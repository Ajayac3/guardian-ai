// sign-evidence-upload: owner-only. Returns a pre-signed S3/R2 PUT URL for one
// encrypted evidence chunk. The relay/object store sees only ciphertext.
// verify_jwt = false (owner auth verified manually).
import { AwsClient } from 'npm:aws4fetch@1';
import { json, preflight } from '../_shared/cors.ts';
import { userClient } from '../_shared/clients.ts';
import { env } from '../_shared/env.ts';

Deno.serve(async (req) => {
  const pf = preflight(req);
  if (pf) return pf;

  try {
    const authHeader = req.headers.get('Authorization') ?? '';
    if (authHeader === '') return json({ error: 'missing_auth' }, 401);
    const u = userClient(authHeader);
    const { data: ud } = await u.auth.getUser();
    if (!ud?.user) return json({ error: 'unauthorized' }, 401);

    const { session_id, seq, media } = await req.json().catch(() => ({}));
    if (!session_id || seq === undefined || media === undefined) {
      return json({ error: 'missing_params' }, 400);
    }
    const mediaWire = media === 'video' ? 'video' : 'audio';

    // Ownership: RLS lets the owner read only their own sessions.
    const { data: sess } = await u
      .from('emergency_sessions')
      .select('id')
      .eq('id', session_id)
      .maybeSingle();
    if (!sess) return json({ error: 'forbidden' }, 403);

    const key = `${session_id}/${mediaWire}/${String(seq).padStart(6, '0')}.enc`;
    const aws = new AwsClient({
      accessKeyId: env.s3AccessKey,
      secretAccessKey: env.s3Secret,
      region: env.s3Region,
      service: 's3',
    });
    const url = `${env.s3Endpoint}/${env.s3Bucket}/${key}`;
    const signed = await aws.sign(new Request(url, { method: 'PUT' }), {
      aws: { signQuery: true },
    });

    return json({ url: signed.url, headers: {}, r2_key: key });
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});
