import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:water_tank_app/services/backup_encryption_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final service = BackupEncryptionService();

  final original = Uint8List.fromList(
    utf8.encode(
      'Water Tank App - AES-256-GCM encryption test',
    ),
  );

  final encrypted = await service.encrypt(original);
  final decrypted = await service.decrypt(encrypted);

  final roundTripPassed =
      utf8.decode(decrypted) == utf8.decode(original);

  final tampered = Uint8List.fromList(encrypted);
  tampered[tampered.length - 1] ^= 1;

  var tamperDetected = false;

  try {
    await service.decrypt(tampered);
  } catch (_) {
    tamperDetected = true;
  }

  runApp(
    MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Backup Encryption Test'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Header: ${utf8.decode(encrypted.sublist(0, 8))}',
              ),
              Text('Version: ${encrypted[8]}'),
              Text(
                'Encrypt/Decrypt: '
                '${roundTripPassed ? 'PASS' : 'FAIL'}',
              ),
              Text(
                'Tamper Detection: '
                '${tamperDetected ? 'PASS' : 'FAIL'}',
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
