/// CryptoService implementation (XChaCha20-Poly1305 + HMAC-SHA256) with a
/// pluggable key vault (hardware-backed secure storage in the app).
library;

export 'src/crypto_service_impl.dart';
export 'src/key_vault.dart';
