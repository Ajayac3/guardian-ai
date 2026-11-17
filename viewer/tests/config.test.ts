import { describe, expect, it } from 'vitest';
import { hasSession, readConfig } from '../src/config';

describe('readConfig', () => {
  it('parses session id and contact token from the link', () => {
    const cfg = readConfig('?session=abc-123&t=magic');
    expect(cfg.sessionId).toBe('abc-123');
    expect(cfg.contactToken).toBe('magic');
    expect(hasSession(cfg)).toBe(true);
  });

  it('reports no session when params are missing', () => {
    const cfg = readConfig('');
    expect(cfg.sessionId).toBeNull();
    expect(hasSession(cfg)).toBe(false);
  });

  it('falls back to local dev defaults', () => {
    const cfg = readConfig('');
    expect(cfg.livekitUrl).toContain('7880');
    expect(cfg.osmTileUrl).toContain('openstreetmap');
  });
});
