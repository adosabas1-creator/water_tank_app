import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/auth/permission_service.dart';
import '../core/constants/app_constants.dart';
import '../core/database/database_helper.dart';
import 'backup_encryption_service.dart';

enum BackupFileType {
  automatic,
  manual,
  invalid,
}

class BackupFile {
  final String path;
  final BackupFileType type;

  const BackupFile({
    required this.path,
    required this.type,
  });
}

class BackupService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final BackupEncryptionService _encryption = BackupEncryptionService();

  Future<String?> createManualBackup({required String password}) async {
    PermissionService.requireManagementRole();
    _encryption.validatePassword(password);
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

    final destination = File(
      p.join(directory, 'alborai_backup_${_stamp()}.wtbak'),
    );

    final plainBytes = await source.readAsBytes();
    final encryptedBytes = await _encryption.encrypt(
      plainBytes: Uint8List.fromList(plainBytes),
      password: password,
    );
    await destination.parent.create(recursive: true);
    await destination.writeAsBytes(encryptedBytes, flush: true);

    return destination.path;
  }

  Future<BackupFile?> pickBackupFile() async {
    final result = await FilePicker.pickFile(
      dialogTitle: 'اختيار النسخة الاحتياطية',
      type: FileType.any,
    );

    if (result == null) return null;

    final selectedPath = result.path;
    if (selectedPath == null) {
      throw Exception('تعذر الوصول إلى ملف النسخة الاحتياطية');
    }

    final source = File(selectedPath);
    if (!await source.exists()) {
      throw Exception('ملف النسخة الاحتياطية غير موجود');
    }

    final bytes = Uint8List.fromList(await source.readAsBytes());

    final type = BackupEncryptionService.isAutomaticBackup(bytes)
        ? BackupFileType.automatic
        : BackupEncryptionService.isEncryptedBackup(bytes)
            ? BackupFileType.manual
            : BackupFileType.invalid;

    return BackupFile(
      path: selectedPath,
      type: type,
    );
  }

  Future<bool> restoreBackup({
    required BackupFile backup,
    String? password,
  }) async {
    PermissionService.requireAdmin();

    if (backup.type == BackupFileType.invalid) {
      throw Exception(
        'الملف المحدد ليس نسخة احتياطية مشفّرة صالحة',
      );
    }

    final source = File(backup.path);

    if (!await source.exists()) {
      throw Exception('ملف النسخة الاحتياطية غير موجود');
    }

    final bytes = Uint8List.fromList(
      await source.readAsBytes(),
    );
    File databaseFile = source;
    File? tempFile;
    if (BackupEncryptionService.isAutomaticBackup(bytes)) {
      final plain = await _encryption.decryptAutomatic(
        encryptedBytes: bytes,
      );
      tempFile = File(
        p.join(
          Directory.systemTemp.path,
          'alborai_restore_${_stamp()}.db',
        ),
      );
      await tempFile.writeAsBytes(plain, flush: true);
      databaseFile = tempFile;
    } else if (BackupEncryptionService.isEncryptedBackup(bytes)) {
      final manualPassword = password;
      if (manualPassword == null || manualPassword.isEmpty) {
        throw StateError('هذه نسخة احتياطية يدوية وتتطلب كلمة مرور');
      }
      _encryption.validatePassword(manualPassword);
      final plain = await _encryption.decrypt(
        encryptedBytes: bytes,
        password: manualPassword,
      );
      tempFile = File(
        p.join(
          Directory.systemTemp.path,
          'alborai_restore_${_stamp()}.db',
        ),
      );
      await tempFile.writeAsBytes(plain, flush: true);
      databaseFile = tempFile;
    }
    if (!await _isValidDatabase(databaseFile)) {
      await tempFile?.delete();
      throw Exception(
        'الملف المحدد ليس نسخة احتياطية صالحة لقاعدة بيانات شركة البرعي للمياه',
      );
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

    await databaseFile.copy(currentPath);
    await tempFile?.delete();

    return true;
  }

  static const String _enabledKey = 'auto_backup_enabled';
  static const String _frequencyKey = 'auto_backup_frequency';
  static const String _lastBackupKey = 'auto_backup_last';

  Future<bool> isAutomaticBackupEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<String> getAutomaticBackupFrequency() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_frequencyKey) ?? 'daily';
  }

  Future<void> setAutomaticBackupEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);
  }

  Future<void> setAutomaticBackupFrequency(String frequency) async {
    if (frequency != 'daily' && frequency != 'weekly') {
      throw ArgumentError('صيغة النسخ التلقائي غير صحيحة');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_frequencyKey, frequency);
  }

  Future<bool> shouldRunAutomaticBackup() async {
    final prefs = await SharedPreferences.getInstance();

    if (!(prefs.getBool(_enabledKey) ?? false)) {
      return false;
    }

    final lastValue = prefs.getString(_lastBackupKey);

    if (lastValue == null) {
      return true;
    }

    final lastBackup = DateTime.tryParse(lastValue);

    if (lastBackup == null) {
      return true;
    }

    final frequency = prefs.getString(_frequencyKey) ?? 'daily';
    final interval = frequency == 'weekly'
        ? const Duration(days: 7)
        : const Duration(days: 1);

    return DateTime.now().difference(lastBackup) >= interval;
  }

  Future<void> runAutomaticBackupIfDue() async {
    if (!await shouldRunAutomaticBackup()) {
      return;
    }

    final success = await automaticBackup();

    if (!success) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _lastBackupKey,
      DateTime.now().toIso8601String(),
    );
  }

  Future<bool> automaticBackup() async {
    final databaseDir = await getDatabasesPath();
    final backupDir = Directory(p.join(databaseDir, 'backups'));

    await backupDir.create(recursive: true);
    await _closeDatabase();

    final source = File(
      p.join(await getDatabasesPath(), AppConstants.localDbName),
    );

    if (!await source.exists()) {
      return false;
    }

    final plainBytes = Uint8List.fromList(
      await source.readAsBytes(),
    );

    final encryptedBytes = await _encryption.encryptAutomatic(
      plainBytes: plainBytes,
    );

    final target = File(
      p.join(backupDir.path, 'auto_${_stamp()}.wtbak'),
    );

    await target.writeAsBytes(
      encryptedBytes,
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

    return true;
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
        "SELECT name FROM sqlite_master "
        "WHERE type='table' AND name IN "
        "('users','clients','suppliers','drivers','tanks',"
        "'filling_operations','sales','payments','account_transactions',"
        "'purchase_invoices','purchase_items','inventory_layers',"
        "'sale_inventory_allocations','expenses','salaries','operation_logs')",
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
