#!/bin/bash

# إنشاء المجلدات اللازمة
mkdir -p lib/core/constants
mkdir -p lib/core/database
mkdir -p lib/core/network
mkdir -p lib/core/auth
mkdir -p lib/core/utils
mkdir -p lib/core/widgets
mkdir -p lib/models
mkdir -p lib/services
mkdir -p lib/screens/login
mkdir -p lib/screens/dashboard

# ---------- 1. lib/core/constants/app_constants.dart ----------
cat > lib/core/constants/app_constants.dart << 'EOF'
class AppConstants {
  static const String appName = 'شركة البرعي للمياه';
  static const String companyName = 'شركة البرعي للمياه';
  static const int unitLiters = 1000; // الوحدة = 1000 لتر
  static const int maxUnitsPerSale = 22; // أقصى عدد وحدات للبيع
  static const int minUnitsPerSale = 1;  // أقل عدد وحدات
  static const String localDbName = 'alborai_water_db.db';
  static const int localDbVersion = 1;
}
EOF

# ---------- 2. lib/core/constants/permissions.dart ----------
cat > lib/core/constants/permissions.dart << 'EOF'
class PermissionKeys {
  static const String clientsView = 'clients_view';
  static const String clientsAdd = 'clients_add';
  static const String clientsEdit = 'clients_edit';
  static const String clientsDelete = 'clients_delete';

  static const String salesView = 'sales_view';
  static const String salesAdd = 'sales_add';
  static const String salesEdit = 'sales_edit';
  static const String salesDelete = 'sales_delete';

  static const String suppliersView = 'suppliers_view';
  static const String suppliersAdd = 'suppliers_add';
  static const String suppliersEdit = 'suppliers_edit';
  static const String suppliersDelete = 'suppliers_delete';

  static const String clientStatementsView = 'client_statements_view';
  static const String supplierStatementsView = 'supplier_statements_view';

  static const String profitsView = 'profits_view';
  static const String pricesEdit = 'prices_edit';

  static const String usersManage = 'users_manage';
  static const String permissionsManage = 'permissions_manage';
}

class DefaultPermissions {
  static Map<String, bool> admin() {
    return {
      PermissionKeys.clientsView: true,
      PermissionKeys.clientsAdd: true,
      PermissionKeys.clientsEdit: true,
      PermissionKeys.clientsDelete: true,
      PermissionKeys.salesView: true,
      PermissionKeys.salesAdd: true,
      PermissionKeys.salesEdit: true,
      PermissionKeys.salesDelete: true,
      PermissionKeys.suppliersView: true,
      PermissionKeys.suppliersAdd: true,
      PermissionKeys.suppliersEdit: true,
      PermissionKeys.suppliersDelete: true,
      PermissionKeys.clientStatementsView: true,
      PermissionKeys.supplierStatementsView: true,
      PermissionKeys.profitsView: true,
      PermissionKeys.pricesEdit: true,
      PermissionKeys.usersManage: true,
      PermissionKeys.permissionsManage: true,
    };
  }

  static Map<String, bool> salesEmployee() {
    return {
      PermissionKeys.clientsView: true,
      PermissionKeys.clientsAdd: true,
      PermissionKeys.clientsEdit: true,
      PermissionKeys.clientsDelete: false,
      PermissionKeys.salesView: true,
      PermissionKeys.salesAdd: true,
      PermissionKeys.salesEdit: false,
      PermissionKeys.salesDelete: false,
      PermissionKeys.suppliersView: true,
      PermissionKeys.suppliersAdd: true,
      PermissionKeys.suppliersEdit: false,
      PermissionKeys.suppliersDelete: false,
      PermissionKeys.clientStatementsView: true,
      PermissionKeys.supplierStatementsView: true,
      PermissionKeys.profitsView: false,
      PermissionKeys.pricesEdit: false,
      PermissionKeys.usersManage: false,
      PermissionKeys.permissionsManage: false,
    };
  }
}
EOF

