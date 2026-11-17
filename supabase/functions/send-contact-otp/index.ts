// send-contact-otp: owner-only. Generates a 6-digit OTP for one of the owner's
// emergency contacts, stores only its hash, and delivers it. Auth verified
// manually (verify_jwt = false).
import { json, preflight } from '../_shared/cors.ts';
import { admin, userClient } from '../_shared/clients.ts';
import { sha256Hex } from '../_shared/hash.ts';
import { deliverOtp } from '../_shared/notify.ts';

Deno.serve(async (req) => {
  const pf = preflight(req);
  if (pf) return pf;

  try {
    const authHeader = req.headers.get('Authorization') ?? '';
    if (authHeader === '') return json({ error: 'missing_auth' }, 401);

    const u = userClient(authHeader);
    const { data: userData, error: userErr } = await u.auth.getUser();
    if (userErr || !userData.user) return json({ error: 'unauthorized' }, 401);

    const body = await req.json().catch(() => ({}));
    const contactId: string | null = body.contact_id ?? null;
    if (!contactId) return json({ error: 'contact_id_required' }, 400);

    // RLS scopes this to the owner's own contacts.
    const { data: contact, error: cErr } = await u
      .from('emergency_contacts')
      .select('id, name, contact_email, contact_phone, status')
      .eq('id', contactId)
      .single();
    if (cErr || !contact) return json({ error: 'contact_not_found' }, 404);
    if (contact.status === 'verified') {
      return json({ error: 'already_verified' }, 409);
    }
    if (contact.status === 'revoked') {
      return json({ error: 'contact_revoked' }, 409);
    }

    const channel: 'email' | 'sms' = contact.contact_email ? 'email' : 'sms';
    const to = contact.contact_email ?? contact.contact_phone;
    if (!to) return json({ error: 'contact_has_no_email_or_phone' }, 400);

    // Throttle issuance to stop SMS/email bombing + toll fraud: max 5 codes/hour
    // per contact, and at least 30s between codes.
    const sinceHour = new Date(Date.now() - 60 * 60 * 1000).toISOString();
    const { data: recent } = await admin
      .from('contact_verifications')
      .select('created_at')
      .eq('contact_id', contactId)
      .gte('created_at', sinceHour)
      .order('created_at', { ascending: false });
    if (recent && recent.length >= 5) {
      return json({ error: 'too_many_requests' }, 429);
    }
    if (
      recent && recent.length > 0 &&
      Date.now() - new Date(recent[0].created_at).getTime() < 30_000
    ) {
      return json({ error: 'try_again_shortly' }, 429);
    }

    // Keep only one live code per contact.
    await admin
      .from('contact_verifications')
      .update({ consumed_at: new Date().toISOString() })
      .eq('contact_id', contactId)
      .is('consumed_at', null);

    const code = (Math.floor(Math.random() * 900000) + 100000).toString();
    const codeHash = await sha256Hex(code);
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString();

    const { error: insErr } = await admin.from('contact_verifications').insert({
      contact_id: contactId,
      code_hash: codeHash,
      channel,
      expires_at: expiresAt,
    });
    if (insErr) return json({ error: insErr.message }, 400);

    const delivered = await deliverOtp({
      channel,
      to,
      code,
      contactName: contact.name,
    });
    const devEcho = Deno.env.get('OTP_DEV_ECHO') === 'true';
    return json({ ok: true, channel, delivered, ...(devEcho ? { code } : {}) });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
