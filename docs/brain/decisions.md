# Decisions (ADR log)

- **D1 Monorepo = Melos + Dart pub workspaces.** One lockfile; enforced package
  boundaries; clean path to Phase-2 feature packages.
- **D2 Viewer = vanilla TS + Vite + livekit-client + MapLibre GL JS** (not Flutter
  web). The "open a link, no install" promise needs a tiny fast bundle.
- **D3 Managed services on free tiers**, abstracted behind Dart interfaces, so a
  self-host swap (LiveKit OSS / coturn / SeaweedFS / PocketBase) is one file.
- **D4 Live media = transport-encryption + trusted (own-infra) relay by default;**
  Chromium-only LiveKit E2EE (insertable streams) offered as an enhancement.
  Evidence-at-rest is hardware-backed encrypted regardless.
- **D5 iOS activation = Action Button / Siri Shortcut / Control Center / manual**
  (no compliant always-on wake-word); Android uses a foreground service.
- **D6 Contact identity = magic-token grant** (no Supabase account for contacts).
- **D7 Maps = OpenStreetMap** (MapLibre on web, flutter_map in app); no paid key.
- **D8 Offline queue = pure-Dart encrypted file store, not drift/SQLite.** The
  planned `sqlite3_multiple_ciphers` is not a pub package, and both
  `sqlite3_flutter_libs` and `sqlcipher_flutter_libs` are now EOL; `sqlite3` 3.x
  resolves its native lib only via experimental native-assets, which `flutter_tester`
  can't load. The `OfflineQueue` needs append / ordered-read / delete / crash-safety,
  not SQL — so M8 uses one atomically-written file per item under app-support, with
  evidence chunks stored as their existing ciphertext and location rows sealed with
  XChaCha20-Poly1305 under the hardware-backed [KeyVault] key. Zero native deps →
  identical on host (tests), Android, iOS. (Package keeps the `…offline_drift` name.)
