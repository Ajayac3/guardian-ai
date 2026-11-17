// delete-user-account: owner-only. Permanently removes the caller's auth user;
// profiles / emergency_contacts / emergency_sessions / devices / push_tokens all
// reference auth.users with ON DELETE CASCADE, so owned data is purged with it.
// verify_jwt = false.
import { json, preflight } from '../_shared/cors.ts';
import { admin, userClient } from '../_shared/clients.ts';

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

    const { error: delErr } = await admin.auth.admin.deleteUser(user.id);
    if (delErr) return json({ error: delErr.message }, 400);
    return json({ ok: true });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
