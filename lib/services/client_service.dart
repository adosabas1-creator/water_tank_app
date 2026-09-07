import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../models/client.dart';

class ClientService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<int> addClient(Client client) async {
    final db = await _dbHelper.database;
    return await db.insert('clients', client.toMap());
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
    final db = await _dbHelper.database;
    await db.update('clients', client.toMap(), where: 'id = ?', whereArgs: [client.id]);
  }

  Future<void> deleteClient(int id) async {
    final db = await _dbHelper.database;
    await db.update('clients', {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
  }
}
