import '../core/database/database_helper.dart';
import '../models/operation_log.dart';

class OperationLogService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<int> addLog(OperationLog log) async {
    final db = await _dbHelper.database;
    return await db.insert('operation_logs', log.toMap());
  }

  Future<List<OperationLog>> getAllLogs() async {
    final db = await _dbHelper.database;
    final result = await db.query('operation_logs', orderBy: 'timestamp DESC');
    return result.map((e) => OperationLog.fromMap(e)).toList();
  }

  Future<void> deleteLog(int id) async {
    final db = await _dbHelper.database;
    await db.delete('operation_logs', where: 'id = ?', whereArgs: [id]);
  }
}
