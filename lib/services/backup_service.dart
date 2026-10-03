import 'dart:io';

import 'package:cryptography/cryptography.dart' as crypto;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

import '../core/auth/permission_service.dart';
import '../core/constants/app_constants.dart';
import '../core/database/database_helper.dart';

class BackupPasswordRequired implements Exception {
  @override
  String toString() => 'كلمة مرور النسخة الاحتياطية مطلوبة';
}

class BackupService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static const List<int> _magic = <int>[0x41, 0x4C, 0x42, 0x32]; // ALB2
  static const int _manualMode = 0x01;
  static const int _deviceMode = 0x02;
  static const int _saltLength = 16;
  static const int _pbkdf2Iterations = 200000;
  static const String _deviceKeyName = 'encrypted_backup_device_key_v1';

  final crypto.Pbkdf2 _backupKdf = crypto.Pbkdf2(
    macAlgorithm: crypto.Hmac.sha256(),
    iterations: _pbkdf2Iterations,
    bits: 256,
  );

  final crypto.AesGcm _aes = crypto.AesGcm.with256bits();

  Future<String?> createManualBackup({
    required String password,
  }) async {
    PermissionService.requireManagementRole();
    _validateBackupPassword(password);

    final directory = await FilePicker.getDirectoryPath(
      dialogTitle: 'اختيار مكان حفظ النسخة الاحتياطية',
    );
    if (directory == null) return null;

    await _closeDatabase();

    final source = File(
      p.join(await getDatabasesPath(), AppConstants.localDbName),
    );
    if (!await source.exists()) {
      throw Exception('قاعدة البيانات غير موجودة');
    }

    final plainBytes = await source.readAsBytes();
    final salt = _randomBytes(_saltLength);
    final key = await _derivePasswordKey(password, salt);
    final encrypted = await _encrypt(plainBytes, key);

    final destination = File(
      p.join(directory, 'alborai_backup_${_stamp()}.albbackup'),
    );
    await destination.parent.create(recursive: true);
    await destination.writeAsBytes(
      _pack(_manualMode, salt, encrypted),
      flush: true,
    );

    return destination.path;
  }

  Future<bool> restoreBackup({
    String? password,
  }) async {
    PermissionService.requireAdmin();

    final result = await FilePicker.pickFile(
      dialogTitle: 'اختيار النسخة الاحتياطية المشفرة',
      type: FileType.any,
    );
    if (result == null) return false;

    final selectedPath = result.path;
    if (selectedPath == null) {
      throw Exception('تعذر الوصول إلى ملف النسخة الاحتياطية');
    }

    final source = File(selectedPath);
    final plainTemp = File(
      p.join(
        await getTemporaryDirectoryPath(),
        'alborai_restore_${DateTime.now().microsecondsSinceEpoch}.db',
      ),
    );

    try {
      final bytes = await source.readAsBytes();
      final parsed = _unpack(bytes);

      late final crypto.SecretKey key;
      if (parsed.mode == _manualMode) {
        if (password == null || password.isEmpty) {
          throw BackupPasswordRequired();
        }
        key = await _derivePasswordKey(password, parsed.salt);
      } else if (parsed.mode == _deviceMode) {
        key = await _deviceKey();
      } else {
        throw Exception('صيغة النسخة الاحتياطية غير معروفة');
      }

      final plainBytes = await _decrypt(parsed.secretBox, key);
      await plainTemp.writeAsBytes(plainBytes, flush: true);

      if (!await _isValidDatabase(plainTemp)) {
        throw Exception('النسخة الاحتياطية غير صالحة أو كلمة المرور غير صحيحة');
      }

      final currentPath = p.join(
        await getDatabasesPath(),
        AppConstants.localDbName,
      );

      await _closeDatabase();

      final current = File(currentPath);
      final safetyCopy = File('$currentPath.before_restore');
      if (await current.exists()) {
        await current.copy(safetyCopy.path);
      }

      await plainTemp.copy(currentPath);
      return true;
    } on crypto.SecretBoxAuthenticationError {
      throw Exception('كلمة مرور النسخة الاحتياطية غير صحيحة أو الملف تالف');
    } finally {
      try {
        if (await plainTemp.exists()) {
          await plainTemp.delete();
        }
      } catch (_) {}
    }
  }

  static const String _enabledKey = 'auto_backup_enabled';
  static const String _frequencyKey = 'auto_backup_frequency';
  static const String _lastBackupKey = 'auto_backup_last';

  Future<bool> isAutomaticBackupEnabled() async {
    final prefs = await _prefs();
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<String> getAutomaticBackupFrequency() async {
    final prefs = await _prefs();
    return prefs.getString(_frequencyKey) ?? 'daily';
  }

  Future<void> setAutomaticBackupEnabled(bool enabled) async {
    final prefs = await _prefs();
    await prefs.setBool(_enabledKey, enabled);
  }

  Future<void> setAutomaticBackupFrequency(String frequency) async {
    if (frequency != 'daily' && frequency != 'weekly') {
      throw ArgumentError('صيغة النسخ التلقائي غير صحيحة');
    }
    final prefs = await _prefs();
    await prefs.setString(_frequencyKey, frequency);
  }

  Future<bool> shouldRunAutomaticBackup() async {
    final prefs = await _prefs();
    if (!(prefs.getBool(_enabledKey) ?? false)) return false;

    final lastValue = prefs.getString(_lastBackupKey);
    if (lastValue == null) return true;

    final lastBackup = DateTime.tryParse(lastValue);
    if (lastBackup == null) return true;

    final frequency = prefs.getString(_frequencyKey) ?? 'daily';
    final interval = frequency == 'weekly'
        ? const Duration(days: 7)
        : const Duration(days: 1);

    return DateTime.now().difference(lastBackup) >= interval;
  }

  Future<void> runAutomaticBackupIfDue() async {
    if (!await shouldRunAutomaticBackup()) return;

    await automaticBackup();

    final prefs = await _prefs();
    await prefs.setString(
      _lastBackupKey,
      DateTime.now().toIso8601String(),
    );
  }

  Future<void> automaticBackup() async {
    final databaseDir = await getDatabasesPath();
    final backupDir = Directory(p.join(databaseDir, 'backups'));
    await backupDir.create(recursive: true);

    await _closeDatabase();

    final source = File(
      p.join(await getDatabasesPath(), AppConstants.localDbName),
    );
    if (!await source.exists()) return;

    final plainBytes = await source.readAsBytes();
    final key = await _deviceKey();
    final encrypted = await _encrypt(plainBytes, key);

    final target = File(
      p.join(backupDir.path, 'auto_${_stamp()}.albbackup'),
    );
    await target.writeAsBytes(
      _pack(_deviceMode, const <int>[], encrypted),
      flush: true,
    );

    final files = backupDir
        .listSync()
        .whereType<File>()
        .where((file) => p.basename(file.path).startsWith('auto_'))
        .toList()
      ..sort(
        (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
      );

    const keep = 7;
    for (final file in files.skip(keep)) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  Future<bool> _isValidDatabase(File file) async {
    if (!await file.exists()) return false;

    const requiredTables = <String>{
      'users',
      'clients',
      'suppliers',
      'drivers',
      'tanks',
      'filling_operations',
      'sales',
      'payments',
      'account_transactions',
      'purchase_invoices',
      'purchase_items',
      'inventory_layers',
      'sale_inventory_allocations',
      'expenses',
      'salaries',
      'operation_logs',
    };

    Database? db;
    try {
      db = await openReadOnlyDatabase(file.path);
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name IN "
        "('users','clients','suppliers','drivers','tanks','filling_operations',"
        "'sales','payments','account_transactions','purchase_invoices',"
        "'purchase_items','inventory_layers','sale_inventory_allocations',"
        "'expenses','salaries','operation_logs')",
      );

      final foundTables = tables
          .map((row) => row['name']?.toString())
          .whereType<String>()
          .toSet();

      return foundTables.length == requiredTables.length &&
          foundTables.containsAll(requiredTables);
    } catch (_) {
      return false;
    } finally {
      await db?.close();
    }
  }

  Future<crypto.SecretKey> _derivePasswordKey(
    String password,
    List<int> salt,
  ) async {
    return _backupKdf.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
  }

  Future<crypto.SecretKey> _deviceKey() async {
    final existing = await _secureStorage.read(key: _deviceKeyName);
    if (existing != null && existing.length == 64) {
      return _aes.newSecretKeyFromBytes(_hexToBytes(existing));
    }

    final key = await _aes.newSecretKey();
    final bytes = await key.extractBytes();
    await _secureStorage.write(
      key: _deviceKeyName,
      value: _bytesToHex(bytes),
    );
    return key;
  }

  Future<crypto.SecretBox> _encrypt(
    List<int> bytes,
    crypto.SecretKey key,
  ) {
    return _aes.encrypt(bytes, secretKey: key);
  }

  Future<List<int>> _decrypt(
    crypto.SecretBox box,
    crypto.SecretKey key,
  ) {
    return _aes.decrypt(box, secretKey: key);
  }

  List<int> _pack(
    int mode,
    List<int> salt,
    crypto.SecretBox box,
  ) {
    final data = <int>[
      ..._magic,
      mode,
      salt.length,
      ...salt,
      ...box.concatenation(),
    ];
    return data;
  }

  _ParsedBackup _unpack(List<int> bytes) {
    if (bytes.length < _magic.length + 2 ||
        !_listEquals(bytes.sublist(0, _magic.length), _magic)) {
      throw Exception('ملف النسخة الاحتياطية غير صالح');
    }

    final mode = bytes[4];
    final saltLength = bytes[5];
    final headerLength = 6 + saltLength;
    if (bytes.length <= headerLength) {
      throw Exception('ملف النسخة الاحتياطية ناقص');
    }

    final salt = bytes.sublist(6, headerLength);
    final boxBytes = bytes.sublist(headerLength);

    try {
      final box = crypto.SecretBox.fromConcatenation(
        boxBytes,
        nonceLength: _aes.nonceLength,
        macLength: _aes.macAlgorithm.macLength,
      );
      return _ParsedBackup(mode, salt, box);
    } catch (_) {
      throw Exception('ملف النسخة الاحتياطية تالف');
    }
  }

  List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  List<int> _hexToBytes(String value) {
    if (value.length.isOdd) throw FormatException('Invalid hex');
    return List<int>.generate(
      value.length ~/ 2,
      (i) => int.parse(value.substring(i * 2, i * 2 + 2), radix: 16),
    );
  }

  String _bytesToHex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _validateBackupPassword(String password) {
    if (password.length < 8) {
      throw ArgumentError(
        'كلمة مرور النسخة الاحتياطية يجب أن تكون 8 أحرف أو أكثر',
      );
    }
  }

  Future<dynamic> _prefs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs;
  }

  Future<String> getTemporaryDirectoryPath() async {
    final directory = Directory(
      p.join(await getDatabasesPath(), 'restore_tmp'),
    );
    await directory.create(recursive: true);
    return directory.path;
  }

  Future<void> _closeDatabase() async {
    await _dbHelper.closeDatabase();
  }

  String _stamp() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }
}

class _ParsedBackup {
  final int mode;
  final List<int> salt;
  final crypto.SecretBox secretBox;

  const _ParsedBackup(this.mode, this.salt, this.secretBox);
}
