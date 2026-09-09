import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../core/database/database_helper.dart';

class BackupService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<String?> createManualBackup() async {
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
      p.join(directory, 'alborai_backup_${_stamp()}.db'),
    );

    await destination.parent.create(recursive: true);
    await source.copy(destination.path);

    return destination.path;
  }

  Future<bool> restoreBackup() async {
    final result = await FilePicker.pickFile(
      dialogTitle: 'اختيار النسخة الاحتياطية',
      type: FileType.any,
    );

    if (result == null) return false;

    final selectedPath = result.path;

    if (selectedPath == null) {
      throw Exception('تعذر الوصول إلى ملف النسخة الاحتياطية');
    }

    final source = File(selectedPath);

    if (!await _isValidDatabase(source)) {
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

    await source.copy(currentPath);

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

    await automaticBackup();

    final prefs = await SharedPreferences.getInstance();
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

    final target = File(
      p.join(backupDir.path, 'auto_${_stamp()}.db'),
    );

    await source.copy(target.path);

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

    Database? db;

    try {
      db = await openReadOnlyDatabase(file.path);

      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master "
        "WHERE type='table' AND name IN "
        "('users','clients','suppliers','drivers','sales')",
      );

      return tables.length >= 5;
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
