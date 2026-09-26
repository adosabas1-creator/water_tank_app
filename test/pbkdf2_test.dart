import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PBKDF2 API works', () async {
    final algorithm = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 100000,
      bits: 256,
    );

    final random = Random.secure();
    final salt = List<int>.generate(
      16,
      (_) => random.nextInt(256),
    );

    final secretKey = await algorithm.deriveKeyFromPassword(
      password: 'TestPassword123',
      nonce: salt,
    );

    final bytes = await secretKey.extractBytes();

    expect(salt.length, 16);
    expect(bytes.length, 32);

    print('PBKDF2 OK');
    print('salt bytes: ${salt.length}');
    print('hash bytes: ${bytes.length}');
  });
}
