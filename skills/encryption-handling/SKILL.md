# Skill: Encryption handling
Key hierarchy and evidence integrity.

- Device key in secure storage (hardware-backed). Never logged, never leaves device.
- Session key via libsodium KDF; per-chunk XChaCha20-Poly1305 + SHA-256 HMAC.
- Local DB encrypted with sqlite3_multiple_ciphers; key wrapped by device key.
- Do NOT put plaintext evidence or keys in logs, crash reports, or analytics.
