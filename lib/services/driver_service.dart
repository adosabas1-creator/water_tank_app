import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../models/driver.dart';

class DriverService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<int> addDriver(Driver driver) async {
    final db = await _dbHelper.database;
    return await db.insert('drivers', driver.toMap());
  }

  Future<List<Driver>> getAllDrivers() async {
    final db = await _dbHelper.database;
    final result = await db.query('drivers', where: 'is_deleted = 0', orderBy: 'name ASC');
    return result.map((e) => Driver.fromMap(e)).toList();
  }

  Future<Driver?> getDriverById(int id) async {
    final db = await _dbHelper.database;
    final result = await db.query('drivers', where: 'id = ? AND is_deleted = 0', whereArgs: [id]);
    if (result.isNotEmpty) return Driver.fromMap(result.first);
    return null;
  }

  Future<void> updateDriver(Driver driver) async {
    final db = await _dbHelper.database;
    await db.update('drivers', driver.toMap(), where: 'id = ?', whereArgs: [driver.id]);
  }

  Future<void> deleteDriver(int id) async {
    final db = await _dbHelper.database;
    await db.update('drivers', {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
  }
}
