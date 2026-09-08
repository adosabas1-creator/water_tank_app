import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import 'database_helper.dart';

Future<void> seedAdminUser() async {
  final db = await DatabaseHelper().database;

  final existing = await db.query(
    'users',
    where: 'username = ?',
    whereArgs: ['admin'],
    limit: 1,
  );

  if (existing.isNotEmpty) {
    print('Admin user already exists');
    return;
  }

  final now = DateTime.now().toIso8601String();
  final passwordHash =
      sha256.convert(utf8.encode('admin123')).toString();

  await db.insert('users', {
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
  });

  print('Admin user created successfully');
}
