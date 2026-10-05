import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BackupEncryptionService {
  // Existing password-based manual backup format.
  static const String magic = 'WTBACK02';
  static const int version = 1;

  // Separate format for automatic backups.
  static const String autoMagic = 'WTBAUTO1';
  static const int autoVersion = 1;

  static const int saltLength = 16;
  static const int nonceLength = 12;
  static const int macLength = 16;
  static const int headerLength = 8 + 1 + saltLength + nonceLength + macLength;

  static const int autoKeyLength = 32;
  static const int autoHeaderLength = 8 + 1 + nonceLength + macLength;

  static const int pbkdf2Iterations = 100000;
  static const int minPasswordLength = 8;

  static const String _autoKeyStorageName = 'water_tank_auto_backup_key_v1';

  final AesGcm _cipher = AesGcm.with256bits();

  final Pbkdf2 _kdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: pbkdf2Iterations,
    bits: 256,
  );

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static bool isEncryptedBackup(Uint8List bytes) {
    if (bytes.length < 8) return false;

    final header = utf8.decode(
      bytes.sublist(0, 8),
      allowMalformed: true,
    );

    return header == magic || header == autoMagic;
  }

  static bool isAutomaticBackup(Uint8List bytes) {
    if (bytes.length < 8) return false;

    return utf8.decode(
          bytes.sublist(0, 8),
          allowMalformed: true,
        ) ==
        autoMagic;
  }

  void validatePassword(String password) {
    if (password.trim().length < minPasswordLength) {
      throw ArgumentError(
        'كلمة مرور النسخة يجب ألا تقل عن 8 أحرف',
      );
    }
  }

  Future<SecretKey> _deriveKey(
    String password,
    List<int> salt,
  ) {
    return _kdf.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
  }

  List<int> _randomBytes(int length) {
    final random = Random.secure();

    return List<int>.generate(
      length,
      (_) => random.nextInt(256),
    );
  }

  // ---------------------------------------------------------------------------
  // Manual password-protected backups
  // ---------------------------------------------------------------------------

  Future<Uint8List> encrypt({
    required Uint8List plainBytes,
    required String password,
  }) async {
    validatePassword(password);

    final salt = _randomBytes(saltLength);
    final key = await _deriveKey(password, salt);

    final secretBox = await _cipher.encrypt(
      plainBytes,
      secretKey: key,
    );

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
      throw const FormatException(
        'ملف النسخة قصير أو تالف',
      );
    }

    final actualMagic = utf8.decode(
      encryptedBytes.sublist(0, 8),
      allowMalformed: true,
    );

    if (actualMagic != magic) {
      throw const FormatException(
        'الملف ليس نسخة يدوية مشفّرة من التطبيق',
      );
    }

    if (encryptedBytes[8] != version) {
      throw const FormatException(
        'إصدار الملف غير مدعوم',
      );
    }

    final salt = encryptedBytes.sublist(9, 25);
    final nonce = encryptedBytes.sublist(25, 37);
    final mac = Mac(
      encryptedBytes.sublist(37, 53),
    );
    final cipherText = encryptedBytes.sublist(53);

    final key = await _deriveKey(password, salt);

    try {
      final clearText = await _cipher.decrypt(
        SecretBox(
          cipherText,
          nonce: nonce,
          mac: mac,
        ),
        secretKey: key,
      );

      return Uint8List.fromList(clearText);
    } on SecretBoxAuthenticationError {
      throw const FormatException(
        'كلمة المرور غير صحيحة أو الملف تالف',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Automatic backups
  // ---------------------------------------------------------------------------

  Future<SecretKey> _getOrCreateAutomaticKey() async {
    final storedKey = await _secureStorage.read(
      key: _autoKeyStorageName,
    );

    if (storedKey != null && storedKey.isNotEmpty) {
      try {
        final keyBytes = base64Url.decode(storedKey);

        if (keyBytes.length == autoKeyLength) {
          return SecretKey(keyBytes);
        }
      } catch (_) {
        // An existing but invalid key must never be replaced automatically.
      }

      throw StateError(
        'مفتاح النسخ التلقائية المخزن غير صالح',
      );
    }

    final keyBytes = _randomBytes(autoKeyLength);

    await _secureStorage.write(
      key: _autoKeyStorageName,
      value: base64UrlEncode(keyBytes),
    );

    return SecretKey(keyBytes);
  }

  Future<SecretKey> _getExistingAutomaticKey() async {
    final storedKey = await _secureStorage.read(
      key: _autoKeyStorageName,
    );

    if (storedKey == null || storedKey.isEmpty) {
      throw StateError(
        'مفتاح النسخة التلقائية غير موجود على هذا الجهاز',
      );
    }

    try {
      final keyBytes = base64Url.decode(storedKey);
      if (keyBytes.length == autoKeyLength) {
        return SecretKey(keyBytes);
      }
    } catch (_) {
      // Fall through to the clear error below.
    }

    throw StateError(
      'مفتاح النسخ التلقائية المخزن غير صالح',
    );
  }

  Future<Uint8List> encryptAutomatic({
    required Uint8List plainBytes,
  }) async {
    final key = await _getOrCreateAutomaticKey();

    // AesGcm generates a fresh cryptographically secure nonce
    // when none is supplied.
    final secretBox = await _cipher.encrypt(
      plainBytes,
      secretKey: key,
    );

    final output = BytesBuilder(copy: false);

    output.add(utf8.encode(autoMagic));
    output.addByte(autoVersion);
    output.add(secretBox.nonce);
    output.add(secretBox.mac.bytes);
    output.add(secretBox.cipherText);

    return output.toBytes();
  }

  Future<Uint8List> decryptAutomatic({
    required Uint8List encryptedBytes,
  }) async {
    if (encryptedBytes.length < autoHeaderLength) {
      throw const FormatException(
        'ملف النسخة التلقائية قصير أو تالف',
      );
    }

    final actualMagic = utf8.decode(
      encryptedBytes.sublist(0, 8),
      allowMalformed: true,
    );

    if (actualMagic != autoMagic) {
      throw const FormatException(
        'الملف ليس نسخة تلقائية من التطبيق',
      );
    }

    if (encryptedBytes[8] != autoVersion) {
      throw const FormatException(
        'إصدار النسخة التلقائية غير مدعوم',
      );
    }

    final nonce = encryptedBytes.sublist(9, 21);
    final mac = Mac(
      encryptedBytes.sublist(21, 37),
    );
    final cipherText = encryptedBytes.sublist(37);

    final key = await _getExistingAutomaticKey();

    try {
      final clearText = await _cipher.decrypt(
        SecretBox(
          cipherText,
          nonce: nonce,
          mac: mac,
        ),
        secretKey: key,
      );

      return Uint8List.fromList(clearText);
    } on SecretBoxAuthenticationError {
      throw const FormatException(
        'مفتاح النسخة التلقائية غير صالح أو الملف تالف',
      );
    }
  }
}
