import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:guardian_services_crypto/guardian_services_crypto.dart';

/// Seals queue payloads at rest with XChaCha20-Poly1305 under a key held in the
/// hardware-backed [KeyVault]. Evidence chunks are already ciphertext when they
/// reach the queue; this protects the lower-sensitivity rows (location pings)
/// that would otherwise sit in plaintext in the local DB.
///
/// Layout: nonce(24) ‖ cipherText ‖ mac(16) — same as the evidence pipeline.
class QueueCipher {
  QueueCipher(this._vault);

  final KeyVault _vault;
  final _aead = Xchacha20.poly1305Aead();

  static const _kKey = 'guardian.offline_queue_key';
  static const _nonceLength = 24;
  static const _macLength = 16;

  Uint8List? _cache;

  Future<Uint8List> _key() async {
    if (_cache != null) return _cache!;
    final stored = await _vault.read(_kKey);
    if (stored != null) {
      _cache = base64Decode(stored);
      return _cache!;
    }
    final key = await _aead.newSecretKey();
    final bytes = Uint8List.fromList(await key.extractBytes());
    await _vault.write(_kKey, base64Encode(bytes));
    _cache = bytes;
    return bytes;
  }

  Future<Uint8List> seal(Uint8List plaintext) async {
    final box = await _aead.encrypt(
      plaintext,
      secretKey: SecretKey(await _key()),
      nonce: _aead.newNonce(),
    );
    return Uint8List.fromList([
      ...box.nonce,
      ...box.cipherText,
      ...box.mac.bytes,
    ]);
  }

  Future<Uint8List> open(Uint8List blob) async {
    final box = SecretBox(
      blob.sublist(_nonceLength, blob.length - _macLength),
      nonce: blob.sublist(0, _nonceLength),
      mac: Mac(blob.sublist(blob.length - _macLength)),
    );
    final clear = await _aead.decrypt(box, secretKey: SecretKey(await _key()));
    return Uint8List.fromList(clear);
  }
}
