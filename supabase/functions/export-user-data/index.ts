// export-user-data: owner-only. Returns a JSON bundle of the caller's data
// (GDPR/CCPA access). RLS scopes every read to the owner. verify_jwt = false.
import { json, preflight } from '../_shared/cors.ts';
import { userClient } from '../_shared/clients.ts';

Deno.serve(async (req) => {
  const pf = preflight(req);
  if (pf) return pf;

  try {
    const authHeader = req.headers.get('Authorization') ?? '';
    if (authHeader === '') return json({ error: 'missing_auth' }, 401);

    const u = userClient(authHeader);
    const { data: userData, error: userErr } = await u.auth.getUser();
    if (userErr || !userData.user) return json({ error: 'unauthorized' }, 401);
    const user = userData.user;

    const [profile, contacts, sessions, events, evidence, devices, pushTokens] =
      await Promise.all([
        u.from('profiles').select('*').eq('id', user.id),
        u.from('emergency_contacts').select('*'),
        u.from('emergency_sessions').select('*'),
        u.from('session_events').select('*'),
        u.from('evidence_manifest').select('*'),
        u.from('devices').select('*'),
        u.from('push_tokens').select('*'),
      ]);

    return json({
      exported_at: new Date().toISOString(),
      account: { id: user.id, email: user.email },
      profile: profile.data ?? [],
      emergency_contacts: contacts.data ?? [],
      emergency_sessions: sessions.data ?? [],
      session_events: events.data ?? [],
      evidence_manifest: evidence.data ?? [],
      devices: devices.data ?? [],
      push_tokens: pushTokens.data ?? [],
    });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
