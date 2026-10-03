import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BackupEncryptionService {
  static const String _keyName = 'water_tank_backup_aes256_key';

  final FlutterSecureStorage _secureStorage =
      const FlutterSecureStorage();

  final AesGcm _cipher = AesGcm.with256bits();

  Future<SecretKey> _getOrCreateKey() async {
    final storedKey = await _secureStorage.read(
      key: _keyName,
    );

    if (storedKey != null && storedKey.isNotEmpty) {
      final bytes = base64Url.decode(storedKey);
      if (bytes.length != 32) {
        throw StateError('مفتاح النسخة الاحتياطية غير صالح');
      }
      return SecretKey(bytes);
    }

    final key = await _cipher.newSecretKey();
    final keyBytes = await key.extract();

    await _secureStorage.write(
      key: _keyName,
      value: base64UrlEncode(keyBytes.bytes),
    );

    return key;
  }

  Future<Uint8List> encrypt(Uint8List plainBytes) async {
    final key = await _getOrCreateKey();

    final secretBox = await _cipher.encrypt(
      plainBytes,
      secretKey: key,
    );

    final output = BytesBuilder();

    // File format:
    // magic: 8 bytes
    // version: 1 byte
    // nonce: 12 bytes
    // MAC: 16 bytes
    // ciphertext: remaining bytes

    output.add(utf8.encode('WTBACK01'));
    output.addByte(1);
    output.add(secretBox.nonce);
    output.add(secretBox.mac.bytes);
    output.add(secretBox.cipherText);

    return output.toBytes();
  }

  Future<Uint8List> decrypt(Uint8List encryptedBytes) async {
    const magic = 'WTBACK01';
    const headerLength = 8 + 1 + 12 + 16;

    if (encryptedBytes.length < headerLength) {
      throw const FormatException('ملف النسخة الاحتياطية قصير أو تالف');
    }

    final actualMagic =
        utf8.decode(encryptedBytes.sublist(0, 8));

    if (actualMagic != magic) {
      throw const FormatException(
        'الملف ليس نسخة احتياطية مشفرة من Water Tank App',
      );
    }

    final version = encryptedBytes[8];

    if (version != 1) {
      throw const FormatException(
        'إصدار ملف النسخة الاحتياطية غير مدعوم',
      );
    }

    final nonce = encryptedBytes.sublist(9, 21);
    final mac = Mac(
      encryptedBytes.sublist(21, 37),
    );
    final cipherText = encryptedBytes.sublist(37);

    final key = await _getOrCreateKey();

    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: mac,
    );

    try {
      final clearText = await _cipher.decrypt(
        secretBox,
        secretKey: key,
      );

      return Uint8List.fromList(clearText);
    } on SecretBoxAuthenticationError {
      throw FormatException(
        'تعذر التحقق من النسخة الاحتياطية: '
        'الملف تالف أو لا ينتمي إلى هذا الجهاز',
      );
    }
  }
}
