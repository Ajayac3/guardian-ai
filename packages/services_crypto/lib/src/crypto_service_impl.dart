import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:guardian_services/guardian_services.dart';

import 'key_vault.dart';

/// XChaCha20-Poly1305 chunk encryption + HMAC-SHA256 integrity. The device
/// master key lives in a hardware-backed [KeyVault]; per-session keys are HKDF
/// derivations of it. Stored ciphertext layout: nonce(24) ‖ cipherText ‖ mac(16).
class CryptographyCryptoService implements CryptoService {
  CryptographyCryptoService(this._vault);

  final KeyVault _vault;
  final _aead = Xchacha20.poly1305Aead();
  final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  static const _kMaster = 'guardian.device_master_key';
  static const _kKeyId = 'guardian.device_key_id';
  static const macLength = 16;
  static const nonceLength = 24;

  Uint8List? _masterCache;

  Future<Uint8List> _master() async {
    if (_masterCache != null) return _masterCache!;
    final stored = await _vault.read(_kMaster);
    if (stored != null) {
      _masterCache = base64Decode(stored);
      return _masterCache!;
    }
    final key = await _aead.newSecretKey();
    final bytes = Uint8List.fromList(await key.extractBytes());
    await _vault.write(_kMaster, base64Encode(bytes));
    _masterCache = bytes;
    return bytes;
  }

  @override
  Future<DeviceKey> ensureDeviceKey() async {
    final master = await _master();
    var keyId = await _vault.read(_kKeyId);
    if (keyId == null) {
      final mac = await Hmac.sha256().calculateMac(
        utf8.encode('guardian-device-id'),
        secretKey: SecretKey(master),
      );
      keyId = base64Url.encode(mac.bytes).substring(0, 16);
      await _vault.write(_kKeyId, keyId);
    }
    // A public identifier the server can bind to — derived, never the secret.
    final pub = await Hmac.sha256().calculateMac(
      utf8.encode('guardian-device-pub'),
      secretKey: SecretKey(master),
    );
    return DeviceKey(keyId: keyId, publicKey: Uint8List.fromList(pub.bytes));
  }

  @override
  Future<SessionKey> deriveSessionKey(
    String sessionId, {
    required String serverSalt,
  }) async {
    final master = await _master();
    final derived = await _hkdf.deriveKey(
      secretKey: SecretKey(master),
      nonce: utf8.encode(serverSalt),
      info: utf8.encode('guardian-session:$sessionId'),
    );
    return SessionKey(
      keyId: sessionId,
      bytes: Uint8List.fromList(await derived.extractBytes()),
    );
  }

  @override
  Future<EncryptedChunk> encryptChunk(
    Uint8List plaintext,
    SessionKey key, {
    required String sessionId,
    required int seq,
    required EvidenceMedia media,
  }) async {
    final secretKey = SecretKey(key.bytes);
    final nonce = _aead.newNonce();
    final aad = utf8.encode('$sessionId|$seq|${media.name}');
    final box = await _aead.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
      aad: aad,
    );
    final combined = Uint8List.fromList([
      ...box.nonce,
      ...box.cipherText,
      ...box.mac.bytes,
    ]);
    final hmac = await hmacSha256(combined, key);
    return EncryptedChunk(
      meta: EvidenceChunkMeta(
        sessionId: sessionId,
        seq: seq,
        media: media,
        bytes: combined.length,
        sha256Hmac: hmac,
        encKeyId: key.keyId,
      ),
      ciphertext: combined,
    );
  }

  @override
  Future<String> hmacSha256(Uint8List data, SessionKey key) async {
    final mac = await Hmac.sha256().calculateMac(
      data,
      secretKey: SecretKey(key.bytes),
    );
    return mac.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
