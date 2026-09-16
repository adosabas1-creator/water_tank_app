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
  late SaleService saleService;

  setUpAll(() async {
    helper = DatabaseHelper();
    db = await helper.database;
    await FinancialMigration.migrate(db);
    saleService = SaleService();
  });

  tearDownAll(() async {
    PermissionService.setCurrentUser(null);
    await helper.closeDatabase();
  });

  User userFor(String role) {
    final now = DateTime.now().toIso8601String();
    final permissions = switch (role) {
      'admin' => DefaultPermissions.admin(),
      'deputy_manager' => DefaultPermissions.deputyManager(),
      'member' => DefaultPermissions.member(),
      'driver' => DefaultPermissions.driver(),
      _ => <String, bool>{},
    };
    return User(
      syncId: 'permission-test-$role',
      username: 'permission_$role',
      passwordHash: 'test',
      recoveryCodeHash: null,
      fullName: 'Permission Test $role',
      role: role,
      permissions: permissions,
      createdAt: now,
      updatedAt: now,
    );
  }

  Sale probeSale() {
    final now = DateTime.now();
    return Sale(
      id: 999999,
      syncId: 'permission-probe',
      saleNumber: 'PERMISSION-PROBE',
      clientId: null,
      tankId: null,
      driverId: null,
      supplierId: 1,
      units: 1,
      salePrice: 100,
      totalAmount: 100,
      costAmount: 0,
      profitAmount: 100,
      saleDate: now,
      paymentStatus: 'paid',
      clientPaymentStatus: 'paid',
      supplierPaymentStatus: 'paid',
      createdByName: 'Test',
      notes: null,
      createdBy: 1,
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
      isSynced: false,
    );
  }

  Future<void> expectPermissionDenied(Future<void> Function() action) async {
    await expectLater(
      action(),
      throwsA(
        predicate((error) =>
            error is StateError &&
            error.message == 'ليس لديك صلاحية تنفيذ هذه العملية.'),
      ),
    );
  }

  Future<void> expectPastPermissionGate(Future<void> Function() action) async {
    await expectLater(
      action(),
      throwsA(
        predicate((error) =>
            error is StateError &&
            error.message != 'ليس لديك صلاحية تنفيذ هذه العملية.'),
      ),
    );
  }

  for (final role in ['admin', 'deputy_manager', 'member', 'driver']) {
    testWidgets('$role sales edit permission gate', (tester) async {
      PermissionService.setCurrentUser(userFor(role));
      final action = saleService.updateSale(probeSale());
      if (role == 'member' || role == 'driver') {
        await expectPermissionDenied(action);
      } else {
        await expectPastPermissionGate(action);
      }
    });

    testWidgets('$role sales delete permission gate', (tester) async {
      PermissionService.setCurrentUser(userFor(role));
      final action = saleService.deleteSale(999999);
      if (role == 'member' || role == 'driver') {
        await expectPermissionDenied(action);
      } else {
        await expectPastPermissionGate(action);
      }
    });
  }

  testWidgets('permission gate runs before database mutation', (tester) async {
    PermissionService.setCurrentUser(userFor('driver'));
    final before = await db.rawQuery('SELECT COUNT(*) AS c FROM sales');
    await expectPermissionDenied(() => saleService.deleteSale(999999));
    final after = await db.rawQuery('SELECT COUNT(*) AS c FROM sales');
    expect((after.single['c'] as num).toInt(), (before.single['c'] as num).toInt());
  });
}
