import 'dart:typed_data';

import 'package:meta/meta.dart';

enum EvidenceMedia { audio, video }

/// Metadata describing one encrypted evidence chunk before upload.
@immutable
class EvidenceChunkMeta {
  const EvidenceChunkMeta({
    required this.sessionId,
    required this.seq,
    required this.media,
    required this.bytes,
    required this.sha256Hmac,
    required this.encKeyId,
  });

  final String sessionId;
  final int seq;
  final EvidenceMedia media;
  final int bytes;
  final String sha256Hmac;
  final String encKeyId;

  String get mediaWire => media == EvidenceMedia.video ? 'video' : 'audio';
}

/// An encrypted chunk plus its metadata, ready to hand to the [StorageService].
@immutable
class EncryptedChunk {
  const EncryptedChunk({required this.meta, required this.ciphertext});

  final EvidenceChunkMeta meta;
  final Uint8List ciphertext;
}
