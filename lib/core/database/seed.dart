import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'database_helper.dart';

Future<void> seedAdminUser() async {
  final db = await DatabaseHelper().database;

  final existingAdmin = await db.query(
    'users',
    where: 'username = ?',
    whereArgs: ['admin'],
    limit: 1,
  );

  if (existingAdmin.isEmpty) {
    final now = DateTime.now().toIso8601String();
    final passwordHash = sha256.convert(utf8.encode('admin123')).toString();

    await db.insert('users', {
      'sync_id': const Uuid().v4(),
      'username': 'admin',
      'password_hash': passwordHash,
      'full_name': 'مدير النظام',
      'role': 'admin',
      'permissions':
          '{"clients_view":true,"clients_add":true,"clients_edit":true,"clients_delete":true,"sales_view":true,"sales_add":true,"sales_edit":true,"sales_delete":true,"suppliers_view":true,"suppliers_add":true,"suppliers_edit":true,"suppliers_delete":true,"client_statements_view":true,"supplier_statements_view":true,"profits_view":true,"prices_edit":true,"users_manage":true,"permissions_manage":true}',
      'created_at': now,
      'updated_at': now,
      'is_deleted': 0,
      'is_synced': 0,
      'must_change_password': 0,
    });

    debugPrint('Admin user created successfully');
  } else {
    debugPrint('Admin user already exists');
  }

  final defaultPasswordHash = sha256.convert(utf8.encode('1234')).toString();

  const defaultPermissions =
      '{"clients_view":true,"clients_add":true,"clients_edit":true,"clients_delete":false,"sales_view":true,"sales_add":true,"sales_edit":false,"sales_delete":false,"suppliers_view":true,"suppliers_add":false,"suppliers_edit":false,"suppliers_delete":false,"client_statements_view":true,"supplier_statements_view":false,"profits_view":false,"prices_edit":false,"users_manage":false,"permissions_manage":false}';

  for (int i = 1; i <= 10; i++) {
    final username = 'مستخدم $i';

    final userExists = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
      limit: 1,
    );

    if (userExists.isEmpty) {
      final now = DateTime.now().toIso8601String();

      await db.insert('users', {
        'sync_id': const Uuid().v4(),
        'username': username,
        'password_hash': defaultPasswordHash,
        'full_name': username,
        'role': 'driver',
        'permissions': defaultPermissions,
        'created_at': now,
        'updated_at': now,
        'is_deleted': 0,
        'is_synced': 0,
        'must_change_password': 1,
      });

      debugPrint('$username created successfully');
    }
  }
}
