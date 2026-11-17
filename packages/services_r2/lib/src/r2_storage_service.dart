import 'package:guardian_core/guardian_core.dart';
import 'package:guardian_services/guardian_services.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Uploads encrypted evidence chunks to R2/S3 via a server-minted presigned PUT,
/// then records the integrity manifest. The object store only ever sees
/// ciphertext.
class R2StorageService implements StorageService {
  R2StorageService(this._client, {http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final SupabaseClient _client;
  final http.Client _http;
  static final _log = Log('storage');

  @override
  Future<UploadTarget> requestUpload(EvidenceChunkMeta meta) async {
    final res = await _client.functions.invoke(
      'sign-evidence-upload',
      body: {
        'session_id': meta.sessionId,
        'seq': meta.seq,
        'media': meta.mediaWire,
      },
    );
    final data = res.data as Map<String, dynamic>;
    if (data['error'] != null) {
      throw StateError('sign-evidence-upload failed: ${data['error']}');
    }
    return UploadTarget(
      url: data['url'] as String,
      headers: Map<String, String>.from(data['headers'] as Map? ?? {}),
      r2Key: data['r2_key'] as String,
    );
  }

  @override
  Future<void> upload(UploadTarget target, EncryptedChunk chunk) async {
    final res = await _http.put(
      Uri.parse(target.url),
      headers: target.headers,
      body: chunk.ciphertext,
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('evidence upload failed: HTTP ${res.statusCode}');
    }
    _log.d('uploaded ${chunk.meta.bytes}B -> ${target.r2Key}');
  }

  @override
  Future<void> commitManifest(EvidenceChunkMeta meta, String r2Key) async {
    await _client.from('evidence_manifest').insert({
      'session_id': meta.sessionId,
      'seq': meta.seq,
      'media': meta.mediaWire,
      'r2_key': r2Key,
      'sha256_hmac': meta.sha256Hmac,
      'bytes': meta.bytes,
      'enc_key_id': meta.encKeyId,
    });
  }
}
