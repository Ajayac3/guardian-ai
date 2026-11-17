# Skill: AI feature integration (Phase 2 hook points)
Where Phase-2 intelligence attaches without touching the safety core.

- Transcription/summary/danger-detection consume the evidence/audio stream via a
  read-only observer on the streaming pipeline; they never gain session-ending
  authority and never weaken the server-authoritative termination model.
- New AI features land as their own `features/*` packages depending on interfaces
  in `packages/services`, not on managed impls.
