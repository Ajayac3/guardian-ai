import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_services/guardian_services.dart';
import 'package:guardian_app/evidence_uploader.dart';

class _FakeCrypto implements CryptoService {
  int deriveCount = 0;

  @override
  Future<DeviceKey> ensureDeviceKey() async =>
      DeviceKey(keyId: 'dev', publicKey: Uint8List(0));

  @override
  Future<SessionKey> deriveSessionKey(
    String sessionId, {
    required String serverSalt,
  }) async {
    deriveCount++;
    return SessionKey(
      keyId: sessionId,
      bytes: Uint8List.fromList(List.filled(32, 1)),
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
    return EncryptedChunk(
      meta: EvidenceChunkMeta(
        sessionId: sessionId,
        seq: seq,
        media: media,
        bytes: plaintext.length + 40,
        sha256Hmac: 'deadbeef',
        encKeyId: key.keyId,
      ),
      ciphertext: Uint8List.fromList([0, ...plaintext]),
    );
  }

  @override
  Future<String> hmacSha256(Uint8List data, SessionKey key) async => 'deadbeef';
}

class _FakeStorage implements StorageService {
  EncryptedChunk? uploaded;
  EvidenceChunkMeta? committed;

  @override
  Future<UploadTarget> requestUpload(EvidenceChunkMeta meta) async =>
      UploadTarget(
        url: 'https://put',
        headers: const {},
        r2Key: 'k/${meta.seq}',
      );

  @override
  Future<void> upload(UploadTarget target, EncryptedChunk chunk) async =>
      uploaded = chunk;

  @override
  Future<void> commitManifest(EvidenceChunkMeta meta, String r2Key) async =>
      committed = meta;
}

void main() {
  test(
    'uploadChunk encrypts, uploads ciphertext, commits manifest; key reused',
    () async {
      final crypto = _FakeCrypto();
      final storage = _FakeStorage();
      final uploader = EvidenceUploader(
        crypto: crypto,
        storage: storage,
        sessionId: 's1',
        serverSalt: 'salt',
      );

      await uploader.uploadChunk(
        Uint8List.fromList([9, 9]),
        seq: 0,
        media: EvidenceMedia.audio,
      );
      await uploader.uploadChunk(
        Uint8List.fromList([8]),
        seq: 1,
        media: EvidenceMedia.audio,
      );

      expect(crypto.deriveCount, 1); // session key derived once and cached
      expect(
        storage.uploaded!.ciphertext.first,
        0,
      ); // ciphertext, not plaintext
      expect(storage.committed!.seq, 1);
      expect(storage.committed!.sha256Hmac, 'deadbeef');
    },
  );
}
