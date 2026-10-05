import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:water_tank_app/services/backup_encryption_service.dart';

void main() {
  final service = BackupEncryptionService();

  test('encrypt decrypt with password', () async {
    final original = Uint8List.fromList(utf8.encode('offline-backup'));
    final encrypted = await service.encrypt(plainBytes: original, password: 'StrongPass1');
    expect(utf8.decode(encrypted.sublist(0, 8)), 'WTBACK02');
    final decrypted = await service.decrypt(encryptedBytes: encrypted, password: 'StrongPass1');
    expect(decrypted, original);
  });

  test('automatic backup encrypt decrypt', () async {
    FlutterSecureStorage.setMockInitialValues({});

    final original = Uint8List.fromList(utf8.encode('automatic-backup'));
    final encrypted = await service.encryptAutomatic(plainBytes: original);

    expect(utf8.decode(encrypted.sublist(0, 8)), 'WTBAUTO1');

    final decrypted = await service.decryptAutomatic(
      encryptedBytes: encrypted,
    );

    expect(decrypted, original);
  });

  test('automatic backup rejects tampered data', () async {
    FlutterSecureStorage.setMockInitialValues({});

    final encrypted = await service.encryptAutomatic(
      plainBytes: Uint8List.fromList(utf8.encode('protected-data')),
    );

    encrypted[encrypted.length - 1] ^= 0x01;

    expect(
      () => service.decryptAutomatic(encryptedBytes: encrypted),
      throwsA(isA<FormatException>()),
    );
  });

  test('automatic backup fails when key is missing', () async {
    FlutterSecureStorage.setMockInitialValues({});

    final encrypted = await service.encryptAutomatic(
      plainBytes: Uint8List.fromList(utf8.encode('protected-data')),
    );

    FlutterSecureStorage.setMockInitialValues({});

    expect(
      () => service.decryptAutomatic(encryptedBytes: encrypted),
      throwsA(isA<StateError>()),
    );
  });

  test('automatic backup rejects invalid stored key', () async {
    FlutterSecureStorage.setMockInitialValues({
      'water_tank_auto_backup_key_v1': 'invalid-key',
    });

    expect(
      () => service.encryptAutomatic(
        plainBytes: Uint8List.fromList(utf8.encode('protected-data')),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('wrong password fails offline', () async {
    final encrypted = await service.encrypt(
      plainBytes: Uint8List.fromList(utf8.encode('data')),
      password: 'StrongPass1',
    );
    expect(
      () => service.decrypt(encryptedBytes: encrypted, password: 'WrongPass1'),
      throwsA(isA<FormatException>()),
    );
  });
}
