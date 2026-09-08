import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../database/database_helper.dart';
import '../../models/user.dart';
import '../constants/permissions.dart';

class AuthService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<User?> login(String username, String password) async {
    final db = await _dbHelper.database;
    final passwordHash = _hashPassword(password);
    final result = await db.query(
      'users',
      where: 'username = ? AND password_hash = ?',
      whereArgs: [username, passwordHash],
    );
    if (result.isNotEmpty) {
      return User.fromMap(result.first);
    }
    return null;
  }

  Future<int> createUser({
    required String username,
    required String password,
    required String fullName,
    required String role,
    int? driverId,
    Map<String, bool>? permissions,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    final user = User(
      username: username,
      passwordHash: _hashPassword(password),
      fullName: fullName,
      role: role,
      driverId: driverId,
      permissions: permissions ?? _defaultPermissionsForRole(role),
      createdAt: now,
      updatedAt: now,
    );
    return await db.insert('users', user.toMap());
  }

  Future<void> updateDriver(int userId, int? driverId) async {
    final db = await _dbHelper.database;

    await db.update(
      'users',
      {
        'driver_id': driverId,
        'updated_at': DateTime.now().toIso8601String(),
        'is_synced': 0,
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> updatePermissions(
      int userId, Map<String, bool> newPermissions) async {
    final db = await _dbHelper.database;
    await db.update(
      'users',
      {
        'permissions': User.permissionsToJson(newPermissions),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<List<User>> getAllUsers() async {
    final db = await _dbHelper.database;
    final result = await db.query('users', where: 'is_deleted = 0');
    return result.map((e) => User.fromMap(e)).toList();
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Map<String, bool> _defaultPermissionsForRole(String role) {
    switch (role) {
      case 'admin':
        return DefaultPermissions.admin();

      case 'deputy_manager':
        return DefaultPermissions.deputyManager();

      case 'driver':
        return DefaultPermissions.driver();

      default:
        return DefaultPermissions.driver();
    }
  }
}
