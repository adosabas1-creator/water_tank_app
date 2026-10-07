import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:water_tank_app/core/auth/permission_service.dart';
import 'package:water_tank_app/core/database/database_helper.dart';
import 'package:water_tank_app/models/sale.dart';
import 'package:water_tank_app/models/user.dart';
import 'package:water_tank_app/services/sale_service.dart';

void main() {
  late Directory testDirectory;
  late DatabaseHelper dbHelper;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    testDirectory = await Directory.systemTemp.createTemp(
      'water_tank_sale_service_test_',
    );
    await databaseFactory.setDatabasesPath(testDirectory.path);
  });

  setUp(() async {
    dbHelper = DatabaseHelper();
    await dbHelper.closeDatabase();

    final now = DateTime.now().toIso8601String();

    PermissionService.setCurrentUser(
      User(
        id: 1,
        syncId: 'test-admin-sync-id',
        username: 'test_admin',
        passwordHash: 'test',
        passwordHashVersion: 2,
        fullName: 'Test Admin',
        role: 'admin',
        permissions: const {},
        createdAt: now,
        updatedAt: now,
      ),
    );
  });

  tearDown(() async {
    await dbHelper.closeDatabase();
    PermissionService.setCurrentUser(null);
  });

  tearDownAll(() async {
    if (testDirectory.existsSync()) {
      await testDirectory.delete(recursive: true);
    }
  });

  test('SaleService.addSale يستخدم FIFO الحقيقي ويحفظ المبيعة والتخصيصات',
      () async {
    final db = await dbHelper.database;

    await db.insert('users', {
      'id': 1,
      'username': 'test_admin',
      'password_hash': 'test',
      'password_hash_version': 2,
      'full_name': 'Test Admin',
      'role': 'admin',
      'permissions': '{}',
      'created_at': '2026-01-01T00:00:00.000',
      'updated_at': '2026-01-01T00:00:00.000',
      'is_deleted': 0,
      'is_synced': 1,
      'sync_id': 'test-admin-sync-id',
    });

    final supplierId = await db.insert('suppliers', {
      'sync_id': 'supplier-test-1',
      'supplier_number': 'SUP-TEST-1',
      'name': 'مورد اختبار',
      'status': 'active',
      'created_at': '2026-01-01T00:00:00.000',
      'updated_at': '2026-01-01T00:00:00.000',
      'is_deleted': 0,
      'is_synced': 1,
    });

    final invoiceId = await db.insert('purchase_invoices', {
      'invoice_number': 'PINV-TEST-1',
      'supplier_id': supplierId,
      'purchase_date': '2026-01-01T00:00:00.000',
      'total_amount': 250.0,
      'payment_status': 'paid',
      'created_by': 1,
      'created_at': '2026-01-01T00:00:00.000',
      'updated_at': '2026-01-01T00:00:00.000',
      'is_deleted': 0,
      'is_synced': 1,
      'sync_id': 'purchase-invoice-test-1',
    });

    final purchaseItemId = await db.insert('purchase_items', {
      'purchase_invoice_id': invoiceId,
      'item_type': 'tank',
      'units': 15,
      'purchase_price': 10.0,
      'total_amount': 150.0,
      'created_at': '2026-01-01T00:00:00.000',
      'updated_at': '2026-01-01T00:00:00.000',
      'is_deleted': 0,
      'is_synced': 1,
      'sync_id': 'purchase-item-test-1',
    });

    await db.insert('inventory_layers', {
      'purchase_item_id': purchaseItemId,
      'item_type': 'tank',
      'original_units': 5,
      'remaining_units': 5,
      'unit_cost': 10.0,
      'layer_date': '2026-01-01T00:00:00.000',
      'created_at': '2026-01-01T00:00:00.000',
      'updated_at': '2026-01-01T00:00:00.000',
      'is_deleted': 0,
      'is_synced': 1,
      'sync_id': 'inventory-layer-test-1',
    });

    await db.insert('inventory_layers', {
      'purchase_item_id': purchaseItemId,
      'item_type': 'tank',
      'original_units': 10,
      'remaining_units': 10,
      'unit_cost': 20.0,
      'layer_date': '2026-02-01T00:00:00.000',
      'created_at': '2026-02-01T00:00:00.000',
      'updated_at': '2026-02-01T00:00:00.000',
      'is_deleted': 0,
      'is_synced': 1,
      'sync_id': 'inventory-layer-test-2',
    });

    final sale = Sale(
      syncId: const Uuid().v4(),
      saleNumber: 'SALE-TEST-1',
      supplierId: supplierId,
      units: 7,
      salePrice: 25.0,
      totalAmount: 175.0,
      costAmount: 0,
      profitAmount: 0,
      saleDate: '2026-03-01T00:00:00.000',
      paymentStatus: 'paid',
      clientPaymentStatus: 'paid',
      createdByName: 'Test Admin',
      createdBy: 1,
      createdAt: '2026-03-01T00:00:00.000',
      updatedAt: '2026-03-01T00:00:00.000',
    );

    final result = await SaleService().addSale(sale);

    expect(result.id, isNotNull);
    expect(result.units, 7);
    expect(result.totalAmount, 175.0);
    expect(result.costAmount, 90.0);
    expect(result.profitAmount, 85.0);
    expect(result.isSynced, isFalse);

    final sales = await db.query(
      'sales',
      where: 'id = ?',
      whereArgs: [result.id],
    );

    expect(sales, hasLength(1));
    expect(sales.first['cost_amount'], 90.0);
    expect(sales.first['profit_amount'], 85.0);
    expect(sales.first['is_synced'], 0);

    final allocations = await db.query(
      'sale_inventory_allocations',
      where: 'sale_id = ?',
      whereArgs: [result.id],
      orderBy: 'id ASC',
    );

    expect(allocations, hasLength(2));
    expect(allocations[0]['units'], 5);
    expect(allocations[0]['unit_cost'], 10.0);
    expect(allocations[0]['cost_amount'], 50.0);
    expect(allocations[1]['units'], 2);
    expect(allocations[1]['unit_cost'], 20.0);
    expect(allocations[1]['cost_amount'], 40.0);

    final layers = await db.query(
      'inventory_layers',
      orderBy: 'layer_date ASC, id ASC',
    );

    expect(layers, hasLength(2));
    expect(layers[0]['remaining_units'], 0);
    expect(layers[0]['is_synced'], 0);
    expect(layers[1]['remaining_units'], 8);
    expect(layers[1]['is_synced'], 0);
  });
}
