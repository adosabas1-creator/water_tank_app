import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';

import 'package:water_tank_app/core/auth/permission_service.dart';
import 'package:water_tank_app/core/constants/permissions.dart';
import 'package:water_tank_app/core/database/database_helper.dart';
import 'package:water_tank_app/core/database/financial_migration.dart';
import 'package:water_tank_app/models/sale.dart';
import 'package:water_tank_app/models/user.dart';
import 'package:water_tank_app/services/sale_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseHelper helper;
  late Database db;
  late SaleService service;
  late int userId;
  late int supplierId;
  late int invoiceId;
  late int itemId;
  late int layerId;
  late int saleId;

  setUpAll(() async {
    helper = DatabaseHelper();
    await helper.closeDatabase();
    db = await helper.database;
    await FinancialMigration.migrate(db);

    final now = DateTime.now().toIso8601String();
    final user = User(
      syncId: 'sale-tx-admin',
      username: 'sale_tx_admin',
      passwordHash: 'test',
      recoveryCodeHash: null,
      fullName: 'Sale Tx Admin',
      role: 'admin',
      permissions: DefaultPermissions.admin(),
      createdAt: now,
      updatedAt: now,
    );
    userId = await db.insert('users', user.toMap()..remove('id'));
    PermissionService.setCurrentUser(User(
      id: userId,
      syncId: user.syncId,
      username: user.username,
      passwordHash: user.passwordHash,
      recoveryCodeHash: null,
      fullName: user.fullName,
      role: user.role,
      permissions: user.permissions,
      createdAt: now,
      updatedAt: now,
    ));

    supplierId = await db.insert('suppliers', {
      'sync_id': 'sale-tx-supplier',
      'supplier_number': 'TX-001',
      'name': 'Transaction Supplier',
      'phone': null,
      'location': null,
      'status': 'active',
      'notes': null,
      'created_at': now,
      'updated_at': now,
      'is_deleted': 0,
      'is_synced': 0,
    });

    invoiceId = await db.insert('purchase_invoices', {
      'invoice_number': 'TX-INV',
      'supplier_id': supplierId,
      'purchase_date': now,
      'total_amount': 1000.0,
      'payment_status': 'unpaid',
      'notes': null,
      'created_by': userId,
      'created_at': now,
      'updated_at': now,
      'is_deleted': 0,
      'is_synced': 0,
      'sync_id': 'sale-tx-invoice',
    });
    itemId = await db.insert('purchase_items', {
      'purchase_invoice_id': invoiceId,
      'item_type': 'tank',
      'units': 10,
      'purchase_price': 100.0,
      'total_amount': 1000.0,
      'created_at': now,
      'updated_at': now,
      'is_deleted': 0,
      'is_synced': 0,
      'sync_id': 'sale-tx-item',
    });
    layerId = await db.insert('inventory_layers', {
      'purchase_item_id': itemId,
      'item_type': 'tank',
      'original_units': 10,
      'remaining_units': 7,
      'unit_cost': 100.0,
      'layer_date': now,
      'created_at': now,
      'updated_at': now,
      'is_deleted': 0,
      'is_synced': 0,
      'sync_id': 'sale-tx-layer',
    });
    saleId = await db.insert('sales', {
      'sync_id': 'sale-tx-sale',
      'sale_number': 'TX-SALE',
      'client_id': null,
      'tank_id': null,
      'driver_id': null,
      'supplier_id': supplierId,
      'units': 3,
      'sale_price': 150.0,
      'total_amount': 450.0,
      'cost_amount': 300.0,
      'profit_amount': 150.0,
      'sale_date': now,
      'payment_status': 'paid',
      'client_payment_status': 'paid',
      'supplier_payment_status': 'paid',
      'created_by_name': 'Sale Tx Admin',
      'notes': null,
      'created_by': userId,
      'created_at': now,
      'updated_at': now,
      'is_deleted': 0,
      'is_synced': 0,
    });
    await db.insert('sale_inventory_allocations', {
      'sale_id': saleId,
      'inventory_layer_id': layerId,
      'purchase_item_id': itemId,
      'supplier_id': supplierId,
      'units': 3,
      'unit_cost': 100.0,
      'cost_amount': 300.0,
      'created_at': now,
      'updated_at': now,
      'is_deleted': 0,
      'is_synced': 0,
      'sync_id': 'sale-tx-allocation',
    });

    service = SaleService();
  });

  tearDownAll(() async {
    PermissionService.setCurrentUser(null);
    await helper.closeDatabase();
  });

  testWidgets('failed sale update rolls back inventory and old allocation changes', (tester) async {
    final row = await db.query('sales', where: 'id = ?', whereArgs: [saleId], limit: 1);
    final original = Sale.fromMap(row.single);
    final changed = Sale(
      id: original.id,
      syncId: original.syncId,
      saleNumber: original.saleNumber,
      clientId: original.clientId,
      tankId: original.tankId,
      driverId: original.driverId,
      supplierId: supplierId,
      units: 8,
      salePrice: 150.0,
      totalAmount: 1200.0,
      costAmount: original.costAmount,
      profitAmount: original.profitAmount,
      saleDate: original.saleDate,
      paymentStatus: original.paymentStatus,
      clientPaymentStatus: original.clientPaymentStatus,
      supplierPaymentStatus: original.supplierPaymentStatus,
      createdByName: original.createdByName,
      notes: original.notes,
      createdBy: userId,
      createdAt: original.createdAt,
      updatedAt: original.updatedAt,
      isDeleted: false,
      isSynced: false,
    );

    await expectLater(service.updateSale(changed), throwsA(isA<Exception>()));

    final saleAfter = await db.query('sales', where: 'id = ?', whereArgs: [saleId], limit: 1);
    expect(saleAfter.single['units'], 3);
    expect(saleAfter.single['is_deleted'], 0);

    final allocationAfter = await db.query('sale_inventory_allocations', where: 'sale_id = ? AND is_deleted = 0', whereArgs: [saleId]);
    expect(allocationAfter.length, 1);
    expect(allocationAfter.single['units'], 3);

    final layerAfter = await db.query('inventory_layers', columns: ['remaining_units'], where: 'id = ?', whereArgs: [layerId], limit: 1);
    expect(layerAfter.single['remaining_units'], 7);
  });
}
