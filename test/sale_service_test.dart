import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

Future<double> allocateFifo(Database db, int units, int supplierId) async {
  final layers = await db.rawQuery('''
    SELECT l.id, l.remaining_units, l.unit_cost
    FROM inventory_layers l
    JOIN purchase_items pi ON pi.id = l.purchase_item_id AND pi.is_deleted = 0
    JOIN purchase_invoices inv ON inv.id = pi.purchase_invoice_id AND inv.is_deleted = 0
    WHERE l.item_type = 'tank' AND l.is_deleted = 0 AND l.remaining_units > 0
      AND inv.supplier_id = ?
    ORDER BY l.layer_date ASC, l.id ASC
  ''', [supplierId]);

  final available = layers.fold<int>(
    0,
    (s, r) => s + (r['remaining_units'] as num).toInt(),
  );
  if (available < units) {
    throw Exception('لا توجد كمية كافية في المخزون.');
  }

  var left = units;
  var cost = 0.0;
  for (final layer in layers) {
    if (left <= 0) break;
    final rem = (layer['remaining_units'] as num).toInt();
    final take = rem < left ? rem : left;
    cost += take * (layer['unit_cost'] as num).toDouble();
    await db.update(
      'inventory_layers',
      {'remaining_units': rem - take, 'is_synced': 0},
      where: 'id = ?',
      whereArgs: [layer['id']],
    );
    left -= take;
  }
  return cost;
}

Future<Database> openDb() async {
  return databaseFactory.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE purchase_invoices (id INTEGER PRIMARY KEY, supplier_id INTEGER, is_deleted INTEGER DEFAULT 0)',
        );
        await db.execute(
          'CREATE TABLE purchase_items (id INTEGER PRIMARY KEY, purchase_invoice_id INTEGER, is_deleted INTEGER DEFAULT 0)',
        );
        await db.execute(
          'CREATE TABLE inventory_layers (id INTEGER PRIMARY KEY, purchase_item_id INTEGER, item_type TEXT, remaining_units INTEGER, unit_cost REAL, layer_date TEXT, is_deleted INTEGER DEFAULT 0, is_synced INTEGER DEFAULT 0)',
        );
        await db.execute(
          'CREATE TABLE sales (id INTEGER PRIMARY KEY, sync_id TEXT UNIQUE, supplier_id INTEGER, units INTEGER, total_amount REAL, cost_amount REAL, profit_amount REAL, is_synced INTEGER DEFAULT 0)',
        );
      },
    ),
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('FIFO داخل transaction يحسب التكلفة من الأقدم', () async {
    final db = await openDb();
    await db.transaction((txn) async {
      final inv = await txn.insert('purchase_invoices', {
        'supplier_id': 1,
        'is_deleted': 0,
      });
      final item = await txn.insert('purchase_items', {
        'purchase_invoice_id': inv,
        'is_deleted': 0,
      });
      await txn.insert('inventory_layers', {
        'purchase_item_id': item,
        'item_type': 'tank',
        'remaining_units': 5,
        'unit_cost': 10,
        'layer_date': '2026-01-01',
        'is_deleted': 0,
        'is_synced': 1,
      });
      await txn.insert('inventory_layers', {
        'purchase_item_id': item,
        'item_type': 'tank',
        'remaining_units': 10,
        'unit_cost': 20,
        'layer_date': '2026-02-01',
        'is_deleted': 0,
        'is_synced': 1,
      });
    });

    final cost = await allocateFifo(db, 7, 1);
    expect(cost, 90);

    final layers = await db.query('inventory_layers', orderBy: 'id');
    expect(layers[0]['remaining_units'], 0);
    expect(layers[1]['remaining_units'], 8);
    await db.close();
  });

  test('إضافة مبيعة is_synced=0 ثم الاسترجاع', () async {
    final db = await openDb();
    final syncId = const Uuid().v4();

    await db.transaction((txn) async {
      await txn.insert('sales', {
        'sync_id': syncId,
        'supplier_id': 1,
        'units': 3,
        'total_amount': 150,
        'cost_amount': 30,
        'profit_amount': 120,
        'is_synced': 0,
      });
    });

    final rows = await db.query(
      'sales',
      where: 'sync_id = ?',
      whereArgs: [syncId],
    );
    expect(rows.length, 1);
    expect(rows.first['is_synced'], 0);
    expect(rows.first['profit_amount'], 120);
    await db.close();
  });

  test('FIFO يرفض عند نقص المخزون', () async {
    final db = await openDb();
    final inv = await db.insert('purchase_invoices', {
      'supplier_id': 1,
      'is_deleted': 0,
    });
    final item = await db.insert('purchase_items', {
      'purchase_invoice_id': inv,
      'is_deleted': 0,
    });
    await db.insert('inventory_layers', {
      'purchase_item_id': item,
      'item_type': 'tank',
      'remaining_units': 2,
      'unit_cost': 10,
      'layer_date': '2026-01-01',
      'is_deleted': 0,
      'is_synced': 1,
    });
    expect(() => allocateFifo(db, 5, 1), throwsException);
    await db.close();
  });
}
