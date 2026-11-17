import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guardian_services/guardian_services.dart';
import 'package:guardian_services_crypto/guardian_services_crypto.dart';

void main() {
  late CryptographyCryptoService svc;

  setUp(() async {
    svc = CryptographyCryptoService(InMemoryKeyVault());
    await svc.ensureDeviceKey();
  });

  test('session key derivation is deterministic and salt-sensitive', () async {
    final a = await svc.deriveSessionKey('s1', serverSalt: 'salt');
    final b = await svc.deriveSessionKey('s1', serverSalt: 'salt');
    final c = await svc.deriveSessionKey('s1', serverSalt: 'other');
    expect(a.bytes, equals(b.bytes));
    expect(a.bytes, isNot(equals(c.bytes)));
    expect(a.bytes.length, 32);
  });

  test(
    'encrypt → decrypt roundtrip, HMAC matches and is deterministic',
    () async {
      final key = await svc.deriveSessionKey('s1', serverSalt: 'salt');
      final plain = Uint8List.fromList(utf8.encode('sensitive evidence bytes'));

      final chunk = await svc.encryptChunk(
        plain,
        key,
        sessionId: 's1',
        seq: 7,
        media: EvidenceMedia.audio,
      );

      expect(chunk.ciphertext, isNot(equals(plain)));
      expect(chunk.meta.sha256Hmac.length, 64); // 32 bytes hex
      expect(chunk.meta.seq, 7);

      // HMAC over the stored ciphertext is reproducible.
      final h2 = await svc.hmacSha256(chunk.ciphertext, key);
      expect(h2, equals(chunk.meta.sha256Hmac));

      // Decrypt using the same AEAD + AAD.
      final aead = Xchacha20.poly1305Aead();
      final bytes = chunk.ciphertext;
      final nonce = bytes.sublist(0, CryptographyCryptoService.nonceLength);
      final mac = bytes.sublist(
        bytes.length - CryptographyCryptoService.macLength,
      );
      final cipherText = bytes.sublist(
        CryptographyCryptoService.nonceLength,
        bytes.length - CryptographyCryptoService.macLength,
      );
      final clear = await aead.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: SecretKey(key.bytes),
        aad: utf8.encode('s1|7|audio'),
      );
      expect(Uint8List.fromList(clear), equals(plain));
    },
  );

  test('wrong AAD (seq) fails authentication', () async {
    final key = await svc.deriveSessionKey('s1', serverSalt: 'salt');
    final plain = Uint8List.fromList(utf8.encode('x'));
    final chunk = await svc.encryptChunk(
      plain,
      key,
      sessionId: 's1',
      seq: 1,
      media: EvidenceMedia.audio,
    );
    final aead = Xchacha20.poly1305Aead();
    final bytes = chunk.ciphertext;
    final nonce = bytes.sublist(0, 24);
    final mac = bytes.sublist(bytes.length - 16);
    final cipherText = bytes.sublist(24, bytes.length - 16);
    expect(
      () => aead.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: SecretKey(key.bytes),
        aad: utf8.encode('s1|999|audio'), // tampered seq
      ),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });
}
