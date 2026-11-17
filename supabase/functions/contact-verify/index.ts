// contact-verify: owner-only. Checks a 6-digit OTP against the latest unconsumed
// verification for one of the owner's contacts; on success marks the contact
// verified. Rate-limited via the attempts counter. verify_jwt = false.
import { json, preflight } from '../_shared/cors.ts';
import { admin, userClient } from '../_shared/clients.ts';
import { sha256Hex } from '../_shared/hash.ts';

const maxAttempts = 5;

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
    const code = (body.code ?? '').toString();
    if (!contactId || !code) {
      return json({ error: 'contact_id_and_code_required' }, 400);
    }

    // Ownership check via RLS (null if not the caller's contact).
    const { data: contact, error: cErr } = await u
      .from('emergency_contacts')
      .select('id, status')
      .eq('id', contactId)
      .single();
    if (cErr || !contact) return json({ error: 'contact_not_found' }, 404);
    if (contact.status === 'verified') {
      return json({ ok: true, status: 'verified' });
    }
    if (contact.status === 'revoked') {
      return json({ error: 'contact_revoked' }, 409);
    }

    // Latest unconsumed code (service-role; the table is owner-invisible).
    const { data: ver } = await admin
      .from('contact_verifications')
      .select('id, code_hash, expires_at, attempts')
      .eq('contact_id', contactId)
      .is('consumed_at', null)
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle();
    if (!ver) return json({ error: 'no_pending_code' }, 404);
    if (new Date(ver.expires_at) < new Date()) {
      return json({ error: 'code_expired' }, 410);
    }
    if (ver.attempts >= maxAttempts) {
      return json({ error: 'too_many_attempts' }, 429);
    }

    if ((await sha256Hex(code)) !== ver.code_hash) {
      // Compare-and-swap on the attempt count: if a concurrent request already
      // incremented it, our update hits zero rows and we lock out — so parallel
      // guesses can't all read the same count and bypass the limit.
      const { data: bumped } = await admin
        .from('contact_verifications')
        .update({ attempts: ver.attempts + 1 })
        .eq('id', ver.id)
        .eq('attempts', ver.attempts)
        .select('attempts');
      if (!bumped || bumped.length === 0) {
        return json({ error: 'too_many_attempts' }, 429);
      }
      return json(
        { error: 'invalid_code', attemptsLeft: maxAttempts - ver.attempts - 1 },
        401,
      );
    }

    await admin
      .from('contact_verifications')
      .update({ consumed_at: new Date().toISOString() })
      .eq('id', ver.id);
    await admin
      .from('emergency_contacts')
      .update({ status: 'verified' })
      .eq('id', contactId);
    return json({ ok: true, status: 'verified' });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
