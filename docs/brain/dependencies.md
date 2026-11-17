# Key dependencies (confirmed current, May 2026)

- State: flutter_riverpod ^3.x (AsyncNotifier)
- Streaming: livekit_client (app) / livekit-client JS (viewer)
- Backend: supabase_flutter; Edge Functions (Deno)
- Crypto: **cryptography** (pure-Dart XChaCha20-Poly1305 + HMAC-SHA256 + HKDF) —
  chosen over sodium/sodium_libs for host-testability (no native-plugin init);
  hardware-backed KEY STORAGE still via flutter_secure_storage (Keystore/Enclave).
- Object storage: aws4fetch (Edge presign) → R2 in prod / local Supabase S3 in dev.
- Local DB: drift + sqlite3_multiple_ciphers (NOT deprecated sqlcipher_flutter_libs) — M8
- Viewer: vite, typescript, livekit-client, maplibre-gl (supabase-js dropped — REST poll)
- Location: geolocator (+ Android FGS); flutter_map + OSM tiles
- Push: firebase_messaging (+ APNs later)
- Wake-word: openWakeWord (on-device TFLite)
- SMS (Android, gated): another_telephony
