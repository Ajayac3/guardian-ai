import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_services/guardian_services.dart';
import 'package:guardian_services_crypto/guardian_services_crypto.dart';
import 'package:guardian_services_offline_drift/guardian_services_offline_drift.dart';

void main() {
  late Directory dir;
  late KeyVault vault;
  late List<EncryptedChunk> sentChunks;
  late List<GeoPing> sentGeos;
  var failSend = false;

  EncryptedChunk chunk(int seq) => EncryptedChunk(
    meta: EvidenceChunkMeta(
      sessionId: 's1',
      seq: seq,
      media: EvidenceMedia.audio,
      bytes: 3,
      sha256Hmac: 'h$seq',
      encKeyId: 'k1',
    ),
    ciphertext: Uint8List.fromList([seq, seq, seq]),
  );

  GeoPing ping(double lat) =>
      GeoPing(lat: lat, lng: 2, at: DateTime.utc(2026, 1, 1));

  FileOfflineQueue build() => FileOfflineQueue(
    dir: dir,
    cipher: QueueCipher(vault),
    sendChunk: (c) async {
      if (failSend) throw Exception('offline');
      sentChunks.add(c);
    },
    sendGeo: (sid, p) async {
      if (failSend) throw Exception('offline');
      sentGeos.add(p);
    },
  );

  setUp(() {
    sentChunks = [];
    sentGeos = [];
    failSend = false;
    vault = InMemoryKeyVault();
    dir = Directory.systemTemp.createTempSync('gai_queue_');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test(
    'enqueue then drain sends in insertion order and empties the queue',
    () async {
      final queue = build();
      await queue.enqueue(QueuedChunk(chunk(0)));
      await queue.enqueue(QueuedGeo('s1', ping(1)));
      await queue.enqueue(QueuedChunk(chunk(1)));
      expect(await queue.pendingCount(), 3);

      final progress = await queue.drain().toList();
      expect(progress.last.remaining, 0);
      expect(progress.last.sent, 3);
      expect(sentChunks.map((c) => c.meta.seq), [0, 1]);
      expect(sentGeos.single.lat, 1);
      expect(await queue.pendingCount(), 0);
    },
  );

  test('duplicate chunk (same session/seq/media) is ignored', () async {
    final queue = build();
    await queue.enqueue(QueuedChunk(chunk(0)));
    await queue.enqueue(QueuedChunk(chunk(0)));
    expect(await queue.pendingCount(), 1);
  });

  test('drain stops and preserves items when the sender fails', () async {
    final queue = build();
    await queue.enqueue(QueuedChunk(chunk(0)));
    await queue.enqueue(QueuedChunk(chunk(1)));
    failSend = true;
    final progress = await queue.drain().toList();
    expect(progress, isEmpty);
    expect(await queue.pendingCount(), 2);
  });

  test('items survive being reopened (durable across restart)', () async {
    await build().enqueue(QueuedChunk(chunk(5)));
    final reopened = build();
    expect(await reopened.pendingCount(), 1);
    await reopened.drain().toList();
    expect(sentChunks.single.meta.seq, 5);
  });

  test('drained chunk round-trips ciphertext + metadata intact', () async {
    final queue = build();
    await queue.enqueue(QueuedChunk(chunk(7)));
    await queue.drain().toList();
    final got = sentChunks.single;
    expect(got.meta.sha256Hmac, 'h7');
    expect(got.meta.encKeyId, 'k1');
    expect(got.ciphertext, Uint8List.fromList([7, 7, 7]));
  });

  test('geo payload is sealed at rest (no plaintext coordinates)', () async {
    await build().enqueue(QueuedGeo('s1', ping(12.345678)));
    final files = dir.listSync().whereType<File>().toList();
    final contents = files.map((f) => f.readAsStringSync()).join();
    expect(contents.contains('12.345678'), isFalse);
  });
}
