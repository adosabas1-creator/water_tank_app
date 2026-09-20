import 'dart:async';
import '../core/auth/permission_service.dart';
import '../core/constants/permissions.dart';
import '../core/database/database_helper.dart';
import '../core/network/sync_service.dart';
import '../models/client.dart';

class ClientService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<int> addClient(Client client) async {
    PermissionService.requirePermission(PermissionKeys.clientsAdd);
    final db = await _dbHelper.database;
    final id = await db.insert('clients', client.toMap());
    unawaited(SyncService().syncAll());
    return id;
  }

  Future<List<Client>> getAllClients() async {
    final db = await _dbHelper.database;
    final result = await db.query('clients', where: 'is_deleted = 0', orderBy: 'name ASC');
    return result.map((e) => Client.fromMap(e)).toList();
  }

  Future<Client?> getClientById(int id) async {
    final db = await _dbHelper.database;
    final result = await db.query('clients', where: 'id = ? AND is_deleted = 0', whereArgs: [id]);
    if (result.isNotEmpty) return Client.fromMap(result.first);
    return null;
  }

  Future<void> updateClient(Client client) async {
    PermissionService.requirePermission(PermissionKeys.clientsEdit);
    final db = await _dbHelper.database;
    final data = client.toMap();
    data['is_synced'] = 0;
    await db.update(
      'clients',
      data,
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [client.id],
    );
    unawaited(SyncService().syncAll());
  }

  Future<void> deleteClient(int id) async {
    PermissionService.requirePermission(PermissionKeys.clientsDelete);
    final db = await _dbHelper.database;
    await db.update(
      'clients',
      {
        'is_deleted': 1,
        'is_synced': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [id],
    );
    unawaited(SyncService().syncAll());
  }
}
