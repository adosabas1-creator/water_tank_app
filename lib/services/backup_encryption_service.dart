import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class BackupEncryptionService {
  static const String magic = 'WTBACK02';
  static const int version = 1;
  static const int saltLength = 16;
  static const int nonceLength = 12;
  static const int macLength = 16;
  static const int headerLength = 8 + 1 + saltLength + nonceLength + macLength;
  static const int pbkdf2Iterations = 100000;
  static const int minPasswordLength = 8;

  final AesGcm _cipher = AesGcm.with256bits();
  final Pbkdf2 _kdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: pbkdf2Iterations,
    bits: 256,
  );

  static bool isEncryptedBackup(Uint8List bytes) {
    if (bytes.length < 8) return false;
    return utf8.decode(bytes.sublist(0, 8), allowMalformed: true) == magic;
  }

  void validatePassword(String password) {
    if (password.trim().length < minPasswordLength) {
      throw ArgumentError('كلمة مرور النسخة يجب ألا تقل عن 8 أحرف');
    }
  }

  Future<SecretKey> _deriveKey(String password, List<int> salt) {
    return _kdf.deriveKeyFromPassword(password: password, nonce: salt);
  }

  List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  Future<Uint8List> encrypt({
    required Uint8List plainBytes,
    required String password,
  }) async {
    validatePassword(password);
    final salt = _randomBytes(saltLength);
    final key = await _deriveKey(password, salt);
    final secretBox = await _cipher.encrypt(plainBytes, secretKey: key);
    final output = BytesBuilder(copy: false);
    output.add(utf8.encode(magic));
    output.addByte(version);
    output.add(salt);
    output.add(secretBox.nonce);
    output.add(secretBox.mac.bytes);
    output.add(secretBox.cipherText);
    return output.toBytes();
  }

  Future<Uint8List> decrypt({
    required Uint8List encryptedBytes,
    required String password,
  }) async {
    validatePassword(password);
    if (encryptedBytes.length < headerLength) {
      throw const FormatException('ملف النسخة قصير أو تالف');
    }
    final actualMagic = utf8.decode(encryptedBytes.sublist(0, 8), allowMalformed: true);
    if (actualMagic != magic) {
      throw const FormatException('الملف ليس نسخة مشفّرة من التطبيق');
    }
    if (encryptedBytes[8] != version) {
      throw const FormatException('إصدار الملف غير مدعوم');
    }
    final salt = encryptedBytes.sublist(9, 25);
    final nonce = encryptedBytes.sublist(25, 37);
    final mac = Mac(encryptedBytes.sublist(37, 53));
    final cipherText = encryptedBytes.sublist(53);
    final key = await _deriveKey(password, salt);
    try {
      final clearText = await _cipher.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: mac),
        secretKey: key,
      );
      return Uint8List.fromList(clearText);
    } on SecretBoxAuthenticationError {
      throw const FormatException('كلمة المرور غير صحيحة أو الملف تالف');
    }
  }
}