# ---------- 3. lib/core/database/database_helper.dart ----------
cat > lib/core/database/database_helper.dart << 'EOF'
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../constants/app_constants.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.localDbName);
    return await openDatabase(
      path,
      version: AppConstants.localDbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        full_name TEXT NOT NULL,
        role TEXT NOT NULL,
        permissions TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE clients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_number TEXT UNIQUE,
        name TEXT NOT NULL,
        phone TEXT,
        address TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE suppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supplier_number TEXT UNIQUE,
        name TEXT NOT NULL,
        phone TEXT,
        location TEXT,
        status TEXT DEFAULT 'active',
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE drivers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        license_number TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE tanks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tank_number TEXT UNIQUE NOT NULL,
        capacity_units INTEGER NOT NULL,
        driver_id INTEGER,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY (driver_id) REFERENCES drivers (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE filling_operations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operation_number TEXT UNIQUE,
        tank_id INTEGER NOT NULL,
        supplier_id INTEGER NOT NULL,
        units INTEGER NOT NULL,
        purchase_price REAL NOT NULL,
        operation_date TEXT NOT NULL,
        employee_id INTEGER,
        notes TEXT,
        created_by INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY (tank_id) REFERENCES tanks (id),
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id),
        FOREIGN KEY (employee_id) REFERENCES users (id),
        FOREIGN KEY (created_by) REFERENCES users (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_number TEXT UNIQUE,
        client_id INTEGER NOT NULL,
        tank_id INTEGER NOT NULL,
        driver_id INTEGER,
        supplier_id INTEGER,
        units INTEGER NOT NULL,
        sale_price REAL NOT NULL,
        total_amount REAL NOT NULL,
        cost_amount REAL NOT NULL,
        profit_amount REAL NOT NULL,
        sale_date TEXT NOT NULL,
        payment_status TEXT NOT NULL,
        notes TEXT,
        created_by INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY (client_id) REFERENCES clients (id),
        FOREIGN KEY (tank_id) REFERENCES tanks (id),
        FOREIGN KEY (driver_id) REFERENCES drivers (id),
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id),
        FOREIGN KEY (created_by) REFERENCES users (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        payment_type TEXT NOT NULL,
        reference_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        payment_date TEXT NOT NULL,
        notes TEXT,
        created_by INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY (created_by) REFERENCES users (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        expense_type TEXT NOT NULL,
        amount REAL NOT NULL,
        expense_date TEXT NOT NULL,
        notes TEXT,
        created_by INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY (created_by) REFERENCES users (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE salaries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER NOT NULL,
        month TEXT NOT NULL,
        base_salary REAL NOT NULL,
        advances REAL DEFAULT 0,
        deductions REAL DEFAULT 0,
        net_salary REAL NOT NULL,
        payment_date TEXT,
        notes TEXT,
        created_by INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY (employee_id) REFERENCES users (id),
        FOREIGN KEY (created_by) REFERENCES users (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE operation_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        action TEXT NOT NULL,
        table_name TEXT NOT NULL,
        record_id INTEGER NOT NULL,
        details TEXT,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // مستقبلًا يمكن إضافة ترقيات تدريجية
  }
}
EOF

# ---------- 4. lib/core/network/connectivity_service.dart ----------
cat > lib/core/network/connectivity_service.dart << 'EOF'
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  Stream<bool> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged.map((result) => result != ConnectivityResult.none);

  Future<bool> isOnline() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }
}
EOF

# ---------- 5. lib/core/network/sync_service.dart ----------
cat > lib/core/network/sync_service.dart << 'EOF'
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../database/database_helper.dart';
import 'connectivity_service.dart';

class SyncService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ConnectivityService _connectivity = ConnectivityService();

  Future<void> syncTable(String tableName) async {
    if (!await _connectivity.isOnline()) return;
    final db = await _dbHelper.database;
    final localData = await db.query(tableName, where: 'is_synced = ?', whereArgs: [0]);
    for (var row in localData) {
      try {
        await _firestore
            .collection('users')
            .doc(_auth.currentUser?.uid)
            .collection(tableName)
            .doc(row['id'].toString())
            .set(row, SetOptions(merge: true));
        await db.update(tableName, {'is_synced': 1}, where: 'id = ?', whereArgs: [row['id']]);
      } catch (e) {
        print('Sync error for $tableName id ${row['id']}: $e');
      }
    }
  }

  Future<void> syncAll() async {
    final tables = ['clients', 'suppliers', 'tanks', 'drivers', 'sales', 'filling_operations', 'payments', 'expenses', 'salaries'];
    for (var table in tables) {
      await syncTable(table);
    }
  }

  Future<void> dailyBackup() async {
    if (!await _connectivity.isOnline()) return;
    final db = await _dbHelper.database;
    final tables = ['clients', 'suppliers', 'tanks', 'drivers', 'sales', 'filling_operations', 'payments', 'expenses', 'salaries'];
    final backupData = <String, dynamic>{};
    for (var table in tables) {
      backupData[table] = await db.query(table);
    }
    await _firestore
        .collection('backups')
        .doc(_auth.currentUser?.uid)
        .collection('daily')
        .doc(DateTime.now().toIso8601String())
        .set(backupData);
  }
}
EOF

# ---------- 6. lib/core/auth/permission_service.dart ----------
cat > lib/core/auth/permission_service.dart << 'EOF'
import '../../models/user.dart';

