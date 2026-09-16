import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'package:water_tank_app/core/auth/permission_service.dart';
import 'package:water_tank_app/core/constants/permissions.dart';
import 'package:water_tank_app/core/database/database_helper.dart';
import 'package:water_tank_app/core/database/financial_migration.dart';
import 'package:water_tank_app/models/account_transaction.dart';
import 'package:water_tank_app/models/payment.dart';
import 'package:water_tank_app/models/purchase_invoice.dart';
import 'package:water_tank_app/models/purchase_item.dart';
import 'package:water_tank_app/models/user.dart';
import 'package:water_tank_app/services/account_transaction_service.dart';
import 'package:water_tank_app/services/payment_service.dart';
import 'package:water_tank_app/services/purchase_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late DatabaseHelper helper;
  late Database db;
  late PurchaseService purchaseService;
  late PaymentService paymentService;
  late AccountTransactionService accountService;
  late int userId;
  late int supplierId;
  late int clientId;

  void setRole(String role) {
    final permissions = switch (role) {
      'admin' => DefaultPermissions.admin(),
      'deputy_manager' => DefaultPermissions.deputyManager(),
      'member' => DefaultPermissions.member(),
      'driver' => DefaultPermissions.driver(),
      _ => <String, bool>{},
    };
    PermissionService.setCurrentUser(User(
      id: userId,
      syncId: 'financial-role-$role',
      username: role,
      passwordHash: 'test',
      recoveryCodeHash: null,
      fullName: role,
      role: role,
      permissions: permissions,
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    ));
  }

  setUpAll(() async {
    helper = DatabaseHelper();
    await helper.closeDatabase();
    final dbPath = await getDatabasesPath();
    await deleteDatabase(p.join(dbPath, 'alborai_water_db.db'));
    db = await helper.database;
    await FinancialMigration.migrate(db);
    final now = DateTime.now().toIso8601String();
    userId = await db.insert('users', {
      'sync_id': 'financial-test-admin', 'username': 'financial_test_admin',
      'password_hash': 'test', 'recovery_code_hash': null,
      'full_name': 'Financial Test Admin', 'role': 'admin', 'driver_id': null,
      'permissions': '{}', 'created_at': now, 'updated_at': now,
      'must_change_password': 0, 'is_deleted': 0, 'is_synced': 0,
    });
    supplierId = await db.insert('suppliers', {
      'sync_id': 'financial-test-supplier', 'supplier_number': 'FIN-SUP-001',
      'name': 'Financial Test Supplier', 'phone': null, 'location': null,
      'status': 'active', 'notes': null, 'created_at': now, 'updated_at': now,
      'is_deleted': 0, 'is_synced': 0,
    });
    clientId = await db.insert('clients', {
      'sync_id': 'financial-test-client', 'client_number': 'FIN-CLI-001',
      'name': 'Financial Test Client', 'phone': null, 'address': null,
      'notes': null, 'created_at': now, 'updated_at': now,
      'is_deleted': 0, 'is_synced': 0,
    });
    purchaseService = PurchaseService();
    paymentService = PaymentService();
    accountService = AccountTransactionService();
  });

  tearDown(() async {
    PermissionService.setCurrentUser(null);
    await db.delete('payments');
    await db.delete('account_transactions');
    await db.delete('inventory_layers');
    await db.delete('purchase_items');
    await db.delete('purchase_invoices');
  });

  tearDownAll(() async {
    PermissionService.setCurrentUser(null);
    await helper.closeDatabase();
  });

  PurchaseInvoice makeInvoice(String suffix) {
    final now = DateTime.now();
    final unique = now.microsecondsSinceEpoch;
    return PurchaseInvoice(
      invoiceNumber: 'FIN-INV-$suffix-$unique', supplierId: supplierId,
      purchaseDate: now, totalAmount: 1000, paymentStatus: 'unpaid',
      createdBy: userId, createdAt: now, updatedAt: now,
      syncId: 'fin-invoice-$suffix-$unique',
    );
  }

  PurchaseItem makeItem(String suffix) {
    final now = DateTime.now();
    final unique = now.microsecondsSinceEpoch;
    return PurchaseItem(
      purchaseInvoiceId: 0, itemType: 'tank', units: 10,
      purchasePrice: 100, totalAmount: 1000, createdAt: now, updatedAt: now,
      syncId: 'fin-item-$suffix-$unique',
    );
  }

  Payment makePayment({required String key, required int invoiceId, required double amount}) {
    final now = DateTime.now().toIso8601String();
    return Payment(
      syncId: key, paymentKey: key, paymentType: 'supplier_payment',
      referenceId: supplierId, purchaseInvoiceId: invoiceId, amount: amount,
      paymentDate: now, createdBy: userId, createdAt: now, updatedAt: now,
      isDeleted: false, isSynced: false,
    );
  }

  testWidgets('Admin and Deputy Manager can mutate purchases, payments and manual transactions', (tester) async {
    for (final role in ['admin', 'deputy_manager']) {
      setRole(role);
      final purchaseId = await purchaseService.addPurchase(
        invoice: makeInvoice(role), item: makeItem(role),
      );
      expect(purchaseId, greaterThan(0));
      final paymentId = await paymentService.addPayment(
        makePayment(key: 'payment-$role', invoiceId: purchaseId, amount: 100),
      );
      expect(paymentId, greaterThan(0));
      final transactionId = await accountService.addTransaction(AccountTransaction(
        accountType: 'client', referenceId: clientId, amount: 50,
        transactionType: 'debt', transactionDate: DateTime.now().toIso8601String(),
        notes: 'permission test', createdBy: userId,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(), isDeleted: false,
        isSynced: false, syncId: 'transaction-$role',
      ));
      expect(transactionId, greaterThan(0));
      await accountService.deleteTransaction(transactionId);
      await paymentService.deletePayment(paymentId);
      await purchaseService.deletePurchase(purchaseId);
    }
  });

  testWidgets('Member and Driver cannot mutate purchases, payments or transactions', (tester) async {
    for (final role in ['member', 'driver']) {
      setRole(role);
      expect(
        purchaseService.addPurchase(invoice: makeInvoice('denied-$role'), item: makeItem('denied-$role')),
        throwsA(isA<StateError>()),
      );
      expect(
        paymentService.addPayment(makePayment(key: 'denied-payment-$role', invoiceId: 1, amount: 10)),
        throwsA(isA<StateError>()),
      );
      expect(
        accountService.addTransaction(AccountTransaction(
          accountType: 'client', referenceId: clientId, amount: 10,
          transactionType: 'debt', transactionDate: DateTime.now().toIso8601String(),
          notes: null, createdBy: userId,
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(), isDeleted: false,
          isSynced: false, syncId: 'denied-transaction-$role',
        )),
        throwsA(isA<StateError>()),
      );
    }
  });

  testWidgets('Purchase creation is atomic when duplicate item sync_id fails', (tester) async {
    setRole('admin');
    final firstInvoice = makeInvoice('first');
    final sharedItem = makeItem('shared');
    await purchaseService.addPurchase(invoice: firstInvoice, item: sharedItem);
    final secondInvoice = makeInvoice('second');
    await expectLater(
      purchaseService.addPurchase(invoice: secondInvoice, item: sharedItem),
      throwsA(isA<StateError>()),
    );
    expect(await db.query('purchase_invoices', where: 'sync_id = ?', whereArgs: [secondInvoice.syncId]), isEmpty);
  });

  testWidgets('Payment update exceeding invoice total is atomic', (tester) async {
    setRole('admin');
    final purchaseId = await purchaseService.addPurchase(
      invoice: makeInvoice('payment-atomic'), item: makeItem('payment-atomic'),
    );
    final paymentId = await paymentService.addPayment(
      makePayment(key: 'atomic-payment', invoiceId: purchaseId, amount: 400),
    );
    final before = (await db.query('payments', where: 'id = ?', whereArgs: [paymentId])).single;
    final bad = makePayment(key: 'atomic-payment-updated', invoiceId: purchaseId, amount: 700);
    final badUpdate = Payment(
      id: paymentId, syncId: bad.syncId, paymentKey: bad.paymentKey,
      paymentType: bad.paymentType, referenceId: bad.referenceId,
      purchaseInvoiceId: bad.purchaseInvoiceId, amount: bad.amount,
      paymentDate: before['payment_date'] as String, createdBy: userId,
      createdAt: before['created_at'] as String,
      updatedAt: DateTime.now().toIso8601String(), isDeleted: false, isSynced: false,
    );
    await expectLater(paymentService.updatePayment(badUpdate), throwsA(isA<StateError>()));
    final after = (await db.query('payments', where: 'id = ?', whereArgs: [paymentId])).single;
    expect((after['amount'] as num).toDouble(), 400);
    expect(after['payment_key'], 'atomic-payment');
    final invoice = (await db.query('purchase_invoices', where: 'id = ?', whereArgs: [purchaseId])).single;
    expect(invoice['payment_status'], 'partial');
  });
}
