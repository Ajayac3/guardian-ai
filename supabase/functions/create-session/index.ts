// create-session: owner-only. Creates an emergency session in 'starting',
// mints a publisher token + an account-less contact magic link, and returns the
// shareable viewer URL. Auth is verified manually (verify_jwt = false).
import { json, preflight } from '../_shared/cors.ts';
import { admin, userClient } from '../_shared/clients.ts';
import { publisherToken } from '../_shared/livekit.ts';
import { sha256Hex } from '../_shared/hash.ts';
import { env } from '../_shared/env.ts';

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

    const body = await req.json().catch(() => ({}));
    const kind = body.kind === 'soft' ? 'soft' : 'full';
    const contactId: string | null = body.contact_id ?? null;

    // Anti-stalking gate: cannot start a session without the attestation.
    const { data: profile } = await u
      .from('profiles')
      .select('anti_stalking_attested_at')
      .eq('id', user.id)
      .single();
    if (!profile?.anti_stalking_attested_at) {
      return json({ error: 'anti_stalking_attestation_required' }, 403);
    }

    const room = `gai_${crypto.randomUUID()}`;
    const { data: session, error: insErr } = await u
      .from('emergency_sessions')
      .insert({
        owner_id: user.id,
        contact_id: contactId,
        kind,
        status: 'starting',
        livekit_room: room,
      })
      .select()
      .single();
    if (insErr) return json({ error: insErr.message }, 400);

    // Account-less contact grant (store only the hash).
    const token =
      crypto.randomUUID() + crypto.randomUUID().replaceAll('-', '');
    const tokenHash = await sha256Hex(token);
    const { error: grantErr } = await admin
      .from('contact_session_grants')
      .insert({
        session_id: session.id,
        contact_id: contactId,
        token_hash: tokenHash,
        expires_at: new Date(Date.now() + 24 * 3600 * 1000).toISOString(),
      });
    if (grantErr) return json({ error: grantErr.message }, 400);

    const publisherJwt = await publisherToken(room, `owner:${user.id}`);
    const viewerUrl = `${env.viewerBaseUrl}/?session=${session.id}&t=${token}`;

    return json({
      session,
      token: {
        sessionId: session.id,
        livekitUrl: env.livekitUrl,
        room,
        publisherJwt,
        viewerUrl,
      },
    });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
