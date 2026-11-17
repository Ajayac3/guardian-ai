/// Exchanges the account-less magic contact token for a short-TTL LiveKit
/// subscriber JWT, via the `issue-viewer-token` Supabase Edge function. The
/// function also records a scoped `contact_session_grants` row that authorizes
/// reading the session and ending it (see M2/M4).

export interface ViewerGrant {
  livekitUrl: string;
  livekitToken: string;
  room: string;
  supabaseAccessToken: string;
}

export async function exchangeToken(opts: {
  supabaseUrl: string;
  supabaseAnonKey: string;
  sessionId: string;
  contactToken: string;
}): Promise<ViewerGrant> {
  const headers: Record<string, string> = { 'content-type': 'application/json' };
  // Pass the publishable/anon key so the request clears the API gateway even
  // when the function route requires an apikey.
  if (opts.supabaseAnonKey !== '') {
    headers.apikey = opts.supabaseAnonKey;
    headers.Authorization = `Bearer ${opts.supabaseAnonKey}`;
  }
  const res = await fetch(`${opts.supabaseUrl}/functions/v1/issue-viewer-token`, {
    method: 'POST',
    headers,
    body: JSON.stringify({
      session_id: opts.sessionId,
      token: opts.contactToken,
    }),
  });
  if (!res.ok) {
    throw new Error(`viewer token exchange failed (${res.status})`);
  }
  return (await res.json()) as ViewerGrant;
}
