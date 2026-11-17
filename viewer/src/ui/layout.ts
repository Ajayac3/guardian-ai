export interface ViewerDom {
  video: HTMLVideoElement;
  mapEl: HTMLElement;
  stateBar: HTMLElement;
  connBadge: HTMLElement;
  stopBtn: HTMLButtonElement;
}

/// Builds the emergency page skeleton and returns the live element references.
export function mountLayout(root: HTMLElement): ViewerDom {
  root.innerHTML = '';

  const wrap = el('div', 'viewer');
  const stateBar = el('div', 'state-bar');
  stateBar.textContent = 'Connecting…';

  const stage = el('div', 'stage');
  const connBadge = el('div', 'conn-badge');
  connBadge.textContent = 'connecting';

  const videoPane = el('div', 'video-pane');
  const video = document.createElement('video');
  video.autoplay = true;
  video.playsInline = true;
  video.controls = false;
  videoPane.appendChild(video);

  const mapPane = el('div', 'map-pane');

  stage.append(connBadge, videoPane, mapPane);

  const footer = el('div', 'footer');
  const stopBtn = document.createElement('button');
  stopBtn.className = 'stop-btn';
  stopBtn.textContent = 'End emergency session';
  stopBtn.disabled = true;
  footer.appendChild(stopBtn);

  wrap.append(stateBar, stage, footer);
  root.appendChild(wrap);

  return { video, mapEl: mapPane, stateBar, connBadge, stopBtn };
}

function el(tag: string, className: string): HTMLElement {
  const e = document.createElement(tag);
  e.className = className;
  return e;
}
