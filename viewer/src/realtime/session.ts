import type { GeoEvent, SessionRow } from '../types';

export interface SessionFeedOptions {
  supabaseUrl: string;
  anonKey: string;
  /** Scoped grant JWT (sub = contact_uid) authorizing reads of this session. */
  accessToken?: string;
  sessionId: string;
  contactToken: string;
  onStatus: (row: SessionRow) => void;
  onGeo: (geo: GeoEvent) => void;
}

export interface SessionFeed {
  /// Ends the session as the verified contact (server-validated RPC). The only
  /// client path that can end a session — and it is NOT the device.
  endSession: () => Promise<void>;
  unsubscribe: () => Promise<void>;
}

const POLL_MS = 3000;

/// Polls live session status + latest location with the contact grant JWT.
///
/// Polling (not Realtime postgres_changes) is used for the account-less contact:
/// the grant is a function-based RLS policy which local Realtime won't evaluate
/// for postgres_changes. REST honours it reliably. See docs/brain/debugging.md.
export function watchSession(opts: SessionFeedOptions): SessionFeed {
  const headers: Record<string, string> = {
    apikey: opts.anonKey,
    Authorization: `Bearer ${opts.accessToken ?? opts.anonKey}`,
    'content-type': 'application/json',
  };

  let stopped = false;
  let lastLocAt: string | null = null;

  async function poll(): Promise<void> {
    if (stopped) return;
    try {
      const url =
        `${opts.supabaseUrl}/rest/v1/emergency_sessions?id=eq.${opts.sessionId}` +
        `&select=id,status,kind,last_lat,last_lng,last_loc_at,ended_by`;
      const res = await fetch(url, { headers });
      if (!res.ok) return;
      const rows = (await res.json()) as SessionRow[];
      const row = rows[0];
      if (!row) return;
      opts.onStatus(row);
      if (
        row.last_lat !== null &&
        row.last_lng !== null &&
        row.last_loc_at !== lastLocAt
      ) {
        lastLocAt = row.last_loc_at;
        opts.onGeo({
          lat: row.last_lat,
          lng: row.last_lng,
          at: row.last_loc_at ?? '',
        });
      }
    } catch {
      // transient; next tick retries
    }
  }

  const timer = setInterval(poll, POLL_MS);
  void poll();

  return {
    endSession: async (): Promise<void> => {
      const res = await fetch(
        `${opts.supabaseUrl}/rest/v1/rpc/end_session_by_contact`,
        {
          method: 'POST',
          headers,
          body: JSON.stringify({
            p_session_id: opts.sessionId,
            p_contact_token: opts.contactToken,
          }),
        },
      );
      if (!res.ok) throw new Error(`end session failed (${res.status})`);
    },
    unsubscribe: async (): Promise<void> => {
      stopped = true;
      clearInterval(timer);
    },
  };
}
