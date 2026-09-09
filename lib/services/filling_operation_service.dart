import '../core/database/database_helper.dart';
import '../models/filling_operation.dart';

class FillingOperationService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<int> addOperation(FillingOperation operation) async {
    final db = await _dbHelper.database;
    return await db.insert('filling_operations', operation.toMap());
  }

  Future<List<FillingOperation>> getAllOperations() async {
    final db = await _dbHelper.database;
    final result = await db.query('filling_operations',
        where: 'is_deleted = 0', orderBy: 'operation_date DESC');
    return result.map((e) => FillingOperation.fromMap(e)).toList();
  }

  Future<FillingOperation?> getOperationById(int id) async {
    final db = await _dbHelper.database;
    final result = await db.query('filling_operations',
        where: 'id = ? AND is_deleted = 0', whereArgs: [id]);
    if (result.isNotEmpty) return FillingOperation.fromMap(result.first);
    return null;
  }

  Future<void> updateOperation(FillingOperation operation) async {
    final db = await _dbHelper.database;
    final data = operation.toMap();
    data['is_synced'] = 0;
    await db.update('filling_operations', data,
        where: 'id = ?', whereArgs: [operation.id]);
  }

  Future<void> deleteOperation(int id) async {
    final db = await _dbHelper.database;
    await db.update(
        'filling_operations',
        {
          'is_deleted': 1,
          'is_synced': 0,
          'updated_at': DateTime.now().toIso8601String()
        },
        where: 'id = ?',
        whereArgs: [id]);
  }
}
