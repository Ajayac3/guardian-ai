import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:guardian_services/guardian_services.dart';
import 'package:guardian_services_crypto/guardian_services_crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'queue_cipher.dart';

/// Transmits a queued evidence chunk to durable storage. Throws on failure so
/// the drain can stop and resume later.
typedef ChunkSender = Future<void> Function(EncryptedChunk chunk);

/// Transmits a queued location ping. Throws on failure to pause the drain.
typedef GeoSender = Future<void> Function(String sessionId, GeoPing ping);

/// Durable, ordered, crash-safe [OfflineQueue] backed by one file per item in a
/// private directory — no native database, so it behaves identically on the host
/// (tests), Android and iOS.
///
/// Each item is written `<tmp>` then renamed (atomic) to a zero-padded ordinal
/// file, so a torn write is never read. Chunk ciphertext is stored as-is (it is
/// already AEAD-encrypted by the evidence pipeline); location rows are sealed via
/// [QueueCipher] so coordinates never sit in plaintext at rest.
class FileOfflineQueue implements OfflineQueue {
  FileOfflineQueue({
    required Directory dir,
    required QueueCipher cipher,
    required ChunkSender sendChunk,
    required GeoSender sendGeo,
  }) : _dir = dir,
       _cipher = cipher,
       _sendChunk = sendChunk,
       _sendGeo = sendGeo {
    _dir.createSync(recursive: true);
    _restore();
  }

  static Future<FileOfflineQueue> openDefault({
    required KeyVault vault,
    required ChunkSender sendChunk,
    required GeoSender sendGeo,
  }) async {
    final base = await getApplicationSupportDirectory();
    return FileOfflineQueue(
      dir: Directory(p.join(base.path, 'guardian_offline_queue')),
      cipher: QueueCipher(vault),
      sendChunk: sendChunk,
      sendGeo: sendGeo,
    );
  }

  final Directory _dir;
  final QueueCipher _cipher;
  final ChunkSender _sendChunk;
  final GeoSender _sendGeo;

  static const _ext = '.itm';
  var _counter = 0;
  final _chunkKeys = <String>{};

  void _restore() {
    // Sweep torn writes: a crash between write and rename leaves a `.tmp` orphan.
    if (_dir.existsSync()) {
      for (final f in _dir.listSync().whereType<File>()) {
        if (f.path.endsWith('.tmp')) f.deleteSync();
      }
    }
    for (final f in _items()) {
      final ordinal = int.tryParse(p.basenameWithoutExtension(f.path)) ?? 0;
      if (ordinal >= _counter) _counter = ordinal + 1;
      final env = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      if (env['kind'] == 'chunk') _chunkKeys.add(_keyFromEnv(env));
    }
  }

  List<File> _items() {
    if (!_dir.existsSync()) return [];
    final files =
        _dir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith(_ext))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    return files;
  }

  String _keyFromEnv(Map<String, dynamic> env) =>
      '${env['sessionId']}|${env['seq']}|${env['media']}';

  @override
  Future<void> enqueue(QueuedItem item) async {
    final Map<String, dynamic> env;
    switch (item) {
      case QueuedChunk(:final chunk):
        final key =
            '${chunk.meta.sessionId}|${chunk.meta.seq}|'
            '${chunk.meta.media.name}';
        if (!_chunkKeys.add(key)) return; // dedupe identical chunk
        env = {
          'kind': 'chunk',
          'sessionId': chunk.meta.sessionId,
          'seq': chunk.meta.seq,
          'media': chunk.meta.media.name,
          'bytes': chunk.meta.bytes,
          'sha256Hmac': chunk.meta.sha256Hmac,
          'encKeyId': chunk.meta.encKeyId,
          'payload': base64Encode(chunk.ciphertext),
        };
      case QueuedGeo(:final sessionId, :final ping):
        final sealed = await _cipher.seal(
          Uint8List.fromList(utf8.encode(jsonEncode(ping.toJson()))),
        );
        env = {
          'kind': 'geo',
          'sessionId': sessionId,
          'payload': base64Encode(sealed),
        };
    }
    final name = _counter.toString().padLeft(16, '0');
    final tmp = File(p.join(_dir.path, '$name.tmp'))
      ..writeAsStringSync(jsonEncode(env), flush: true);
    tmp.renameSync(p.join(_dir.path, '$name$_ext'));
    _counter++;
  }

  @override
  Stream<DrainProgress> drain() async* {
    final files = _items();
    var sent = 0;
    var remaining = files.length;
    for (final f in files) {
      try {
        final env = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
        final payload = base64Decode(env['payload'] as String);
        if (env['kind'] == 'chunk') {
          await _sendChunk(_chunkFromEnv(env, payload));
        } else {
          final opened = await _cipher.open(payload);
          final json = jsonDecode(utf8.decode(opened)) as Map<String, dynamic>;
          await _sendGeo(env['sessionId'] as String, GeoPing.fromJson(json));
        }
        if (env['kind'] == 'chunk') _chunkKeys.remove(_keyFromEnv(env));
        f.deleteSync();
        sent++;
        remaining--;
        yield DrainProgress(sent: sent, remaining: remaining);
      } catch (_) {
        // Still offline or the endpoint is failing — keep the rest queued.
        break;
      }
    }
  }

  @override
  Future<int> pendingCount() async => _items().length;

  EncryptedChunk _chunkFromEnv(Map<String, dynamic> env, Uint8List payload) {
    return EncryptedChunk(
      meta: EvidenceChunkMeta(
        sessionId: env['sessionId'] as String,
        seq: env['seq'] as int,
        media: EvidenceMedia.values.byName(env['media'] as String),
        bytes: env['bytes'] as int,
        sha256Hmac: env['sha256Hmac'] as String,
        encKeyId: env['encKeyId'] as String,
      ),
      ciphertext: payload,
    );
  }
}
