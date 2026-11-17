// issue-viewer-token: account-less. Verifies the magic contact token, then
// returns a LiveKit subscriber JWT + a scoped Supabase access token (carrying a
// `session_grant` claim) so the browser can watch and read live state.
// verify_jwt = false (the contact has no Supabase account).
import { json, preflight } from '../_shared/cors.ts';
import { admin } from '../_shared/clients.ts';
import { contactSupabaseJwt, subscriberToken } from '../_shared/livekit.ts';
import { sha256Hex } from '../_shared/hash.ts';
import { env } from '../_shared/env.ts';

Deno.serve(async (req) => {
  const pf = preflight(req);
  if (pf) return pf;

  try {
    const { session_id, token } = await req.json().catch(() => ({}));
    if (!session_id || !token) return json({ error: 'missing_params' }, 400);

    const tokenHash = await sha256Hex(token);
    const { data: grant } = await admin
      .from('contact_session_grants')
      .select('id, session_id, expires_at, revoked_at')
      .eq('session_id', session_id)
      .eq('token_hash', tokenHash)
      .maybeSingle();

    if (
      !grant ||
      grant.revoked_at !== null ||
      new Date(grant.expires_at) < new Date()
    ) {
      return json({ error: 'invalid_or_expired' }, 403);
    }

    const { data: session } = await admin
      .from('emergency_sessions')
      .select('livekit_room')
      .eq('id', session_id)
      .single();
    if (!session?.livekit_room) return json({ error: 'no_room' }, 404);

    // Pseudo-identity for this contact view; recorded so RLS (auth.uid()) and
    // Realtime can authorize it.
    const contactUid = crypto.randomUUID();
    await admin
      .from('contact_session_grants')
      .update({ contact_uid: contactUid })
      .eq('id', grant.id);

    const livekitToken = await subscriberToken(
      session.livekit_room,
      `contact:${contactUid}`,
    );
    const supabaseAccessToken = await contactSupabaseJwt(session_id, contactUid);

    return json({
      livekitUrl: env.livekitUrl,
      livekitToken,
      room: session.livekit_room,
      supabaseAccessToken,
    });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
