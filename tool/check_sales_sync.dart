import 'package:flutter/widgets.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dbPath = await getDatabasesPath();
  final path = p.join(dbPath, 'alborai_water_db.db');

  print('DB_PATH=$path');

  final db = await openDatabase(path);

  final rows = await db.query(
    'sales',
    columns: ['id', 'sale_number', 'sync_id', 'is_synced', 'updated_at'],
    where: 'is_synced = ?',
    whereArgs: [0],
    orderBy: 'id DESC',
    limit: 20,
  );

  print('UNSYNCED_SALES=${rows.length}');

  for (final row in rows) {
    print(row);
  }

  await db.close();
}
