import 'dart:convert';

import 'package:cryptography/cryptography.dart';

Future<void> main() async {
  final algorithm = Argon2id(
    parallelism: 1,
    memory: 19 * 1024,
    iterations: 2,
    hashLength: 32,
  );

  final password = SecretKey(
    utf8.encode('WaterTank-Test-Password-2026'),
  );

  final salt = List<int>.generate(
    16,
    (i) => i + 1,
  );

  final stopwatch = Stopwatch()..start();

  final key = await algorithm.deriveKey(
    secretKey: password,
    nonce: salt,
  );

  stopwatch.stop();

  final bytes = await key.extractBytes();

  print('===== ARGON2ID TEST =====');
  print('Memory: 19 MiB');
  print('Parallelism: 1');
  print('Iterations: 2');
  print('Key length: ${bytes.length} bytes');
  print('Elapsed: ${stopwatch.elapsedMilliseconds} ms');

  if (bytes.length != 32) {
    throw StateError('Invalid derived key length');
  }

  print('Argon2id: PASS');
}
