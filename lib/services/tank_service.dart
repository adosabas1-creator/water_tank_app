import '../core/database/database_helper.dart';
import '../models/tank.dart';

class TankService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<int> addTank(Tank tank) async {
    final db = await _dbHelper.database;
    return await db.insert('tanks', tank.toMap());
  }

  Future<List<Tank>> getAllTanks() async {
    final db = await _dbHelper.database;
    final result = await db.query('tanks', where: 'is_deleted = 0', orderBy: 'tank_number ASC');
    return result.map((e) => Tank.fromMap(e)).toList();
  }

  Future<Tank?> getTankById(int id) async {
    final db = await _dbHelper.database;
    final result = await db.query('tanks', where: 'id = ? AND is_deleted = 0', whereArgs: [id]);
    if (result.isNotEmpty) return Tank.fromMap(result.first);
    return null;
  }

  Future<void> updateTank(Tank tank) async {
    final db = await _dbHelper.database;
    await db.update('tanks', tank.toMap(), where: 'id = ?', whereArgs: [tank.id]);
  }

  Future<void> deleteTank(int id) async {
    final db = await _dbHelper.database;
    await db.update('tanks', {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
  }
}
