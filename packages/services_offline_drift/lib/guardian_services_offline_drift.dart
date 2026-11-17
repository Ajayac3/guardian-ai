/// Encrypted durable OfflineQueue — crash-safe one-file-per-item store + app-layer
/// XChaCha20 AEAD. No native database, so it behaves identically on host/Android/iOS.
///
/// Scaffolded in M0; implemented in M8. Evidence chunks arrive already encrypted;
/// location rows are sealed with [QueueCipher] before they touch disk.
library;

export 'src/file_offline_queue.dart';
export 'src/queue_cipher.dart';
