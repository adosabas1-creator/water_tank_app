import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'package:water_tank_app/core/auth/permission_service.dart';
import 'package:water_tank_app/core/database/database_helper.dart';
import 'package:water_tank_app/core/database/financial_migration.dart';
import 'package:water_tank_app/core/constants/permissions.dart';
import 'package:water_tank_app/models/purchase_invoice.dart';
import 'package:water_tank_app/models/purchase_item.dart';
import 'package:water_tank_app/models/user.dart';
import 'package:water_tank_app/services/account_transaction_service.dart';
import 'package:water_tank_app/services/purchase_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseHelper helper;
  late Database db;
  late PurchaseService purchaseService;
  late AccountTransactionService accountService;
  late int userId;
  late int supplierId;

  setUpAll(() async {
    helper = DatabaseHelper();
    await helper.closeDatabase();

    final dbPath = await getDatabasesPath();
    await deleteDatabase(p.join(dbPath, 'alborai_water_db.db'));

    db = await helper.database;
    await FinancialMigration.migrate(db);

    final now = DateTime.now().toIso8601String();
    final user = User(
      syncId: 'test_admin_user',
      username: 'test_admin',
      passwordHash: 'test',
      recoveryCodeHash: null,
      fullName: 'Test Admin',
      role: 'admin',
      permissions: DefaultPermissions.admin(),
      createdAt: now,
      updatedAt: now,
    );
    userId = await db.insert('users', user.toMap()..remove('id'));
    PermissionService.setCurrentUser(
      User(
        id: userId,
        syncId: user.syncId,
        username: user.username,
        passwordHash: user.passwordHash,
        recoveryCodeHash: user.recoveryCodeHash,
        fullName: user.fullName,
        role: user.role,
        driverId: user.driverId,
        permissions: user.permissions,
        createdAt: user.createdAt,
        updatedAt: user.updatedAt,
        mustChangePassword: user.mustChangePassword,
      ),
    );

    supplierId = await db.insert('suppliers', {
      'sync_id': 'test_supplier',
      'supplier_number': 'TEST-001',
      'name': 'Test Supplier',
      'phone': null,
      'location': null,
      'status': 'active',
      'notes': null,
      'created_at': now,
      'updated_at': now,
      'is_deleted': 0,
      'is_synced': 0,
    });

    purchaseService = PurchaseService();
    accountService = AccountTransactionService();
  });

  tearDown(() async {
    await db.delete('sale_inventory_allocations');
    await db.delete('sales');
    await db.delete('inventory_layers');
    await db.delete('purchase_items');
    await db.delete('payments');
    await db.delete('account_transactions');
    await db.delete('purchase_invoices');
  });

  tearDownAll(() async {
    PermissionService.setCurrentUser(null);
    await helper.closeDatabase();
  });

  Future<int> createPurchase({String suffix = '', double paidAmount = 40}) async {
    final now = DateTime.now();
    final unique = now.microsecondsSinceEpoch;
    final invoice = PurchaseInvoice(
      invoiceNumber: 'TEST-INV-$suffix-$unique',
      supplierId: supplierId,
      purchaseDate: now,
      totalAmount: 1000,
      paymentStatus: 'partial',
      createdBy: userId,
      createdAt: now,
      updatedAt: now,
      syncId: 'test-invoice-$suffix-$unique',
    );
    final item = PurchaseItem(
      purchaseInvoiceId: 0,
      itemType: 'tank',
      units: 10,
      purchasePrice: 100,
      totalAmount: 1000,
      createdAt: now,
      updatedAt: now,
      syncId: 'test-item-$suffix-$unique',
    );
    return purchaseService.addPurchase(
      invoice: invoice,
      item: item,
      paidAmount: paidAmount,
    );
  }

  Future<Map<String, int>> purchaseChildren(int invoiceId) async {
    final item = await db.query(
      'purchase_items',
      columns: ['id'],
      where: 'purchase_invoice_id = ?',
      whereArgs: [invoiceId],
      limit: 1,
    );
    final itemId = (item.single['id'] as num).toInt();
    final layer = await db.query(
      'inventory_layers',
      columns: ['id'],
      where: 'purchase_item_id = ?',
      whereArgs: [itemId],
      limit: 1,
    );
    final layerId = (layer.single['id'] as num).toInt();
    final debt = await db.query(
      'account_transactions',
      columns: ['id'],
      where: 'purchase_invoice_id = ?',
      whereArgs: [invoiceId],
      limit: 1,
    );
    final payment = await db.query(
      'payments',
      columns: ['id'],
      where: 'purchase_invoice_id = ?',
      whereArgs: [invoiceId],
      limit: 1,
    );
    return {
      'item': itemId,
      'layer': layerId,
      'debt': (debt.single['id'] as num).toInt(),
      'payment': (payment.single['id'] as num).toInt(),
    };
  }

  Future<int> createSale({
    required int supplier,
    required int units,
    required int purchaseItemId,
    required int inventoryLayerId,
    bool deleted = false,
    bool allocationDeleted = false,
  }) async {
    final now = DateTime.now().toIso8601String();
    final unique = DateTime.now().microsecondsSinceEpoch;
    final saleId = await db.insert('sales', {
      'sync_id': 'test-sale-$unique',
      'sale_number': 'TEST-SALE-$unique',
      'client_id': null,
      'tank_id': null,
      'driver_id': null,
      'supplier_id': supplier,
      'units': units,
      'sale_price': 150,
      'total_amount': units * 150.0,
      'cost_amount': units * 100.0,
      'profit_amount': units * 50.0,
      'sale_date': now,
      'payment_status': 'paid',
      'client_payment_status': 'paid',
      'supplier_payment_status': 'paid',
      'created_by_name': 'Test Admin',
      'notes': null,
      'created_by': userId,
      'created_at': now,
      'updated_at': now,
      'is_deleted': deleted ? 1 : 0,
      'is_synced': 0,
    });

    await db.insert('sale_inventory_allocations', {
      'sale_id': saleId,
      'inventory_layer_id': inventoryLayerId,
      'purchase_item_id': purchaseItemId,
      'supplier_id': supplier,
      'units': units,
      'unit_cost': 100,
      'cost_amount': units * 100.0,
      'created_at': now,
      'updated_at': now,
      'is_deleted': allocationDeleted ? 1 : 0,
      'is_synced': 0,
      'sync_id': 'test-allocation-$unique',
    });
    return saleId;
  }

  testWidgets(
    'active sale allocation blocks PurchaseService.deletePurchase and transaction rolls back',
    (tester) async {
      final invoiceId = await createPurchase(suffix: 'active');
      final ids = await purchaseChildren(invoiceId);

      await createSale(
        supplier: supplierId,
        units: 3,
        purchaseItemId: ids['item']!,
        inventoryLayerId: ids['layer']!,
      );

      await expectLater(
        purchaseService.deletePurchase(invoiceId),
        throwsA(isA<StateError>()),
      );

      final invoice = await db.query(
        'purchase_invoices',
        where: 'id = ?',
        whereArgs: [invoiceId],
      );
      expect(invoice.single['is_deleted'], 0);

      final debt = await db.query(
        'account_transactions',
        where: 'id = ?',
        whereArgs: [ids['debt']],
      );
      expect(debt.single['is_deleted'], 0);

      final payment = await db.query(
        'payments',
        where: 'id = ?',
        whereArgs: [ids['payment']],
      );
      expect(payment.single['is_deleted'], 0);
    },
  );

  testWidgets(
    'historical allocation only allows deletion and soft-deletes invoice children, debt and payment',
    (tester) async {
      final invoiceId = await createPurchase(suffix: 'historical');
      final ids = await purchaseChildren(invoiceId);

      await createSale(
        supplier: supplierId,
        units: 3,
        purchaseItemId: ids['item']!,
        inventoryLayerId: ids['layer']!,
        allocationDeleted: true,
      );

      await purchaseService.deletePurchase(invoiceId);

      final invoice = await db.query(
        'purchase_invoices',
        where: 'id = ?',
        whereArgs: [invoiceId],
      );
      expect(invoice.single['is_deleted'], 1);
      expect(invoice.single['is_synced'], 0);

      for (final table in ['purchase_items', 'inventory_layers', 'account_transactions', 'payments']) {
        final id = ids[table == 'purchase_items'
            ? 'item'
            : table == 'inventory_layers'
                ? 'layer'
                : table == 'account_transactions'
                    ? 'debt'
                    : 'payment']!;
        final rows = await db.query(table, where: 'id = ?', whereArgs: [id]);
        expect(rows.single['is_deleted'], 1, reason: '$table must be soft-deleted');
        expect(rows.single['is_synced'], 0, reason: '$table must be marked for sync');
      }

      expect(
        await accountService.getBalance(
          accountType: 'supplier',
          referenceId: supplierId,
        ),
        0,
      );
    },
  );

  testWidgets(
    'deleted sale with an active historical allocation does not block purchase deletion',
    (tester) async {
      final invoiceId = await createPurchase(suffix: 'deleted-sale');
      final ids = await purchaseChildren(invoiceId);

      await createSale(
        supplier: supplierId,
        units: 2,
        purchaseItemId: ids['item']!,
        inventoryLayerId: ids['layer']!,
        deleted: true,
      );

      await purchaseService.deletePurchase(invoiceId);

      final invoice = await db.query(
        'purchase_invoices',
        where: 'id = ?',
        whereArgs: [invoiceId],
      );
      expect(invoice.single['is_deleted'], 1);
    },
  );
}
