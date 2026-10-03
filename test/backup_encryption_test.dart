import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
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
