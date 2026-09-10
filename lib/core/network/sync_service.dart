import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../database/database_helper.dart';
import 'connectivity_service.dart';

class SyncService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ConnectivityService _connectivity = ConnectivityService();

  static const String businessId = 'alborai_water_tank';

  Future<void> syncClients() async {
    if (!await _connectivity.isOnline()) return;
    if (_auth.currentUser == null) return;

    final db = await _dbHelper.database;

    final rows = await db.query(
      'clients',
      where: 'is_synced = ?',
      whereArgs: [0],
    );

    for (final row in rows) {
      try {
        final syncId = row['sync_id']?.toString();
        if (syncId == null || syncId.isEmpty) continue;

        final data = Map<String, dynamic>.from(row);
        data.remove('id');
        data.remove('is_synced');

        final createdBy = row['created_by'];
        data.remove('created_by');
        if (createdBy != null) {
          final userRows = await db.query(
            'users',
            columns: ['sync_id'],
            where: 'id = ?',
            whereArgs: [createdBy],
            limit: 1,
          );
          if (userRows.isNotEmpty) {
            data['created_by_sync_id'] = userRows.first['sync_id'];
          }
        }

        await _firestore
            .collection('businesses')
            .doc(businessId)
            .collection('clients')
            .doc(syncId)
            .set(data, SetOptions(merge: true));

        await db.update(
          'clients',
          {'is_synced': 1},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      } catch (e) {
        debugPrint('Client sync error: $e');
      }
    }
  }

  Future<void> syncSuppliers() async {
    if (!await _connectivity.isOnline()) return;
    if (_auth.currentUser == null) return;

    final db = await _dbHelper.database;
    final rows = await db.query(
      'suppliers',
      where: 'is_synced = ?',
      whereArgs: [0],
    );

    for (final row in rows) {
      try {
        final syncId = row['sync_id']?.toString();
        if (syncId == null || syncId.isEmpty) continue;

        final data = Map<String, dynamic>.from(row);
        data.remove('id');
        data.remove('is_synced');

        await _firestore
            .collection('businesses')
            .doc(businessId)
            .collection('suppliers')
            .doc(syncId)
            .set(data, SetOptions(merge: true));

        await db.update(
          'suppliers',
          {'is_synced': 1},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      } catch (e) {
        debugPrint('Supplier sync error: $e');
      }
    }
  }

  Future<void> syncDrivers() async {
    if (!await _connectivity.isOnline()) return;
    if (_auth.currentUser == null) return;

    final db = await _dbHelper.database;
    final rows = await db.query(
      'drivers',
      where: 'is_synced = ?',
      whereArgs: [0],
    );

    for (final row in rows) {
      try {
        final syncId = row['sync_id']?.toString();
        if (syncId == null || syncId.isEmpty) continue;

        final data = Map<String, dynamic>.from(row);
        data.remove('id');
        data.remove('is_synced');

        await _firestore
            .collection('businesses')
            .doc(businessId)
            .collection('drivers')
            .doc(syncId)
            .set(data, SetOptions(merge: true));

        await db.update(
          'drivers',
          {'is_synced': 1},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      } catch (e) {
        debugPrint('Driver sync error: $e');
      }
    }
  }

  Future<void> syncTanks() async {
    if (!await _connectivity.isOnline()) return;
    if (_auth.currentUser == null) return;

    final db = await _dbHelper.database;
    final rows = await db.query(
      'tanks',
      where: 'is_synced = ?',
      whereArgs: [0],
    );

    for (final row in rows) {
      try {
        final syncId = row['sync_id']?.toString();
        if (syncId == null || syncId.isEmpty) continue;

        final data = Map<String, dynamic>.from(row);
        data.remove('id');
        data.remove('is_synced');

        final driverId = row['driver_id'];
        data.remove('driver_id');

        if (driverId != null) {
          final driver = await db.query(
            'drivers',
            columns: ['sync_id'],
            where: 'id = ?',
            whereArgs: [driverId],
            limit: 1,
          );
          data['driver_sync_id'] =
              driver.isNotEmpty ? driver.first['sync_id'] : null;
        } else {
          data['driver_sync_id'] = null;
        }

        await _firestore
            .collection('businesses')
            .doc(businessId)
            .collection('tanks')
            .doc(syncId)
            .set(data, SetOptions(merge: true));

        await db.update(
          'tanks',
          {'is_synced': 1},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      } catch (e) {
        debugPrint('Tank sync error: $e');
      }
    }
  }

  Future<void> syncFillingOperations() async {
    if (!await _connectivity.isOnline()) return;
    if (_auth.currentUser == null) return;

    final db = await _dbHelper.database;
    final rows = await db.query(
      'filling_operations',
      where: 'is_synced = ?',
      whereArgs: [0],
    );

    for (final row in rows) {
      try {
        final syncId = row['sync_id']?.toString();
        if (syncId == null || syncId.isEmpty) continue;

        final data = Map<String, dynamic>.from(row);
        data.remove('id');
        data.remove('is_synced');

        Future<String?> getSyncId(
          String table,
          dynamic localId,
        ) async {
          if (localId == null) return null;
          final result = await db.query(
            table,
            columns: ['sync_id'],
            where: 'id = ?',
            whereArgs: [localId],
            limit: 1,
          );
          return result.isNotEmpty ? result.first['sync_id']?.toString() : null;
        }

        data['tank_sync_id'] = await getSyncId('tanks', row['tank_id']);
        data.remove('tank_id');

        data['supplier_sync_id'] =
            await getSyncId('suppliers', row['supplier_id']);
        data.remove('supplier_id');

        data['employee_sync_id'] = await getSyncId('users', row['employee_id']);
        data.remove('employee_id');

        data['created_by_sync_id'] =
            await getSyncId('users', row['created_by']);
        data.remove('created_by');

        await _firestore
            .collection('businesses')
            .doc(businessId)
            .collection('filling_operations')
            .doc(syncId)
            .set(data, SetOptions(merge: true));

        await db.update(
          'filling_operations',
          {'is_synced': 1},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      } catch (e) {
        debugPrint('Filling operation sync error: $e');
      }
    }
  }

  Future<void> syncSales() async {
    if (!await _connectivity.isOnline()) return;
    if (_auth.currentUser == null) return;

    final db = await _dbHelper.database;
    final rows = await db.query(
      'sales',
      where: 'is_synced = ?',
      whereArgs: [0],
    );

    for (final row in rows) {
      try {
        final syncId = row['sync_id']?.toString();
        if (syncId == null || syncId.isEmpty) continue;

        final data = Map<String, dynamic>.from(row);
        data.remove('id');
        data.remove('is_synced');

        Future<String?> getSyncId(
          String table,
          dynamic localId,
        ) async {
          if (localId == null) return null;
          final result = await db.query(
            table,
            columns: ['sync_id'],
            where: 'id = ?',
            whereArgs: [localId],
            limit: 1,
          );
          return result.isNotEmpty ? result.first['sync_id']?.toString() : null;
        }

        data['client_sync_id'] = await getSyncId('clients', row['client_id']);
        data.remove('client_id');

        data['tank_sync_id'] = await getSyncId('tanks', row['tank_id']);
        data.remove('tank_id');

        data['driver_sync_id'] = await getSyncId('drivers', row['driver_id']);
        data.remove('driver_id');

        data['supplier_sync_id'] =
            await getSyncId('suppliers', row['supplier_id']);
        data.remove('supplier_id');

        data['created_by_sync_id'] =
            await getSyncId('users', row['created_by']);
        data.remove('created_by');

        await _firestore
            .collection('businesses')
            .doc(businessId)
            .collection('sales')
            .doc(syncId)
            .set(data, SetOptions(merge: true));

        await db.update(
          'sales',
          {'is_synced': 1},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      } catch (e) {
        debugPrint('Sale sync error: $e');
      }
    }
  }

  Future<void> syncPayments() async {
    if (!await _connectivity.isOnline()) return;
    if (_auth.currentUser == null) return;

    final db = await _dbHelper.database;
    final rows = await db.query(
      'payments',
      where: 'is_synced = ?',
      whereArgs: [0],
    );

    for (final row in rows) {
      try {
        final syncId = row['sync_id']?.toString();
        if (syncId == null || syncId.isEmpty) continue;

        final data = Map<String, dynamic>.from(row);
        data.remove('id');
        data.remove('is_synced');

        Future<String?> getSyncId(
          String table,
          dynamic localId,
        ) async {
          if (localId == null) return null;
          final result = await db.query(
            table,
            columns: ['sync_id'],
            where: 'id = ?',
            whereArgs: [localId],
            limit: 1,
          );
          return result.isNotEmpty ? result.first['sync_id']?.toString() : null;
        }

        final paymentType = row['payment_type']?.toString();
        final referenceId = row['reference_id'];

        if (paymentType == 'client_payment') {
          data['reference_sync_id'] = await getSyncId('clients', referenceId);
        } else if (paymentType == 'supplier_payment') {
          data['reference_sync_id'] = await getSyncId('suppliers', referenceId);
        } else {
          data['reference_sync_id'] = null;
        }

        data.remove('reference_id');

        data['created_by_sync_id'] =
            await getSyncId('users', row['created_by']);
        data.remove('created_by');

        await _firestore
            .collection('businesses')
            .doc(businessId)
            .collection('payments')
            .doc(syncId)
            .set(data, SetOptions(merge: true));

        await db.update(
          'payments',
          {'is_synced': 1},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      } catch (e) {
        debugPrint('Payment sync error: $e');
      }
    }
  }

  Future<void> syncExpenses() async {
    if (!await _connectivity.isOnline()) return;
    if (_auth.currentUser == null) return;

    final db = await _dbHelper.database;
    final rows = await db.query(
      'expenses',
      where: 'is_synced = ?',
      whereArgs: [0],
    );

    for (final row in rows) {
      try {
        final syncId = row['sync_id']?.toString();
        if (syncId == null || syncId.isEmpty) continue;

        final data = Map<String, dynamic>.from(row);
        data.remove('id');
        data.remove('is_synced');

        final createdBy = row['created_by'];
        data.remove('created_by');

        if (createdBy != null) {
          final userRows = await db.query(
            'users',
            columns: ['sync_id'],
            where: 'id = ?',
            whereArgs: [createdBy],
            limit: 1,
          );

          if (userRows.isNotEmpty) {
            data['created_by_sync_id'] = userRows.first['sync_id'];
          }
        }

        await _firestore
            .collection('businesses')
            .doc(businessId)
            .collection('expenses')
            .doc(syncId)
            .set(data, SetOptions(merge: true));

        await db.update(
          'expenses',
          {'is_synced': 1},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      } catch (e) {
        debugPrint('Expense sync error: $e');
      }
    }
  }

  Future<void> syncSalaries() async {
    if (!await _connectivity.isOnline()) return;
    if (_auth.currentUser == null) return;

    final db = await _dbHelper.database;
    final rows = await db.query(
      'salaries',
      where: 'is_synced = ?',
      whereArgs: [0],
    );

    for (final row in rows) {
      try {
        final syncId = row['sync_id']?.toString();
        if (syncId == null || syncId.isEmpty) continue;

        final data = Map<String, dynamic>.from(row);
        data.remove('id');
        data.remove('is_synced');

        final employeeId = row['employee_id'];
        data.remove('employee_id');
        if (employeeId != null) {
          final employeeRows = await db.query(
            'users',
            columns: ['sync_id'],
            where: 'id = ?',
            whereArgs: [employeeId],
            limit: 1,
          );
          if (employeeRows.isNotEmpty) {
            data['employee_sync_id'] = employeeRows.first['sync_id'];
          }
        }

        final createdBy = row['created_by'];
        data.remove('created_by');
        if (createdBy != null) {
          final userRows = await db.query(
            'users',
            columns: ['sync_id'],
            where: 'id = ?',
            whereArgs: [createdBy],
            limit: 1,
          );
          if (userRows.isNotEmpty) {
            data['created_by_sync_id'] = userRows.first['sync_id'];
          }
        }

        await _firestore
            .collection('businesses')
            .doc(businessId)
            .collection('salaries')
            .doc(syncId)
            .set(data, SetOptions(merge: true));

        await db.update(
          'salaries',
          {'is_synced': 1},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      } catch (e) {
        debugPrint('Salary sync error: $e');
      }
    }
  }

  Future<void> downloadClients() async {
    if (!await _connectivity.isOnline()) return;
    if (_auth.currentUser == null) return;

    final db = await _dbHelper.database;

    final snapshot = await _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('clients')
        .get();

    for (final doc in snapshot.docs) {
      try {
        final data = Map<String, dynamic>.from(doc.data());
        final syncId = data['sync_id']?.toString();

        if (syncId == null || syncId.isEmpty) continue;

        final existing = await db.query(
          'clients',
          where: 'sync_id = ?',
          whereArgs: [syncId],
          limit: 1,
        );

        data.remove('id');
        data.remove('is_synced');
        data['sync_id'] = syncId;
        data['is_synced'] = 1;

        if (existing.isEmpty) {
          await db.insert('clients', data);
        } else {
          await db.update(
            'clients',
            data,
            where: 'sync_id = ?',
            whereArgs: [syncId],
          );
        }
      } catch (e) {
        debugPrint('Client download error: $e');
      }
    }
  }

  Future<void> downloadTable(String tableName) async {
    if (!await _connectivity.isOnline()) return;
    if (_auth.currentUser == null) return;

    final db = await _dbHelper.database;

    final snapshot = await _firestore
        .collection('businesses')
        .doc(businessId)
        .collection(tableName)
        .get();

    for (final doc in snapshot.docs) {
      try {
        final data = Map<String, dynamic>.from(doc.data());
        final syncId = data['sync_id']?.toString();

        if (syncId == null || syncId.isEmpty) continue;

        final existing = await db.query(
          tableName,
          where: 'sync_id = ?',
          whereArgs: [syncId],
          limit: 1,
        );

        data.remove('id');
        data.remove('is_synced');
        data['sync_id'] = syncId;
        data['is_synced'] = 1;

        if (existing.isEmpty) {
          await db.insert(tableName, data);
        } else {
          await db.update(
            tableName,
            data,
            where: 'sync_id = ?',
            whereArgs: [syncId],
          );
        }
      } catch (e) {
        debugPrint('$tableName download error: $e');
      }
    }
  }

  Future<void> downloadTanks() async {
    if (!await _connectivity.isOnline()) return;
    if (_auth.currentUser == null) return;

    final db = await _dbHelper.database;
    final snapshot = await _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('tanks')
        .get();

    for (final doc in snapshot.docs) {
      try {
        final data = Map<String, dynamic>.from(doc.data());
        final syncId = data['sync_id']?.toString();

        if (syncId == null || syncId.isEmpty) continue;

        final driverSyncId = data['driver_sync_id']?.toString();
        data.remove('driver_sync_id');

        if (driverSyncId != null && driverSyncId.isNotEmpty) {
          final driverRows = await db.query(
            'drivers',
            columns: ['id'],
            where: 'sync_id = ?',
            whereArgs: [driverSyncId],
            limit: 1,
          );

          if (driverRows.isEmpty) {
            debugPrint(
              'Tank download skipped: driver not found for $syncId',
            );
            continue;
          }

          data['driver_id'] = driverRows.first['id'];
        } else {
          data['driver_id'] = null;
        }

        final existing = await db.query(
          'tanks',
          where: 'sync_id = ?',
          whereArgs: [syncId],
          limit: 1,
        );

        data.remove('id');
        data.remove('is_synced');
        data['sync_id'] = syncId;
        data['is_synced'] = 1;

        if (existing.isEmpty) {
          await db.insert('tanks', data);
        } else {
          await db.update(
            'tanks',
            data,
            where: 'sync_id = ?',
            whereArgs: [syncId],
          );
        }
      } catch (e) {
        debugPrint('Tank download error: $e');
      }
    }
  }

  Future<void> downloadFillingOperations() async {
    if (!await _connectivity.isOnline()) return;
    if (_auth.currentUser == null) return;

    final db = await _dbHelper.database;
    final snapshot = await _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('filling_operations')
        .get();

    Future<int?> getLocalId(String table, dynamic syncId) async {
      if (syncId == null || syncId.toString().isEmpty) return null;

      final result = await db.query(
        table,
        columns: ['id'],
        where: 'sync_id = ?',
        whereArgs: [syncId.toString()],
        limit: 1,
      );

      return result.isNotEmpty ? result.first['id'] as int? : null;
    }

    for (final doc in snapshot.docs) {
      try {
        final data = Map<String, dynamic>.from(doc.data());
        final syncId = data['sync_id']?.toString();

        if (syncId == null || syncId.isEmpty) continue;

        final tankSyncId = data['tank_sync_id'];
        final supplierSyncId = data['supplier_sync_id'];
        final employeeSyncId = data['employee_sync_id'];
        final createdBySyncId = data['created_by_sync_id'];

        data.remove('tank_sync_id');
        data.remove('supplier_sync_id');
        data.remove('employee_sync_id');
        data.remove('created_by_sync_id');

        final tankId = await getLocalId('tanks', tankSyncId);
        final supplierId = await getLocalId('suppliers', supplierSyncId);
        final employeeId = await getLocalId('users', employeeSyncId);
        final createdById = await getLocalId('users', createdBySyncId);

        if (tankSyncId != null && tankId == null) continue;
        if (supplierSyncId != null && supplierId == null) continue;
        if (employeeSyncId != null && employeeId == null) continue;
        if (createdBySyncId != null && createdById == null) continue;

        data['tank_id'] = tankId;
        data['supplier_id'] = supplierId;
        data['employee_id'] = employeeId;
        data['created_by'] = createdById;

        final existing = await db.query(
          'filling_operations',
          where: 'sync_id = ?',
          whereArgs: [syncId],
          limit: 1,
        );

        data.remove('id');
        data.remove('is_synced');
        data['sync_id'] = syncId;
        data['is_synced'] = 1;

        if (existing.isEmpty) {
          await db.insert('filling_operations', data);
        } else {
          await db.update(
            'filling_operations',
            data,
            where: 'sync_id = ?',
            whereArgs: [syncId],
          );
        }
      } catch (e) {
        debugPrint('Filling operation download error: $e');
      }
    }
  }

  Future<void> downloadSales() async {
    if (!await _connectivity.isOnline()) return;
    if (_auth.currentUser == null) return;

    final db = await _dbHelper.database;
    final snapshot = await _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('sales')
        .get();

    Future<int?> getLocalId(String table, dynamic syncId) async {
      if (syncId == null || syncId.toString().isEmpty) return null;

      final result = await db.query(
        table,
        columns: ['id'],
        where: 'sync_id = ?',
        whereArgs: [syncId.toString()],
        limit: 1,
      );

      return result.isNotEmpty ? result.first['id'] as int? : null;
    }

    for (final doc in snapshot.docs) {
      try {
        final data = Map<String, dynamic>.from(doc.data());
        final syncId = data['sync_id']?.toString();

        if (syncId == null || syncId.isEmpty) continue;

        final clientSyncId = data['client_sync_id'];
        final tankSyncId = data['tank_sync_id'];
        final driverSyncId = data['driver_sync_id'];
        final supplierSyncId = data['supplier_sync_id'];
        final createdBySyncId = data['created_by_sync_id'];

        data.remove('client_sync_id');
        data.remove('tank_sync_id');
        data.remove('driver_sync_id');
        data.remove('supplier_sync_id');
        data.remove('created_by_sync_id');

        final clientId = await getLocalId('clients', clientSyncId);
        final tankId = await getLocalId('tanks', tankSyncId);
        final driverId = await getLocalId('drivers', driverSyncId);
        final supplierId = await getLocalId('suppliers', supplierSyncId);
        final createdById = await getLocalId('users', createdBySyncId);

        if (clientSyncId != null && clientId == null) continue;
        if (tankSyncId != null && tankId == null) continue;
        if (driverSyncId != null && driverId == null) continue;
        if (supplierSyncId != null && supplierId == null) continue;
        if (createdBySyncId != null && createdById == null) continue;

        data['client_id'] = clientId;
        data['tank_id'] = tankId;
        data['driver_id'] = driverId;
        data['supplier_id'] = supplierId;
        data['created_by'] = createdById;

        final existing = await db.query(
          'sales',
          where: 'sync_id = ?',
          whereArgs: [syncId],
          limit: 1,
        );

        data.remove('id');
        data.remove('is_synced');
        data['sync_id'] = syncId;
        data['is_synced'] = 1;

        if (existing.isEmpty) {
          await db.insert('sales', data);
        } else {
          await db.update(
            'sales',
            data,
            where: 'sync_id = ?',
            whereArgs: [syncId],
          );
        }
      } catch (e) {
        debugPrint('Sale download error: $e');
      }
    }
  }

  Future<void> downloadPayments() async {
    if (!await _connectivity.isOnline()) return;
    if (_auth.currentUser == null) return;

    final db = await _dbHelper.database;
    final snapshot = await _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('payments')
        .get();

    Future<int?> getLocalId(String table, dynamic syncId) async {
      if (syncId == null || syncId.toString().isEmpty) return null;

      final result = await db.query(
        table,
        columns: ['id'],
        where: 'sync_id = ?',
        whereArgs: [syncId.toString()],
        limit: 1,
      );

      return result.isNotEmpty ? result.first['id'] as int? : null;
    }

    for (final doc in snapshot.docs) {
      try {
        final data = Map<String, dynamic>.from(doc.data());
        final syncId = data['sync_id']?.toString();

        if (syncId == null || syncId.isEmpty) continue;

        final paymentType = data['payment_type']?.toString();
        final referenceSyncId = data['reference_sync_id'];
        final createdBySyncId = data['created_by_sync_id'];

        data.remove('reference_sync_id');
        data.remove('created_by_sync_id');

        int? referenceId;

        if (paymentType == 'client_payment') {
          referenceId = await getLocalId('clients', referenceSyncId);
        } else if (paymentType == 'supplier_payment') {
          referenceId = await getLocalId('suppliers', referenceSyncId);
        }

        final createdById = await getLocalId('users', createdBySyncId);

        if (referenceSyncId != null && referenceId == null) continue;
        if (createdBySyncId != null && createdById == null) continue;

        data['reference_id'] = referenceId;
        data['created_by'] = createdById;

        final existing = await db.query(
          'payments',
          where: 'sync_id = ?',
          whereArgs: [syncId],
          limit: 1,
        );

        data.remove('id');
        data.remove('is_synced');
        data['sync_id'] = syncId;
        data['is_synced'] = 1;

        if (existing.isEmpty) {
          await db.insert('payments', data);
        } else {
          await db.update(
            'payments',
            data,
            where: 'sync_id = ?',
            whereArgs: [syncId],
          );
        }
      } catch (e) {
        debugPrint('Payment download error: $e');
      }
    }
  }

  Future<void> downloadSalaries() async {
    if (!await _connectivity.isOnline()) return;
    if (_auth.currentUser == null) return;

    final db = await _dbHelper.database;
    final snapshot = await _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('salaries')
        .get();

    Future<int?> getLocalId(String table, dynamic syncId) async {
      if (syncId == null || syncId.toString().isEmpty) return null;

      final result = await db.query(
        table,
        columns: ['id'],
        where: 'sync_id = ?',
        whereArgs: [syncId.toString()],
        limit: 1,
      );

      return result.isNotEmpty ? result.first['id'] as int? : null;
    }

    for (final doc in snapshot.docs) {
      try {
        final data = Map<String, dynamic>.from(doc.data());
        final syncId = data['sync_id']?.toString();

        if (syncId == null || syncId.isEmpty) continue;

        final employeeSyncId = data['employee_sync_id'];
        final createdBySyncId = data['created_by_sync_id'];

        data.remove('employee_sync_id');
        data.remove('created_by_sync_id');

        final employeeId = await getLocalId('users', employeeSyncId);
        final createdById = await getLocalId('users', createdBySyncId);

        if (employeeSyncId != null && employeeId == null) continue;
        if (createdBySyncId != null && createdById == null) continue;

        data['employee_id'] = employeeId;
        data['created_by'] = createdById;

        final existing = await db.query(
          'salaries',
          where: 'sync_id = ?',
          whereArgs: [syncId],
          limit: 1,
        );

        data.remove('id');
        data.remove('is_synced');
        data['sync_id'] = syncId;
        data['is_synced'] = 1;

        if (existing.isEmpty) {
          await db.insert('salaries', data);
        } else {
          await db.update(
            'salaries',
            data,
            where: 'sync_id = ?',
            whereArgs: [syncId],
          );
        }
      } catch (e) {
        debugPrint('Salary download error: $e');
      }
    }
  }

  Future<void> downloadExpenses() async {
    if (!await _connectivity.isOnline()) return;
    if (_auth.currentUser == null) return;

    final db = await _dbHelper.database;
    final snapshot = await _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('expenses')
        .get();

    Future<int?> getLocalId(dynamic syncId) async {
      if (syncId == null || syncId.toString().isEmpty) return null;

      final result = await db.query(
        'users',
        columns: ['id'],
        where: 'sync_id = ?',
        whereArgs: [syncId.toString()],
        limit: 1,
      );

      return result.isNotEmpty ? result.first['id'] as int? : null;
    }

    for (final doc in snapshot.docs) {
      try {
        final data = Map<String, dynamic>.from(doc.data());
        final syncId = data['sync_id']?.toString();

        if (syncId == null || syncId.isEmpty) continue;

        final createdBySyncId = data['created_by_sync_id'];

        data.remove('created_by_sync_id');

        final createdById = await getLocalId(createdBySyncId);

        if (createdBySyncId != null && createdById == null) continue;

        data['created_by'] = createdById;
        data.remove('id');
        data.remove('is_synced');
        data['sync_id'] = syncId;
        data['is_synced'] = 1;

        final existing = await db.query(
          'expenses',
          where: 'sync_id = ?',
          whereArgs: [syncId],
          limit: 1,
        );

        if (existing.isEmpty) {
          await db.insert('expenses', data);
        } else {
          await db.update(
            'expenses',
            data,
            where: 'sync_id = ?',
            whereArgs: [syncId],
          );
        }
      } catch (e) {
        debugPrint('Expense download error: $e');
      }
    }
  }

  Future<void> syncAll() async {
    await syncClients();
    await syncSuppliers();
    await syncDrivers();
    await syncTanks();
    await syncFillingOperations();
    await syncSales();
    await syncPayments();
    await syncExpenses();
    await syncSalaries();
    await downloadClients();
    await downloadTable('suppliers');
    await downloadTable('drivers');
    await downloadTanks();
    await downloadFillingOperations();
    await downloadSales();
    await downloadPayments();
    await downloadExpenses();
    await downloadSalaries();
  }
}
