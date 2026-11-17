export type SessionStatus =
  | 'starting'
  | 'active'
  | 'lost_connection'
  | 'ending'
  | 'ended'
  | 'cancelled';

export type DisplayState = SessionStatus | 'connecting';

export type ConnState = 'connecting' | 'connected' | 'reconnecting' | 'disconnected';

export interface SessionRow {
  id: string;
  status: SessionStatus;
  kind: 'full' | 'soft';
  last_lat: number | null;
  last_lng: number | null;
  last_loc_at: string | null;
  ended_by: string | null;
}

export interface GeoEvent {
  lat: number;
  lng: number;
  at: string;
}
