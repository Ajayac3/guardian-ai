import 'dart:typed_data';

import 'package:guardian_services/guardian_services.dart';

/// Encrypts an evidence chunk, uploads the ciphertext to object storage, and
/// records the integrity manifest. One instance per session (caches the
/// per-session key). The object store only ever sees ciphertext.
class EvidenceUploader {
  EvidenceUploader({
    required CryptoService crypto,
    required StorageService storage,
    required this.sessionId,
    required this.serverSalt,
  }) : _crypto = crypto,
       _storage = storage;

  final CryptoService _crypto;
  final StorageService _storage;
  final String sessionId;
  final String serverSalt;

  SessionKey? _key;

  Future<void> uploadChunk(
    Uint8List plaintext, {
    required int seq,
    required EvidenceMedia media,
  }) async {
    _key ??= await _crypto.deriveSessionKey(sessionId, serverSalt: serverSalt);
    final chunk = await _crypto.encryptChunk(
      plaintext,
      _key!,
      sessionId: sessionId,
      seq: seq,
      media: media,
    );
    final target = await _storage.requestUpload(chunk.meta);
    await _storage.upload(target, chunk);
    await _storage.commitManifest(chunk.meta, target.r2Key);
  }
}