class PermissionService {
  static bool hasPermission(User? user, String permissionKey) {
    if (user == null) return false;
    return user.permissions[permissionKey] ?? false;
  }

  static bool hasAnyPermission(User? user, List<String> permissionKeys) {
    if (user == null) return false;
    return permissionKeys.any((key) => user.permissions[key] ?? false);
  }

  static bool hasAllPermissions(User? user, List<String> permissionKeys) {
    if (user == null) return false;
    return permissionKeys.every((key) => user.permissions[key] ?? false);
  }
}
EOF

# ---------- 7. lib/core/auth/user_provider.dart ----------
cat > lib/core/auth/user_provider.dart << 'EOF'
import 'package:flutter/foundation.dart';
import '../../models/user.dart';

class UserProvider extends ChangeNotifier {
  User? _currentUser;
  User? get currentUser => _currentUser;

  void setUser(User? user) {
    _currentUser = user;
    notifyListeners();
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }
}
EOF

# ---------- 8. lib/core/auth/auth_service.dart ----------
cat > lib/core/auth/auth_service.dart << 'EOF'
import 'package:sqflite/sqflite.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../database/database_helper.dart';
import '../../models/user.dart';
import '../constants/permissions.dart';

class AuthService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<User?> login(String username, String password) async {
    final db = await _dbHelper.database;
    final passwordHash = _hashPassword(password);
    final result = await db.query(
      'users',
      where: 'username = ? AND password_hash = ?',
      whereArgs: [username, passwordHash],
    );
    if (result.isNotEmpty) {
      return User.fromMap(result.first);
    }
    return null;
  }

  Future<int> createUser({
    required String username,
    required String password,
    required String fullName,
    required String role,
    Map<String, bool>? permissions,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    final user = User(
      username: username,
      passwordHash: _hashPassword(password),
      fullName: fullName,
      role: role,
      permissions: permissions ?? DefaultPermissions.salesEmployee(),
      createdAt: now,
      updatedAt: now,
    );
    return await db.insert('users', user.toMap());
  }

  Future<void> updatePermissions(int userId, Map<String, bool> newPermissions) async {
    final db = await _dbHelper.database;
    await db.update(
      'users',
      {
        'permissions': User.permissionsToJson(newPermissions),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<List<User>> getAllUsers() async {
    final db = await _dbHelper.database;
    final result = await db.query('users', where: 'is_deleted = 0');
    return result.map((e) => User.fromMap(e)).toList();
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
EOF

# ---------- 9. lib/models/user.dart ----------
cat > lib/models/user.dart << 'EOF'
import 'dart:convert';

class User {
  final int? id;
  final String username;
  final String passwordHash;
  final String fullName;
  final String role;
  Map<String, bool> permissions;
  final String createdAt;
  final String updatedAt;

  User({
    this.id,
    required this.username,
    required this.passwordHash,
    required this.fullName,
    required this.role,
    required this.permissions,
    required this.createdAt,
    required this.updatedAt,
  });

  static Map<String, bool> permissionsFromJson(String json) {
    final Map<String, dynamic> decoded = jsonDecode(json);
    return decoded.map((key, value) => MapEntry(key, value as bool));
  }

  static String permissionsToJson(Map<String, bool> permissions) {
    return jsonEncode(permissions);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'password_hash': passwordHash,
      'full_name': fullName,
      'role': role,
      'permissions': permissionsToJson(permissions),
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_deleted': 0,
      'is_synced': 0,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      username: map['username'],
      passwordHash: map['password_hash'],
      fullName: map['full_name'],
      role: map['role'],
      permissions: permissionsFromJson(map['permissions']),
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
    );
  }
}
EOF

# ---------- 10. lib/models/client.dart ----------
cat > lib/models/client.dart << 'EOF'
class Client {
  final int? id;
  final String? clientNumber;
  final String name;
  final String? phone;
  final String? address;
  final String? notes;
  final String createdAt;
  final String updatedAt;
  final bool isDeleted;
  final bool isSynced;

  Client({
    this.id,
    this.clientNumber,
    required this.name,
    this.phone,
    this.address,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'client_number': clientNumber,
      'name': name,
      'phone': phone,
      'address': address,
      'notes': notes,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_deleted': isDeleted ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: map['id'],
      clientNumber: map['client_number'],
      name: map['name'],
      phone: map['phone'],
      address: map['address'],
      notes: map['notes'],
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
      isDeleted: map['is_deleted'] == 1,
      isSynced: map['is_synced'] == 1,
    );
  }
}
EOF

# ---------- 11. lib/models/supplier.dart ----------
cat > lib/models/supplier.dart << 'EOF'
class Supplier {
  final int? id;
  final String? supplierNumber;
  final String name;
  final String? phone;
  final String? location;
  final String status; // active / inactive
  final String? notes;
  final String createdAt;
  final String updatedAt;
  final bool isDeleted;
  final bool isSynced;

  Supplier({
    this.id,
    this.supplierNumber,
    required this.name,
    this.phone,
    this.location,
    this.status = 'active',
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'supplier_number': supplierNumber,
      'name': name,
      'phone': phone,
      'location': location,
      'status': status,
      'notes': notes,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_deleted': isDeleted ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'],
      supplierNumber: map['supplier_number'],
      name: map['name'],
      phone: map['phone'],
      location: map['location'],
      status: map['status'] ?? 'active',
      notes: map['notes'],
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
      isDeleted: map['is_deleted'] == 1,
      isSynced: map['is_synced'] == 1,
    );
  }
}
EOF

# ---------- 12. lib/models/driver.dart ----------
cat > lib/models/driver.dart << 'EOF'
class Driver {
  final int? id;
  final String name;
  final String? phone;
  final String? licenseNumber;
  final String? notes;
  final String createdAt;
  final String updatedAt;
  final bool isDeleted;
  final bool isSynced;

  Driver({
    this.id,
    required this.name,
    this.phone,
    this.licenseNumber,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'license_number': licenseNumber,
      'notes': notes,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_deleted': isDeleted ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory Driver.fromMap(Map<String, dynamic> map) {
    return Driver(
      id: map['id'],
      name: map['name'],
      phone: map['phone'],
      licenseNumber: map['license_number'],
      notes: map['notes'],
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
      isDeleted: map['is_deleted'] == 1,
      isSynced: map['is_synced'] == 1,
    );
  }
}
EOF

# ---------- 13. lib/models/tank.dart ----------
cat > lib/models/tank.dart << 'EOF'
class Tank {
  final int? id;
  final String tankNumber;
  final int capacityUnits;
  final int? driverId;
  final String? notes;
  final String createdAt;
  final String updatedAt;
  final bool isDeleted;
  final bool isSynced;

  Tank({
    this.id,
    required this.tankNumber,
    required this.capacityUnits,
    this.driverId,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tank_number': tankNumber,
      'capacity_units': capacityUnits,
      'driver_id': driverId,
      'notes': notes,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_deleted': isDeleted ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory Tank.fromMap(Map<String, dynamic> map) {
    return Tank(
      id: map['id'],
      tankNumber: map['tank_number'],
      capacityUnits: map['capacity_units'],
      driverId: map['driver_id'],
      notes: map['notes'],
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
      isDeleted: map['is_deleted'] == 1,
      isSynced: map['is_synced'] == 1,
    );
  }
}
EOF

# ---------- 14. lib/models/filling_operation.dart ----------
cat > lib/models/filling_operation.dart << 'EOF'
class FillingOperation {
  final int? id;
  final String? operationNumber;
  final int tankId;
  final int supplierId;
  final int units;
  final double purchasePrice;
  final String operationDate;
  final int? employeeId;
  final String? notes;
  final int createdBy;
  final String createdAt;
  final String updatedAt;
  final bool isDeleted;
  final bool isSynced;

  FillingOperation({
    this.id,
    this.operationNumber,
    required this.tankId,
    required this.supplierId,
    required this.units,
    required this.purchasePrice,
    required this.operationDate,
    this.employeeId,
    this.notes,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'operation_number': operationNumber,
      'tank_id': tankId,
      'supplier_id': supplierId,
      'units': units,
      'purchase_price': purchasePrice,
      'operation_date': operationDate,
      'employee_id': employeeId,
      'notes': notes,
      'created_by': createdBy,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_deleted': isDeleted ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory FillingOperation.fromMap(Map<String, dynamic> map) {
    return FillingOperation(
      id: map['id'],
      operationNumber: map['operation_number'],
      tankId: map['tank_id'],
      supplierId: map['supplier_id'],
      units: map['units'],
      purchasePrice: map['purchase_price'],
      operationDate: map['operation_date'],
      employeeId: map['employee_id'],
      notes: map['notes'],
      createdBy: map['created_by'],
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
      isDeleted: map['is_deleted'] == 1,
      isSynced: map['is_synced'] == 1,
    );
  }
}
EOF

# ---------- 15. lib/models/sale.dart ----------
cat > lib/models/sale.dart << 'EOF'
class Sale {
  final int? id;
  final String? saleNumber;
  final int clientId;
  final int tankId;
  final int? driverId;
  final int? supplierId;
  final int units;
  final double salePrice;
  final double totalAmount;
  final double costAmount;
  final double profitAmount;
  final String saleDate;
  final String paymentStatus; // paid, partial, unpaid
  final String? notes;
  final int createdBy;
  final String createdAt;
  final String updatedAt;
  final bool isDeleted;
  final bool isSynced;

  Sale({
    this.id,
    this.saleNumber,
    required this.clientId,
    required this.tankId,
    this.driverId,
    this.supplierId,
    required this.units,
    required this.salePrice,
    required this.totalAmount,
    required this.costAmount,
    required this.profitAmount,
    required this.saleDate,
    required this.paymentStatus,
    this.notes,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sale_number': saleNumber,
      'client_id': clientId,
      'tank_id': tankId,
      'driver_id': driverId,
      'supplier_id': supplierId,
      'units': units,
      'sale_price': salePrice,
      'total_amount': totalAmount,
      'cost_amount': costAmount,
      'profit_amount': profitAmount,
      'sale_date': saleDate,
      'payment_status': paymentStatus,
      'notes': notes,
      'created_by': createdBy,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_deleted': isDeleted ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id'],
      saleNumber: map['sale_number'],
      clientId: map['client_id'],
      tankId: map['tank_id'],
      driverId: map['driver_id'],
      supplierId: map['supplier_id'],
      units: map['units'],
      salePrice: map['sale_price'],
      totalAmount: map['total_amount'],
      costAmount: map['cost_amount'],
      profitAmount: map['profit_amount'],
      saleDate: map['sale_date'],
      paymentStatus: map['payment_status'],
      notes: map['notes'],
      createdBy: map['created_by'],
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
      isDeleted: map['is_deleted'] == 1,
      isSynced: map['is_synced'] == 1,
    );
  }
}
EOF

# ---------- 16. lib/models/payment.dart ----------
cat > lib/models/payment.dart << 'EOF'
class Payment {
  final int? id;
  final String paymentType; // client_payment / supplier_payment
  final int referenceId;    // client_id or supplier_id
  final double amount;
  final String paymentDate;
  final String? notes;
  final int createdBy;
  final String createdAt;
  final String updatedAt;
  final bool isDeleted;
  final bool isSynced;

  Payment({
    this.id,
    required this.paymentType,
    required this.referenceId,
    required this.amount,
    required this.paymentDate,
    this.notes,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'payment_type': paymentType,
      'reference_id': referenceId,
      'amount': amount,
      'payment_date': paymentDate,
      'notes': notes,
      'created_by': createdBy,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_deleted': isDeleted ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'],
      paymentType: map['payment_type'],
      referenceId: map['reference_id'],
      amount: map['amount'],
      paymentDate: map['payment_date'],
      notes: map['notes'],
      createdBy: map['created_by'],
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
      isDeleted: map['is_deleted'] == 1,
      isSynced: map['is_synced'] == 1,
    );
  }
}
EOF

# ---------- 17. lib/models/expense.dart ----------
cat > lib/models/expense.dart << 'EOF'
class Expense {
  final int? id;
  final String expenseType;
  final double amount;
  final String expenseDate;
  final String? notes;
  final int createdBy;
  final String createdAt;
  final String updatedAt;
  final bool isDeleted;
  final bool isSynced;

  Expense({
    this.id,
    required this.expenseType,
    required this.amount,
    required this.expenseDate,
    this.notes,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'expense_type': expenseType,
      'amount': amount,
      'expense_date': expenseDate,
      'notes': notes,
      'created_by': createdBy,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_deleted': isDeleted ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'],
      expenseType: map['expense_type'],
      amount: map['amount'],
      expenseDate: map['expense_date'],
      notes: map['notes'],
      createdBy: map['created_by'],
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
      isDeleted: map['is_deleted'] == 1,
      isSynced: map['is_synced'] == 1,
    );
  }
}
EOF

# ---------- 18. lib/models/salary.dart ----------
cat > lib/models/salary.dart << 'EOF'
class Salary {
  final int? id;
  final int employeeId;
  final String month;
  final double baseSalary;
  final double advances;
  final double deductions;
  final double netSalary;
  final String? paymentDate;
  final String? notes;
  final int createdBy;
  final String createdAt;
  final String updatedAt;
  final bool isDeleted;
  final bool isSynced;

  Salary({
    this.id,
    required this.employeeId,
    required this.month,
    required this.baseSalary,
    this.advances = 0,
    this.deductions = 0,
    required this.netSalary,
    this.paymentDate,
    this.notes,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'employee_id': employeeId,
      'month': month,
      'base_salary': baseSalary,
      'advances': advances,
      'deductions': deductions,
      'net_salary': netSalary,
      'payment_date': paymentDate,
      'notes': notes,
      'created_by': createdBy,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_deleted': isDeleted ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory Salary.fromMap(Map<String, dynamic> map) {
    return Salary(
      id: map['id'],
      employeeId: map['employee_id'],
      month: map['month'],
      baseSalary: map['base_salary'],
      advances: map['advances'],
      deductions: map['deductions'],
      netSalary: map['net_salary'],
      paymentDate: map['payment_date'],
      notes: map['notes'],
      createdBy: map['created_by'],
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
      isDeleted: map['is_deleted'] == 1,
      isSynced: map['is_synced'] == 1,
    );
  }
}
EOF

# ---------- 19. lib/services/client_service.dart ----------
cat > lib/services/client_service.dart << 'EOF'
import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../models/client.dart';

class ClientService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<int> addClient(Client client) async {
    final db = await _dbHelper.database;
    return await db.insert('clients', client.toMap());
  }

  Future<List<Client>> getAllClients() async {
    final db = await _dbHelper.database;
    final result = await db.query('clients', where: 'is_deleted = 0', orderBy: 'name ASC');
    return result.map((e) => Client.fromMap(e)).toList();
  }

  Future<Client?> getClientById(int id) async {
    final db = await _dbHelper.database;
    final result = await db.query('clients', where: 'id = ? AND is_deleted = 0', whereArgs: [id]);
    if (result.isNotEmpty) return Client.fromMap(result.first);
    return null;
  }

  Future<void> updateClient(Client client) async {
    final db = await _dbHelper.database;
    await db.update('clients', client.toMap(), where: 'id = ?', whereArgs: [client.id]);
  }

  Future<void> deleteClient(int id) async {
    final db = await _dbHelper.database;
    await db.update('clients', {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
  }
}
EOF

# ---------- 20. lib/services/supplier_service.dart ----------
cat > lib/services/supplier_service.dart << 'EOF'
import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../models/supplier.dart';

class SupplierService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<int> addSupplier(Supplier supplier) async {
    final db = await _dbHelper.database;
    return await db.insert('suppliers', supplier.toMap());
  }

  Future<List<Supplier>> getAllSuppliers() async {
    final db = await _dbHelper.database;
    final result = await db.query('suppliers', where: 'is_deleted = 0', orderBy: 'name ASC');
    return result.map((e) => Supplier.fromMap(e)).toList();
  }

  Future<Supplier?> getSupplierById(int id) async {
    final db = await _dbHelper.database;
    final result = await db.query('suppliers', where: 'id = ? AND is_deleted = 0', whereArgs: [id]);
    if (result.isNotEmpty) return Supplier.fromMap(result.first);
    return null;
  }

  Future<void> updateSupplier(Supplier supplier) async {
    final db = await _dbHelper.database;
    await db.update('suppliers', supplier.toMap(), where: 'id = ?', whereArgs: [supplier.id]);
  }

  Future<void> deleteSupplier(int id) async {
    final db = await _dbHelper.database;
    await db.update('suppliers', {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
  }
}
EOF

# ---------- 21. lib/services/driver_service.dart ----------
cat > lib/services/driver_service.dart << 'EOF'
import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../models/driver.dart';

class DriverService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<int> addDriver(Driver driver) async {
    final db = await _dbHelper.database;
    return await db.insert('drivers', driver.toMap());
  }

  Future<List<Driver>> getAllDrivers() async {
    final db = await _dbHelper.database;
    final result = await db.query('drivers', where: 'is_deleted = 0', orderBy: 'name ASC');
    return result.map((e) => Driver.fromMap(e)).toList();
  }

  Future<Driver?> getDriverById(int id) async {
    final db = await _dbHelper.database;
    final result = await db.query('drivers', where: 'id = ? AND is_deleted = 0', whereArgs: [id]);
    if (result.isNotEmpty) return Driver.fromMap(result.first);
    return null;
  }

  Future<void> updateDriver(Driver driver) async {
    final db = await _dbHelper.database;
    await db.update('drivers', driver.toMap(), where: 'id = ?', whereArgs: [driver.id]);
  }

  Future<void> deleteDriver(int id) async {
    final db = await _dbHelper.database;
    await db.update('drivers', {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
  }
}
EOF

# ---------- 22. lib/services/tank_service.dart ----------
cat > lib/services/tank_service.dart << 'EOF'
import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../models/tank.dart';

class TankService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<int> addTank(Tank tank) async {
    final db = await _dbHelper.database;
    return await db.insert('tanks', tank.toMap());
  }

  Future<List<Tank>> getAllTanks() async {
    final db = await _dbHelper.database;
    final result = await db.query('tanks', where: 'is_deleted = 0', orderBy: 'tank_number ASC');
    return result.map((e) => Tank.fromMap(e)).toList();
  }

  Future<Tank?> getTankById(int id) async {
    final db = await _dbHelper.database;
    final result = await db.query('tanks', where: 'id = ? AND is_deleted = 0', whereArgs: [id]);
    if (result.isNotEmpty) return Tank.fromMap(result.first);
    return null;
  }

  Future<void> updateTank(Tank tank) async {
    final db = await _dbHelper.database;
    await db.update('tanks', tank.toMap(), where: 'id = ?', whereArgs: [tank.id]);
  }

  Future<void> deleteTank(int id) async {
    final db = await _dbHelper.database;
    await db.update('tanks', {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
  }
}
EOF

# ---------- 23. lib/services/filling_operation_service.dart ----------
cat > lib/services/filling_operation_service.dart << 'EOF'
import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../models/filling_operation.dart';

class FillingOperationService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<int> addOperation(FillingOperation operation) async {
    final db = await _dbHelper.database;
    return await db.insert('filling_operations', operation.toMap());
  }

  Future<List<FillingOperation>> getAllOperations() async {
    final db = await _dbHelper.database;
    final result = await db.query('filling_operations', where: 'is_deleted = 0', orderBy: 'operation_date DESC');
    return result.map((e) => FillingOperation.fromMap(e)).toList();
  }

  Future<FillingOperation?> getOperationById(int id) async {
    final db = await _dbHelper.database;
    final result = await db.query('filling_operations', where: 'id = ? AND is_deleted = 0', whereArgs: [id]);
    if (result.isNotEmpty) return FillingOperation.fromMap(result.first);
    return null;
  }

  Future<void> updateOperation(FillingOperation operation) async {
    final db = await _dbHelper.database;
    await db.update('filling_operations', operation.toMap(), where: 'id = ?', whereArgs: [operation.id]);
  }

  Future<void> deleteOperation(int id) async {
    final db = await _dbHelper.database;
    await db.update('filling_operations', {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
  }
}
EOF

# ---------- 24. lib/services/sale_service.dart ----------
cat > lib/services/sale_service.dart << 'EOF'
import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../models/sale.dart';

class SaleService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<int> addSale(Sale sale) async {
    final db = await _dbHelper.database;
    return await db.insert('sales', sale.toMap());
  }

  Future<List<Sale>> getAllSales() async {
    final db = await _dbHelper.database;
    final result = await db.query('sales', where: 'is_deleted = 0', orderBy: 'sale_date DESC');
    return result.map((e) => Sale.fromMap(e)).toList();
  }

  Future<Sale?> getSaleById(int id) async {
    final db = await _dbHelper.database;
    final result = await db.query('sales', where: 'id = ? AND is_deleted = 0', whereArgs: [id]);
    if (result.isNotEmpty) return Sale.fromMap(result.first);
    return null;
  }

  Future<void> updateSale(Sale sale) async {
    final db = await _dbHelper.database;
    await db.update('sales', sale.toMap(), where: 'id = ?', whereArgs: [sale.id]);
  }

  Future<void> deleteSale(int id) async {
    final db = await _dbHelper.database;
    await db.update('sales', {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
  }
}
EOF

# ---------- 25. lib/services/payment_service.dart ----------
cat > lib/services/payment_service.dart << 'EOF'
import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../models/payment.dart';

class PaymentService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<int> addPayment(Payment payment) async {
    final db = await _dbHelper.database;
    return await db.insert('payments', payment.toMap());
  }

  Future<List<Payment>> getAllPayments() async {
    final db = await _dbHelper.database;
    final result = await db.query('payments', where: 'is_deleted = 0', orderBy: 'payment_date DESC');
    return result.map((e) => Payment.fromMap(e)).toList();
  }

  Future<List<Payment>> getPaymentsForClient(int clientId) async {
    final db = await _dbHelper.database;
    final result = await db.query('payments',
        where: 'payment_type = ? AND reference_id = ? AND is_deleted = 0',
        whereArgs: ['client_payment', clientId],
        orderBy: 'payment_date ASC');
    return result.map((e) => Payment.fromMap(e)).toList();
  }

  Future<List<Payment>> getPaymentsForSupplier(int supplierId) async {
    final db = await _dbHelper.database;
    final result = await db.query('payments',
        where: 'payment_type = ? AND reference_id = ? AND is_deleted = 0',
        whereArgs: ['supplier_payment', supplierId],
        orderBy: 'payment_date ASC');
    return result.map((e) => Payment.fromMap(e)).toList();
  }
}
EOF

# ---------- 26. lib/services/expense_service.dart ----------
cat > lib/services/expense_service.dart << 'EOF'
import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../models/expense.dart';

class ExpenseService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<int> addExpense(Expense expense) async {
    final db = await _dbHelper.database;
    return await db.insert('expenses', expense.toMap());
  }

  Future<List<Expense>> getAllExpenses() async {
    final db = await _dbHelper.database;
    final result = await db.query('expenses', where: 'is_deleted = 0', orderBy: 'expense_date DESC');
    return result.map((e) => Expense.fromMap(e)).toList();
  }
}
EOF

# ---------- 27. lib/services/salary_service.dart ----------
cat > lib/services/salary_service.dart << 'EOF'
import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../models/salary.dart';

class SalaryService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<int> addSalary(Salary salary) async {
    final db = await _dbHelper.database;
    return await db.insert('salaries', salary.toMap());
  }

  Future<List<Salary>> getAllSalaries() async {
    final db = await _dbHelper.database;
    final result = await db.query('salaries', where: 'is_deleted = 0', orderBy: 'month DESC');
    return result.map((e) => Salary.fromMap(e)).toList();
  }
}
EOF

# ---------- 28. lib/main.dart ----------
cat > lib/main.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_constants.dart';
import 'core/network/connectivity_service.dart';
import 'core/network/sync_service.dart';
import 'core/auth/user_provider.dart';
import 'screens/login/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ConnectivityService>(create: (_) => ConnectivityService()),
        Provider<SyncService>(create: (_) => SyncService()),
        ChangeNotifierProvider<UserProvider>(create: (_) => UserProvider()),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          fontFamily: 'Cairo',
        ),
        home: const LoginScreen(),
      ),
    );
  }
}
EOF

# ---------- 29. lib/screens/login/login_screen.dart ----------
cat > lib/screens/login/login_screen.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_service.dart';
import '../../core/auth/user_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../models/user.dart';
import '../dashboard/dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.water_drop, size: 60, color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AppConstants.companyName,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                  const SizedBox(height: 8),
                  const Text('نظام إدارة صهاريج المياه', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 40),
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'اسم المستخدم',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.person),
                    ),
                    validator: (v) => v!.isEmpty ? 'أدخل اسم المستخدم' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.lock),
                    ),
                    validator: (v) => v!.isEmpty ? 'أدخل كلمة المرور' : null,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('تسجيل الدخول', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final user = await _authService.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );
      setState(() => _isLoading = false);
      if (user != null) {
        context.read<UserProvider>().setUser(user);
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const DashboardScreen()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('بيانات الدخول غير صحيحة')));
      }
    }
  }
}
EOF

