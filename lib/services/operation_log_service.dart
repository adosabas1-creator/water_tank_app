import 'package:uuid/uuid.dart';

import '../core/auth/permission_service.dart';
import '../core/database/database_helper.dart';
import '../models/operation_log.dart';

class OperationLogService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<String?> _localSyncId(
    dynamic db,
    String table,
    dynamic id,
  ) async {
    if (id == null) return null;

    final rows = await db.query(
      table,
      columns: ['sync_id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    final value = rows.first['sync_id']?.toString();
    if (value == null || value.isEmpty) return null;

    return value;
  }

  Future<int> addLog(OperationLog log) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    final data = log.toMap()
      ..remove('id')
      ..['sync_id'] = log.syncId ?? const Uuid().v4()
      ..['created_at'] = log.createdAt ?? now
      ..['updated_at'] = log.updatedAt ?? now
      ..['is_deleted'] = log.isDeleted
      ..['is_synced'] = 0;

    data['user_sync_id'] =
        await _localSyncId(db, 'users', log.userId);

    final recordTable = switch (log.tableName) {
      'clients' => 'clients',
      'suppliers' => 'suppliers',
      _ => null,
    };

    if (recordTable != null) {
      data['record_sync_id'] =
          await _localSyncId(db, recordTable, log.recordId);
    }

    return db.insert('operation_logs', data);
  }

  Future<List<OperationLog>> getAllLogs() async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'operation_logs',
      where: 'is_deleted = 0',
      orderBy: 'timestamp DESC',
    );
    return result.map((e) => OperationLog.fromMap(e)).toList();
  }

  Future<void> deleteLog(int id) async {
    PermissionService.requireAdmin();
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();

    await db.update(
      'operation_logs',
      {
        'is_deleted': 1,
        'is_synced': 0,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
