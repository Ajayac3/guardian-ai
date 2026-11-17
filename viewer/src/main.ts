import './styles/main.css';
import { readConfig, hasSession } from './config';
import { mountLayout } from './ui/layout';
import { renderState } from './ui/stateIndicator';
import { renderConn } from './ui/connStatus';
import { wireStopButton } from './ui/stopFlow';
import { createMap, type LiveMap } from './map/maplibre';
import { subscribe } from './livekit/subscriber';
import { exchangeToken } from './auth/contactToken';
import { watchSession } from './realtime/session';

async function bootstrap(): Promise<void> {
  const cfg = readConfig();
  const root = document.getElementById('app');
  if (root === null) return;

  const dom = mountLayout(root);
  renderState(dom.stateBar, 'connecting');
  renderConn(dom.connBadge, 'connecting');

  if (!hasSession(cfg)) {
    renderState(dom.stateBar, 'ended');
    dom.stateBar.textContent = 'No active session in this link.';
    renderConn(dom.connBadge, 'disconnected');
    return;
  }

  const sessionId = cfg.sessionId as string;
  const contactToken = cfg.contactToken as string;

  // Live media (M2) FIRST — it is the life-safety payload and must never be
  // blocked by anything else (e.g. a map/WebGL failure).
  let accessToken: string | undefined;
  try {
    const grant = await exchangeToken({
      supabaseUrl: cfg.supabaseUrl,
      supabaseAnonKey: cfg.supabaseAnonKey,
      sessionId,
      contactToken,
    });
    accessToken = grant.supabaseAccessToken;
    await subscribe({
      url: grant.livekitUrl,
      token: grant.livekitToken,
      videoEl: dom.video,
      onState: (state) => renderConn(dom.connBadge, state),
    });
  } catch (err) {
    renderConn(dom.connBadge, 'disconnected');
    console.error('media connect failed', err);
  }

  // Map is best-effort — a WebGL/tile failure must not abort the page.
  let map: LiveMap | null = null;
  try {
    map = createMap(dom.mapEl, cfg.osmTileUrl);
  } catch (err) {
    console.error('map init failed', err);
  }

  // Live status + location (M3/M4).
  const feed = watchSession({
    supabaseUrl: cfg.supabaseUrl,
    anonKey: cfg.supabaseAnonKey,
    accessToken,
    sessionId,
    contactToken,
    onStatus: (row) => {
      renderState(dom.stateBar, row.status);
      if (row.last_lat !== null && row.last_lng !== null) {
        map?.setLocation(row.last_lat, row.last_lng);
      }
    },
    onGeo: (geo) => map?.setLocation(geo.lat, geo.lng),
  });

  // Stop-authorization (M4): only the verified contact can end the session.
  wireStopButton(dom.stopBtn, () => feed.endSession());
}

void bootstrap();
