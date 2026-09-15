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


}
