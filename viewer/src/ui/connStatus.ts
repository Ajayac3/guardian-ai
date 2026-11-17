import type { ConnState } from '../types';

export function renderConn(el: HTMLElement, state: ConnState): void {
  el.className = `conn-badge ${state}`;
  el.textContent = state;
}
