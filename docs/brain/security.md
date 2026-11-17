# Security model

## Key hierarchy
1. **Device key** — generated once, stored in `flutter_secure_storage`
   (Android Keystore; iOS Secure Enclave via `useSecureEnclave` later).
2. **Session key** — derived per session via libsodium KDF (device key + session
   id + server salt). Wraps the local DB key and encrypts evidence.
3. **Per-chunk** — XChaCha20-Poly1305 encrypt + SHA-256 HMAC; manifest records
   HMAC + R2 key + seq. Optional RFC-3161 trusted timestamp.

## Server-authoritative termination (the safety guarantee)
The device JWT cannot write `status='ended'`:
- RLS `WITH CHECK` blocks the value on owner UPDATE.
- A `BEFORE UPDATE` trigger raises unless the role is service-role.
Termination authority: verified contact RPC (`end_session_by_contact`),
pg_cron `server_timeout`, or verified `recovery`. Soft alerts allow owner
`cancelled` only (the "Guardian I'm okay" carve-out), still server-validated.

## Transport
LiveKit transport encryption always; short-TTL signed viewer JWT minted only
after magic-token contact verification; token `jti` revoked on session end.

## Anti-stalking
Owner-initiated only (RLS `owner_id = auth.uid()`); session creation gated on
`anti_stalking_attested_at`; non-dismissible recording indicator during sessions.
