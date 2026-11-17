// LiveKit access tokens are HS256 JWTs: iss=apiKey, sub=identity, and a `video`
// grant claim. We mint them with jose (Deno-native) rather than the Node-based
// livekit-server-sdk, which keeps the edge runtime happy.
import { SignJWT } from 'npm:jose@5';
import { env } from './env.ts';

interface VideoGrant {
  room: string;
  roomJoin: boolean;
  canPublish: boolean;
  canSubscribe: boolean;
  canPublishData: boolean;
}

function livekitToken(
  identity: string,
  grant: VideoGrant,
  ttl: string,
): Promise<string> {
  const secret = new TextEncoder().encode(env.livekitApiSecret);
  return new SignJWT({ video: grant })
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuer(env.livekitApiKey)
    .setSubject(identity)
    .setNotBefore('0s')
    .setIssuedAt()
    .setExpirationTime(ttl)
    .sign(secret);
}

/// Publisher token for the device owner (audio/video/data).
export function publisherToken(room: string, identity: string): Promise<string> {
  return livekitToken(
    identity,
    {
      room,
      roomJoin: true,
      canPublish: true,
      canSubscribe: true,
      canPublishData: true,
    },
    '2h',
  );
}

/// Subscriber-only token for the emergency contact's browser.
export function subscriberToken(room: string, identity: string): Promise<string> {
  return livekitToken(
    identity,
    {
      room,
      roomJoin: true,
      canPublish: false,
      canSubscribe: true,
      canPublishData: false,
    },
    '1h',
  );
}

/// A short-lived Supabase access token carrying a `session_grant` claim so the
/// account-less contact can read exactly one session over Realtime (RLS).
export function contactSupabaseJwt(sessionId: string, sub: string): Promise<string> {
  const secret = new TextEncoder().encode(env.jwtSecret);
  // `sub` is the contact's pseudo-identity (a UUID also stored as the grant's
  // contact_uid). Realtime honours auth.uid()=sub in RLS; authorization is the
  // grant lookup keyed on it.
  return new SignJWT({ role: 'authenticated', session_grant: sessionId })
    .setProtectedHeader({ alg: 'HS256' })
    .setSubject(sub)
    .setAudience('authenticated')
    .setIssuedAt()
    .setExpirationTime('2h')
    .sign(secret);
}
