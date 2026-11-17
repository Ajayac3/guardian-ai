import 'models/evidence_chunk.dart';
import 'models/geo_ping.dart';

/// One item awaiting upload while connectivity is unavailable.
sealed class QueuedItem {
  const QueuedItem();
}

class QueuedChunk extends QueuedItem {
  const QueuedChunk(this.chunk);
  final EncryptedChunk chunk;
}

class QueuedGeo extends QueuedItem {
  const QueuedGeo(this.sessionId, this.ping);
  final String sessionId;
  final GeoPing ping;
}

class DrainProgress {
  const DrainProgress({required this.sent, required this.remaining});
  final int sent;
  final int remaining;
}

/// Encrypted durable queue that preserves evidence locally until connectivity
/// resumes, then drains in order.
abstract interface class OfflineQueue {
  Future<void> enqueue(QueuedItem item);

  /// Drains pending items as connectivity allows, emitting progress.
  Stream<DrainProgress> drain();

  Future<int> pendingCount();
}
