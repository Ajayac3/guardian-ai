/// SHA-256 hex of a string. Must match Postgres
/// `encode(digest(token,'sha256'),'hex')` used by end_session_by_contact.
export async function sha256Hex(input: string): Promise<string> {
  const buf = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(input),
  );
  return [...new Uint8Array(buf)]
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}
