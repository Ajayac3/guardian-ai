import type { DisplayState } from '../types';

const LABELS: Record<DisplayState, string> = {
  connecting: 'Connecting…',
  starting: 'Emergency starting…',
  active: 'EMERGENCY ACTIVE',
  lost_connection: 'Connection lost — trying to reconnect',
  ending: 'Session ending…',
  ended: 'Session ended',
  cancelled: 'Session cancelled',
};

export function renderState(el: HTMLElement, state: DisplayState): void {
  el.className = `state-bar ${state}`;
  el.textContent = LABELS[state];
}
