import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import 'connectivity_service.dart';
import '../auth/permission_service.dart';
import '../constants/permissions.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();

  factory SyncService() => _instance;

  SyncService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ConnectivityService _connectivity = ConnectivityService();

  StreamSubscription<bool>? _connectivitySubscription;
  bool _autoSyncStarted = false;

  static const String businessId = 'alborai_water_tank';

  CollectionReference<Map<String, dynamic>> _collection(String table) =>
      _firestore.collection('businesses').doc(businessId).collection(table);

  void startAutoSync() {
    if (_autoSyncStarted) return;

    _autoSyncStarted = true;

    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((isOnline) {
      if (!isOnline) return;

      syncAll();
    });

    assert(_connectivitySubscription != null);
    debugPrint('Automatic sync listener started');
  }

  Future<bool> _ready() async =>
      await _connectivity.isOnline() && _auth.currentUser != null;

  dynamic get _currentUser => PermissionService.currentUser;

  bool _hasPermission(String permissionKey) {
    return PermissionService.hasPermission(_currentUser, permissionKey);
  }

  bool _canDownloadTable(String table) {
    switch (table) {
      case 'clients':
        return _hasPermission(PermissionKeys.clientsView) ||
            _hasPermission(PermissionKeys.salesView) ||
            _hasPermission(PermissionKeys.clientStatementsView);

      case 'suppliers':
        return _hasPermission(PermissionKeys.suppliersView) ||
            _hasPermission(PermissionKeys.salesView) ||
            _hasPermission(PermissionKeys.supplierStatementsView) ||
            _hasPermission(PermissionKeys.profitsView);

      case 'drivers':
        return _hasPermission(PermissionKeys.driversView);

      case 'users':
        return _hasPermission(PermissionKeys.usersManage);

      case 'sales':
        return _hasPermission(PermissionKeys.salesView) ||
            _hasPermission(PermissionKeys.profitsView);

      case 'expenses':
        return _hasPermission(PermissionKeys.profitsView) ||
            _currentUser?.role == 'admin' ||
            _currentUser?.role == 'deputy_manager';

      case 'account_transactions':
        return _hasPermission(PermissionKeys.clientStatementsView) ||
            _hasPermission(PermissionKeys.supplierStatementsView);

      case 'payments':
        return _hasPermission(PermissionKeys.clientStatementsView) ||
            _hasPermission(PermissionKeys.supplierStatementsView);

      case 'purchase_invoices':
      case 'purchase_items':
      case 'inventory_layers':
      case 'sale_inventory_allocations':
        return _hasPermission(PermissionKeys.profitsView) ||
            _currentUser?.role == 'admin' ||
            _currentUser?.role == 'deputy_manager';

      case 'salaries':
      case 'filling_operations':
      case 'tanks':
        return _currentUser?.role == 'admin' ||
            _currentUser?.role == 'deputy_manager';

      default:
        return false;
    }
  }

  Future<List<String>> _columns(Database db, String table) async {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    return rows.map((e) => e['name'].toString()).toList();
  }

  Future<String?> _localSyncId(Database db, String table, dynamic id) async {
    if (id == null) return null;
    final rows = await db.query(table,
        columns: ['sync_id'], where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first['sync_id']?.toString();
  }

  Future<int?> _localId(Database db, String table, dynamic syncId) async {
    if (syncId == null || syncId.toString().isEmpty) return null;
    final rows = await db.query(table,
        columns: ['id'], where: 'sync_id = ?', whereArgs: [syncId], limit: 1);
    return rows.isEmpty ? null : (rows.first['id'] as num).toInt();
  }

  Future<Map<String, dynamic>> _uploadData(
      Database db, String table, Map<String, dynamic> row) async {
    final data = Map<String, dynamic>.from(row)..remove('id');
    data.remove('is_synced');

    if (table == 'users') {
      data.remove('password_hash');
      data.remove('recovery_code_hash');
      data.remove('driver_id');

      if (row['driver_id'] != null) {
        data['driver_sync_id'] =
            await _localSyncId(db, 'drivers', row['driver_id']);
      } else {
        data['driver_sync_id'] = null;
      }
    } else if (table == 'tanks') {
      data['driver_sync_id'] =
          await _localSyncId(db, 'drivers', row['driver_id']);
      data.remove('driver_id');
    } else if (table == 'filling_operations') {
      data['tank_sync_id'] = await _localSyncId(db, 'tanks', row['tank_id']);
      data['supplier_sync_id'] =
          await _localSyncId(db, 'suppliers', row['supplier_id']);
      data['employee_sync_id'] =
          await _localSyncId(db, 'users', row['employee_id']);
      data['created_by_sync_id'] =
          await _localSyncId(db, 'users', row['created_by']);
      data.remove('tank_id');
      data.remove('supplier_id');
      data.remove('employee_id');
      data.remove('created_by');
    } else if (table == 'sales') {
      data['client_sync_id'] =
          await _localSyncId(db, 'clients', row['client_id']);
      data['tank_sync_id'] = await _localSyncId(db, 'tanks', row['tank_id']);
      data['driver_sync_id'] =
          await _localSyncId(db, 'drivers', row['driver_id']);
      data['supplier_sync_id'] =
          await _localSyncId(db, 'suppliers', row['supplier_id']);
      data['created_by_sync_id'] =
          await _localSyncId(db, 'users', row['created_by']);
      data.remove('client_id');
      data.remove('tank_id');
      data.remove('driver_id');
      data.remove('supplier_id');
      data.remove('created_by');
    } else if (table == 'payments') {
      final type = row['payment_type']?.toString();
      data['reference_sync_id'] = type == 'client_payment'
          ? await _localSyncId(db, 'clients', row['reference_id'])
          : type == 'supplier_payment'
              ? await _localSyncId(db, 'suppliers', row['reference_id'])
              : null;
      data['created_by_sync_id'] =
          await _localSyncId(db, 'users', row['created_by']);
      data['purchase_invoice_sync_id'] = await _localSyncId(
        db,
        'purchase_invoices',
        row['purchase_invoice_id'],
      );
      data.remove('reference_id');
      data.remove('created_by');
      data.remove('purchase_invoice_id');
    } else if (table == 'salaries') {
      data['employee_sync_id'] =
          await _localSyncId(db, 'users', row['employee_id']);
      data['created_by_sync_id'] =
          await _localSyncId(db, 'users', row['created_by']);
      data.remove('employee_id');
      data.remove('created_by');
    } else if (table == 'purchase_invoices') {
      data['supplier_sync_id'] =
          await _localSyncId(db, 'suppliers', row['supplier_id']);
      data['created_by_sync_id'] =
          await _localSyncId(db, 'users', row['created_by']);
      data.remove('supplier_id');
      data.remove('created_by');
    } else if (table == 'purchase_items') {
      data['purchase_invoice_sync_id'] = await _localSyncId(
          db, 'purchase_invoices', row['purchase_invoice_id']);
      data.remove('purchase_invoice_id');
    } else if (table == 'inventory_layers') {
      data['purchase_item_sync_id'] =
          await _localSyncId(db, 'purchase_items', row['purchase_item_id']);
      data.remove('purchase_item_id');
    } else if (table == 'sale_inventory_allocations') {
      data['sale_sync_id'] = await _localSyncId(db, 'sales', row['sale_id']);
      data['inventory_layer_sync_id'] =
          await _localSyncId(db, 'inventory_layers', row['inventory_layer_id']);
      data['purchase_item_sync_id'] =
          await _localSyncId(db, 'purchase_items', row['purchase_item_id']);
      data['supplier_sync_id'] =
          await _localSyncId(db, 'suppliers', row['supplier_id']);
      data.remove('sale_id');
      data.remove('inventory_layer_id');
      data.remove('purchase_item_id');
      data.remove('supplier_id');
    } else if (table == 'account_transactions') {
      final type = row['account_type']?.toString();
      data['reference_sync_id'] = type == 'client'
          ? await _localSyncId(db, 'clients', row['reference_id'])
          : type == 'supplier'
              ? await _localSyncId(db, 'suppliers', row['reference_id'])
              : null;
      data['created_by_sync_id'] =
          await _localSyncId(db, 'users', row['created_by']);
      data.remove('reference_id');
      data.remove('created_by');
    } else if (table == 'expenses') {
      data['created_by_sync_id'] =
          await _localSyncId(db, 'users', row['created_by']);
      data.remove('created_by');
    }
    return data;
  }

  Future<void> _uploadTable(String table) async {
    if (!_canUploadTable(table)) return;
    if (!await _ready()) return;
    final db = await _dbHelper.database;
    final rows = await db.query(table, where: 'is_synced = 0');
    for (final row in rows) {
      final syncId = row['sync_id']?.toString();
      if (syncId == null || syncId.isEmpty) continue;
      try {
        final data = await _uploadData(db, table, row);

        final collection = table == 'users'
            ? _firestore
                .collection('businesses')
                .doc(businessId)
                .collection('user_directory')
            : _collection(table);

        final documentId =
            table == 'users' ? row['firebase_uid']?.toString() : syncId;

        if (documentId == null || documentId.isEmpty) {
          debugPrint('$table upload skipped: missing Firebase UID');
          continue;
        }

        await collection.doc(documentId).set(data, SetOptions(merge: true));
        final current = await db.query(table,
            columns: ['updated_at'],
            where: 'id = ?',
            whereArgs: [row['id']],
            limit: 1);
        if (current.isNotEmpty &&
            current.first['updated_at'] == row['updated_at']) {
          await db.update(table, {'is_synced': 1},
              where: 'id = ?', whereArgs: [row['id']]);
        }
      } catch (e) {
        debugPrint('$table upload error: $e');
      }
    }
  }

  bool _remoteIsNewer(Map<String, dynamic> local, Map<String, dynamic> remote) {
    if ((local['is_synced'] as num? ?? 0).toInt() == 0) return false;
    final r = DateTime.tryParse(remote['updated_at']?.toString() ?? '');
    final l = DateTime.tryParse(local['updated_at']?.toString() ?? '');
    if (r == null || l == null) return false;
    return r.isAfter(l);
  }

  Future<Map<String, dynamic>?> _downloadData(
      Database db, String table, Map<String, dynamic> remote) async {
    final data = Map<String, dynamic>.from(remote);
    data.remove('id');
    data.remove('is_synced');

    Future<bool> requireRef(
        String key, String localTable, String localKey) async {
      final value = data[key];
      if (value == null || value.toString().isEmpty) return true;
      final id = await _localId(db, localTable, value);
      if (id == null) return false;
      data[localKey] = id;
      return true;
    }

    if (table == 'users') {
      if (!await requireRef('driver_sync_id', 'drivers', 'driver_id')) {
        return null;
      }
      data.remove('driver_sync_id');

      final existing = await db.query(
        'users',
        where: 'sync_id = ?',
        whereArgs: [remote['sync_id']],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        data['password_hash'] = existing.first['password_hash'];
        data['recovery_code_hash'] = existing.first['recovery_code_hash'];
      } else {
        data['password_hash'] = 'remote_profile_${remote['sync_id']}';
        data['recovery_code_hash'] = null;
      }

      final permissions = data['permissions'];
      if (permissions is Map) {
        data['permissions'] = jsonEncode(
          permissions.map(
            (key, value) => MapEntry(key.toString(), value == true),
          ),
        );
      } else if (permissions == null) {
        data['permissions'] = '{}';
      } else {
        data['permissions'] = permissions.toString();
      }

      final isDeleted = data['is_deleted'];
      if (isDeleted is bool) {
        data['is_deleted'] = isDeleted ? 1 : 0;
      }

      final mustChangePassword = data['must_change_password'];
      if (mustChangePassword is bool) {
        data['must_change_password'] = mustChangePassword ? 1 : 0;
      }
    } else if (table == 'tanks') {
      if (!await requireRef('driver_sync_id', 'drivers', 'driver_id')) {
        return null;
      }
      data.remove('driver_sync_id');
    } else if (table == 'filling_operations') {
      if (!await requireRef('tank_sync_id', 'tanks', 'tank_id')) return null;
      if (!await requireRef('supplier_sync_id', 'suppliers', 'supplier_id')) {
        return null;
      }
      if (!await requireRef('employee_sync_id', 'users', 'employee_id')) {
        return null;
      }
      if (!await requireRef('created_by_sync_id', 'users', 'created_by')) {
        return null;
      }
      data.remove('tank_sync_id');
      data.remove('supplier_sync_id');
      data.remove('employee_sync_id');
      data.remove('created_by_sync_id');
    } else if (table == 'sales') {
      // العميل والخزان والسائق اختياريون في جدول المبيعات.
      // إذا لم يكن المرجع موجودًا على الجهاز الحالي، تبقى المبيعة
      // صالحة مع قيمة NULL بدل منع تنزيلها بالكامل.
      await requireRef('client_sync_id', 'clients', 'client_id');
      await requireRef('tank_sync_id', 'tanks', 'tank_id');
      await requireRef('driver_sync_id', 'drivers', 'driver_id');

      // المورد إلزامي في قاعدة البيانات، لذلك لا يمكن تنزيل
      // المبيعة قبل توفر المورد محليًا.
      if (!await requireRef(
        'supplier_sync_id',
        'suppliers',
        'supplier_id',
      )) {
        return null;
      }

      final creatorSyncId = data['created_by_sync_id']?.toString();
      if (creatorSyncId != null && creatorSyncId.isNotEmpty) {
        var creatorId = await _localId(db, 'users', creatorSyncId);

        if (creatorId == null) {
          final now = DateTime.now().toIso8601String();
          creatorId = await db.insert(
            'users',
            {
              'username': 'remote_creator_$creatorSyncId',
              'password_hash':
                  'remote_${DateTime.now().microsecondsSinceEpoch}',
              'recovery_code_hash': null,
              'full_name': data['created_by_name']?.toString() ?? 'مستخدم سابق',
              'role': 'member',
              'driver_id': null,
              'permissions': '{}',
              'created_at': data['created_at']?.toString() ?? now,
              'updated_at': data['updated_at']?.toString() ?? now,
              'is_deleted': 0,
              'is_synced': 1,
              'sync_id': creatorSyncId,
              'firebase_uid': null,
              'firebase_email': null,
              'must_change_password': 1,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );

          if (creatorId == 0) {
            creatorId = await _localId(db, 'users', creatorSyncId);
          }
        }

        if (creatorId == null) return null;
        data['created_by'] = creatorId;
      }

      data.remove('client_sync_id');
      data.remove('tank_sync_id');
      data.remove('driver_sync_id');
      data.remove('supplier_sync_id');
      data.remove('created_by_sync_id');
    } else if (table == 'payments') {
      final type = data['payment_type']?.toString();
      if (data['reference_sync_id'] != null) {
        final t = type == 'client_payment'
            ? 'clients'
            : type == 'supplier_payment'
                ? 'suppliers'
                : null;
        if (t == null ||
            !await requireRef('reference_sync_id', t, 'reference_id')) {
          return null;
        }
      }
      if (!await requireRef('created_by_sync_id', 'users', 'created_by')) {
        return null;
      }
      if (!await requireRef('purchase_invoice_sync_id', 'purchase_invoices',
          'purchase_invoice_id')) {
        return null;
      }
      data.remove('reference_sync_id');
      data.remove('created_by_sync_id');
      data.remove('purchase_invoice_sync_id');
    } else if (table == 'salaries') {
      if (!await requireRef('employee_sync_id', 'users', 'employee_id')) {
        return null;
      }
      if (!await requireRef('created_by_sync_id', 'users', 'created_by')) {
        return null;
      }
      data.remove('employee_sync_id');
      data.remove('created_by_sync_id');
    } else if (table == 'purchase_invoices') {
      if (!await requireRef('supplier_sync_id', 'suppliers', 'supplier_id')) {
        return null;
      }
      if (!await requireRef('created_by_sync_id', 'users', 'created_by')) {
        return null;
      }
      data.remove('supplier_sync_id');
      data.remove('created_by_sync_id');
    } else if (table == 'purchase_items') {
      if (!await requireRef('purchase_invoice_sync_id', 'purchase_invoices',
          'purchase_invoice_id')) {
        return null;
      }
      data.remove('purchase_invoice_sync_id');
    } else if (table == 'inventory_layers') {
      if (!await requireRef(
          'purchase_item_sync_id', 'purchase_items', 'purchase_item_id')) {
        return null;
      }
      data.remove('purchase_item_sync_id');
    } else if (table == 'sale_inventory_allocations') {
      if (!await requireRef('sale_sync_id', 'sales', 'sale_id')) return null;
      if (!await requireRef('inventory_layer_sync_id', 'inventory_layers',
          'inventory_layer_id')) {
        return null;
      }
      if (!await requireRef(
          'purchase_item_sync_id', 'purchase_items', 'purchase_item_id')) {
        return null;
      }
      if (!await requireRef('supplier_sync_id', 'suppliers', 'supplier_id')) {
        return null;
      }
      data.remove('sale_sync_id');
      data.remove('inventory_layer_sync_id');
      data.remove('purchase_item_sync_id');
      data.remove('supplier_sync_id');
    } else if (table == 'account_transactions') {
      final type = data['account_type']?.toString();
      if (data['reference_sync_id'] != null) {
        final t = type == 'client'
            ? 'clients'
            : type == 'supplier'
                ? 'suppliers'
                : null;
        if (t == null ||
            !await requireRef('reference_sync_id', t, 'reference_id')) {
          return null;
        }
      }
      if (!await requireRef('created_by_sync_id', 'users', 'created_by')) {
        return null;
      }
      data.remove('reference_sync_id');
      data.remove('created_by_sync_id');
    } else if (table == 'expenses') {
      if (!await requireRef('created_by_sync_id', 'users', 'created_by')) {
        return null;
      }
      data.remove('created_by_sync_id');
    }
    data['sync_id'] = remote['sync_id'];
    data['is_synced'] = 1;
    return data;
  }

  bool _canUploadTable(String table) {
    final isManagement =
        _currentUser?.role == 'admin' || _currentUser?.role == 'deputy_manager';

    switch (table) {
      case 'clients':
        return _hasPermission(PermissionKeys.clientsAdd) ||
            _hasPermission(PermissionKeys.clientsEdit) ||
            _hasPermission(PermissionKeys.clientsDelete);

      case 'suppliers':
        return _hasPermission(PermissionKeys.suppliersAdd) ||
            _hasPermission(PermissionKeys.suppliersEdit) ||
            _hasPermission(PermissionKeys.suppliersDelete);

      case 'drivers':
        return _hasPermission(PermissionKeys.driversAdd) ||
            _hasPermission(PermissionKeys.driversEdit) ||
            _hasPermission(PermissionKeys.driversDelete);

      case 'users':
        return _hasPermission(PermissionKeys.usersManage);

      case 'sales':
        return _hasPermission(PermissionKeys.salesAdd) ||
            _hasPermission(PermissionKeys.salesEdit) ||
            _hasPermission(PermissionKeys.salesDelete);

      case 'tanks':
      case 'filling_operations':
      case 'purchase_invoices':
      case 'purchase_items':
      case 'inventory_layers':
      case 'sale_inventory_allocations':
      case 'account_transactions':
      case 'payments':
      case 'expenses':
      case 'salaries':
        return isManagement;

      default:
        return false;
    }
  }

  Future<void> _downloadTable(String table) async {
    if (!_canDownloadTable(table)) return;
    if (!await _ready()) return;
    final db = await _dbHelper.database;

    final collection = table == 'users'
        ? _firestore
            .collection('businesses')
            .doc(businessId)
            .collection('user_directory')
        : _collection(table);

    final snapshot = await collection.get();
    final columns = await _columns(db, table);
    for (final doc in snapshot.docs) {
      try {
        final remote = Map<String, dynamic>.from(doc.data());
        final syncId = remote['sync_id']?.toString() ?? doc.id;
        if (syncId.isEmpty) continue;
        remote['sync_id'] = syncId;
        final existing = await db.query(table,
            where: 'sync_id = ?', whereArgs: [syncId], limit: 1);
        if (existing.isNotEmpty && !_remoteIsNewer(existing.first, remote)) {
          continue;
        }
        if (existing.isEmpty && remote['updated_at'] == null) continue;
        final data = await _downloadData(db, table, remote);
        if (data == null) continue;
        data.removeWhere((key, _) => !columns.contains(key));
        if (existing.isEmpty) {
          await db.insert(table, data,
              conflictAlgorithm: ConflictAlgorithm.ignore);
        } else {
          await db
              .update(table, data, where: 'sync_id = ?', whereArgs: [syncId]);
        }
      } catch (e) {
        debugPrint('$table download error: $e');
      }
    }
  }

  Future<void> syncClients() => _uploadTable('clients');
  Future<void> syncSuppliers() => _uploadTable('suppliers');
  Future<void> syncDrivers() => _uploadTable('drivers');
  Future<void> syncUsers() => _uploadTable('users');
  Future<void> syncTanks() => _uploadTable('tanks');
  Future<void> syncFillingOperations() => _uploadTable('filling_operations');
  Future<void> syncSales() => _uploadTable('sales');
  Future<void> syncPayments() => _uploadTable('payments');
  Future<void> syncExpenses() => _uploadTable('expenses');
  Future<void> syncSalaries() => _uploadTable('salaries');

  Future<void> downloadClients() => _downloadTable('clients');
  Future<void> downloadUsers() => _downloadTable('users');
  Future<void> downloadTanks() => _downloadTable('tanks');
  Future<void> downloadFillingOperations() =>
      _downloadTable('filling_operations');
  Future<void> downloadSales() => _downloadTable('sales');
  Future<void> downloadPayments() => _downloadTable('payments');
  Future<void> downloadExpenses() => _downloadTable('expenses');
  Future<void> downloadSalaries() => _downloadTable('salaries');
  Future<void> downloadTable(String tableName) => _downloadTable(tableName);

  bool _syncInProgress = false;

  Future<void> syncAll() async {
    if (_syncInProgress) {
      debugPrint('Sync skipped: another sync is already in progress');
      return;
    }

    if (!await _ready()) return;

    _syncInProgress = true;

    try {
      final db = await _dbHelper.database;

      try {
        await db.execute('PRAGMA foreign_keys = ON');
      } catch (_) {}

      const order = [
        'suppliers',
        'clients',
        'drivers',
        'users',
        'tanks',
        'purchase_invoices',
        'purchase_items',
        'inventory_layers',
        'sales',
        'sale_inventory_allocations',
        'account_transactions',
        'payments',
        'expenses',
        'salaries',
        'filling_operations',
      ];

      for (final table in order) {
        await _uploadTable(table);
      }

      for (final table in order) {
        await _downloadTable(table);
      }

      debugPrint('Sync completed successfully');
    } catch (e, stackTrace) {
      debugPrint('Sync failed: $e');
      debugPrint('$stackTrace');
    } finally {
      _syncInProgress = false;
    }
  }
}
