import 'models/evidence_chunk.dart';

/// A short-lived, pre-signed destination for one encrypted chunk.
class UploadTarget {
  const UploadTarget({
    required this.url,
    required this.headers,
    required this.r2Key,
  });
  final String url;
  final Map<String, String> headers;
  final String r2Key;
}

/// Stores encrypted evidence chunks in object storage and records the manifest.
abstract interface class StorageService {
  /// Requests a pre-signed PUT for an encrypted chunk.
  Future<UploadTarget> requestUpload(EvidenceChunkMeta meta);

  /// Uploads the ciphertext to the pre-signed target.
  Future<void> upload(UploadTarget target, EncryptedChunk chunk);

  /// Records the manifest row (key, HMAC, seq) after a successful upload.
  Future<void> commitManifest(EvidenceChunkMeta meta, String r2Key);
}
