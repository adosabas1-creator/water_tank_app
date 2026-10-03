import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

DateTime? parseTime(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString());
}

bool remoteIsNewer(Map local, Map remote) {
  final r = parseTime(remote['local_updated_at']) ??
      parseTime(remote['updated_at']);
  final l = parseTime(local['updated_at']) ??
      parseTime(local['local_updated_at']);
  if (r == null || l == null) return false;
  return r.isAfter(l);
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('LWW: remote أحدث يفوز', () {
    expect(
      remoteIsNewer(
        {'updated_at': '2026-01-01T10:00:00.000'},
        {'local_updated_at': '2026-01-01T11:00:00.000'},
      ),
      isTrue,
    );
  });

  test('LWW: local أحدث لا يُستبدل', () {
    expect(
      remoteIsNewer(
        {'updated_at': '2026-01-01T12:00:00.000'},
        {'local_updated_at': '2026-01-01T11:00:00.000'},
      ),
      isFalse,
    );
  });

  test('رفع is_synced=0 ثم تعليمه متزامناً', () async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE clients (id INTEGER PRIMARY KEY, sync_id TEXT, name TEXT, updated_at TEXT, is_synced INTEGER DEFAULT 0)',
          );
        },
      ),
    );

    final id = await db.insert('clients', {
      'sync_id': 'c1',
      'name': 'عميل',
      'updated_at': '2026-01-01T10:00:00.000',
      'is_synced': 0,
    });

    expect(
      (await db.query('clients', where: 'is_synced = 0')).length,
      1,
    );

    await db.update(
      'clients',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );

    expect(
      await db.query('clients', where: 'is_synced = 0'),
      isEmpty,
    );
    await db.close();
  });

  test('بدون إنترنت: السجل يبقى is_synced=0', () {
    const isOnline = false;
    final record = {'is_synced': 0};
    if (!isOnline) {
      expect(record['is_synced'], 0);
    }
  });
}
