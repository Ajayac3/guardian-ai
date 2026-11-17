import 'dart:typed_data';

import 'models/evidence_chunk.dart';

/// Public half of the device key, registered server-side for binding.
class DeviceKey {
  const DeviceKey({required this.keyId, required this.publicKey});
  final String keyId;
  final Uint8List publicKey;
}

/// Per-session symmetric key derived from the device key.
class SessionKey {
  const SessionKey({required this.keyId, required this.bytes});
  final String keyId;
  final Uint8List bytes;
}

/// All cryptography for the app: hardware-backed device key, per-session key
/// derivation, chunk encryption + integrity HMAC. See `docs/brain/security.md`.
abstract interface class CryptoService {
  /// Returns the device key, generating + persisting it in hardware-backed
  /// secure storage on first use.
  Future<DeviceKey> ensureDeviceKey();

  /// Derives a per-session key (KDF over device key + session id + server salt).
  Future<SessionKey> deriveSessionKey(
    String sessionId, {
    required String serverSalt,
  });

  /// Encrypts a plaintext chunk (XChaCha20-Poly1305) and attaches an HMAC.
  Future<EncryptedChunk> encryptChunk(
    Uint8List plaintext,
    SessionKey key, {
    required String sessionId,
    required int seq,
    required EvidenceMedia media,
  });

  Future<String> hmacSha256(Uint8List data, SessionKey key);
}
