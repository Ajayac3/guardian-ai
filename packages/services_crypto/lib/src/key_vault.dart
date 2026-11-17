import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Small seam over secret persistence so crypto is testable without platform
/// channels. The app uses [SecureStorageKeyVault] (Android Keystore / iOS
/// Keychain + Secure Enclave); tests use [InMemoryKeyVault].
abstract interface class KeyVault {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class InMemoryKeyVault implements KeyVault {
  final _store = <String, String>{};

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> write(String key, String value) async => _store[key] = value;
}

class SecureStorageKeyVault implements KeyVault {
  // Defaults are hardware-backed where the device supports it (Android Keystore /
  // iOS Keychain). Kept minimal to stay compatible across plugin versions.
  SecureStorageKeyVault([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
}