# ---------- 30. lib/screens/dashboard/dashboard_screen.dart ----------
cat > lib/screens/dashboard/dashboard_screen.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/user_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/permissions.dart';
import '../../core/auth/permission_service.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().currentUser;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppConstants.companyName),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<UserProvider>().logout();
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        children: [
          if (PermissionService.hasPermission(user, PermissionKeys.clientsView))
            _buildCard(context, 'العملاء', Icons.people, '/clients'),
          if (PermissionService.hasPermission(user, PermissionKeys.suppliersView))
            _buildCard(context, 'الموردون', Icons.local_shipping, '/suppliers'),
          if (PermissionService.hasPermission(user, PermissionKeys.salesView))
            _buildCard(context, 'المبيعات', Icons.shopping_cart, '/sales'),
          _buildCard(context, 'عمليات التعبئة', Icons.local_gas_station, '/filling'),
          _buildCard(context, 'الصهاريج', Icons.local_fire_department, '/tanks'),
          _buildCard(context, 'السائقون', Icons.drive_eta, '/drivers'),
          _buildCard(context, 'المدفوعات', Icons.payments, '/payments'),
          _buildCard(context, 'المصروفات', Icons.money_off, '/expenses'),
          _buildCard(context, 'الرواتب', Icons.attach_money, '/salaries'),
          _buildCard(context, 'التقارير', Icons.report, '/reports'),
          _buildCard(context, 'كشوف الحسابات', Icons.receipt_long, '/statements'),
          if (PermissionService.hasPermission(user, PermissionKeys.usersManage))
            _buildCard(context, 'المستخدمون', Icons.admin_panel_settings, '/users'),
          _buildCard(context, 'سجل العمليات', Icons.history, '/logs'),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, String title, IconData icon, String route) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed(route),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.blue),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
EOF

echo "✅ تم إنشاء جميع الملفات الأساسية بنجاح!"
echo "الخطوة التالية: أضف الخط Cairo في pubspec.yaml ثم شغّل flutter pub get"
