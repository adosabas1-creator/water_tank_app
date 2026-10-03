import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/services/backup_encryption_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AES-256-GCM encrypt/decrypt and tamper detection', () async {
    final service = BackupEncryptionService();

    final original = Uint8List.fromList(
      utf8.encode(
        'Water Tank App - AES-256-GCM backup encryption test',
      ),
    );

    final encrypted = await service.encrypt(original);

    expect(
      utf8.decode(encrypted.sublist(0, 8)),
      'WTBACK01',
    );
    expect(encrypted[8], 1);

    final decrypted = await service.decrypt(encrypted);

    expect(
      utf8.decode(decrypted),
      utf8.decode(original),
    );

    final tampered = Uint8List.fromList(encrypted);
    tampered[tampered.length - 1] ^= 1;

    expect(
      () => service.decrypt(tampered),
      throwsA(isA<FormatException>()),
    );
  });
}
