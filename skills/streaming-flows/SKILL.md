# Skill: Streaming flows
LiveKit room/token lifecycle and publisher<->viewer debugging.

- `create-session` Edge fn mints a publisher JWT + room; `issue-viewer-token`
  mints a short-TTL subscriber JWT after magic-token verification.
- Local dev: `livekit-server --dev` (api key `devkey` / secret `secret`).
- Publisher = app (livekit_client); subscriber = viewer (livekit-client JS).
- `StreamingService.disconnect()` closes local transport only — it does NOT end
  the server session.
