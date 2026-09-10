import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
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
        recovery_code_hash TEXT,
        full_name TEXT NOT NULL,
        role TEXT NOT NULL,
        driver_id INTEGER,
        permissions TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0,
        sync_id TEXT UNIQUE NOT NULL,
        firebase_uid TEXT,
        firebase_email TEXT,
        must_change_password INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE clients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sync_id TEXT UNIQUE NOT NULL,
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
        sync_id TEXT UNIQUE NOT NULL,
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
        sync_id TEXT UNIQUE NOT NULL,
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
        sync_id TEXT UNIQUE NOT NULL,
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
        sync_id TEXT UNIQUE NOT NULL,
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
        sync_id TEXT UNIQUE NOT NULL,
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
        sync_id TEXT UNIQUE NOT NULL,
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
        sync_id TEXT UNIQUE NOT NULL,
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
        sync_id TEXT UNIQUE NOT NULL,
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

  Future<void> closeDatabase() async {
    final db = _database;
    _database = null;
    if (db != null && db.isOpen) {
      await db.close();
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 14) {
      final clientColumns = await db.rawQuery(
        'PRAGMA table_info(clients)',
      );
      final hasClientPhone = clientColumns.any(
        (column) => column['name'] == 'phone',
      );
      if (!hasClientPhone) {
        await db.execute(
          'ALTER TABLE clients ADD COLUMN phone TEXT',
        );
      }

      final supplierColumns = await db.rawQuery(
        'PRAGMA table_info(suppliers)',
      );
      final hasSupplierPhone = supplierColumns.any(
        (column) => column['name'] == 'phone',
      );
      if (!hasSupplierPhone) {
        await db.execute(
          'ALTER TABLE suppliers ADD COLUMN phone TEXT',
        );
      }
    }

    if (oldVersion < 11) {
      final userColumns = await db.rawQuery(
        'PRAGMA table_info(users)',
      );
      final hasUserSyncId = userColumns.any(
        (column) => column['name'] == 'sync_id',
      );

      if (!hasUserSyncId) {
        await db.execute(
          'ALTER TABLE users ADD COLUMN sync_id TEXT',
        );

        final userRows = await db.query(
          'users',
          columns: ['id'],
          where: 'sync_id IS NULL',
        );

        const uuid = Uuid();
        for (final row in userRows) {
          await db.update(
            'users',
            {'sync_id': uuid.v4()},
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        }
      }
    }

    if (oldVersion < 13) {
      final userColumns = await db.rawQuery(
        'PRAGMA table_info(users)',
      );
      final hasMustChangePassword = userColumns.any(
        (column) => column['name'] == 'must_change_password',
      );

      if (!hasMustChangePassword) {
        await db.execute(
          'ALTER TABLE users ADD COLUMN must_change_password INTEGER DEFAULT 0',
        );
      }
    }

    if (oldVersion < 12) {
      final userColumns = await db.rawQuery(
        'PRAGMA table_info(users)',
      );
      final hasFirebaseUid = userColumns.any(
        (column) => column['name'] == 'firebase_uid',
      );
      final hasFirebaseEmail = userColumns.any(
        (column) => column['name'] == 'firebase_email',
      );

      if (!hasFirebaseUid) {
        await db.execute(
          'ALTER TABLE users ADD COLUMN firebase_uid TEXT',
        );
      }

      if (!hasFirebaseEmail) {
        await db.execute(
          'ALTER TABLE users ADD COLUMN firebase_email TEXT',
        );
      }
    }

    if (oldVersion < 2) {
      final columns = await db.rawQuery('PRAGMA table_info(users)');
      final hasDriverId = columns.any(
        (column) => column['name'] == 'driver_id',
      );

      if (!hasDriverId) {
        await db.execute(
          'ALTER TABLE users ADD COLUMN driver_id INTEGER',
        );
      }
    }

    if (oldVersion < 3) {
      final columns = await db.rawQuery('PRAGMA table_info(users)');
      final hasRecoveryCodeHash = columns.any(
        (column) => column['name'] == 'recovery_code_hash',
      );

      if (!hasRecoveryCodeHash) {
        await db.execute(
          'ALTER TABLE users ADD COLUMN recovery_code_hash TEXT',
        );
      }
    }

    if (oldVersion < 10) {
      final salaryColumns = await db.rawQuery(
        'PRAGMA table_info(salaries)',
      );
      final hasSalarySyncId = salaryColumns.any(
        (column) => column['name'] == 'sync_id',
      );

      if (!hasSalarySyncId) {
        await db.execute(
          'ALTER TABLE salaries ADD COLUMN sync_id TEXT',
        );

        final salaryRows = await db.query(
          'salaries',
          columns: ['id'],
          where: 'sync_id IS NULL',
        );

        const uuid = Uuid();
        for (final row in salaryRows) {
          await db.update(
            'salaries',
            {'sync_id': uuid.v4()},
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        }
      }
    }

    if (oldVersion < 9) {
      final expenseColumns = await db.rawQuery(
        'PRAGMA table_info(expenses)',
      );
      final hasExpenseSyncId = expenseColumns.any(
        (column) => column['name'] == 'sync_id',
      );

      if (!hasExpenseSyncId) {
        await db.execute(
          'ALTER TABLE expenses ADD COLUMN sync_id TEXT',
        );

        final expenseRows = await db.query(
          'expenses',
          columns: ['id'],
          where: 'sync_id IS NULL',
        );

        const uuid = Uuid();
        for (final row in expenseRows) {
          await db.update(
            'expenses',
            {'sync_id': uuid.v4()},
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        }
      }
    }

    if (oldVersion < 8) {
      final paymentColumns = await db.rawQuery(
        'PRAGMA table_info(payments)',
      );
      final hasPaymentSyncId = paymentColumns.any(
        (column) => column['name'] == 'sync_id',
      );

      if (!hasPaymentSyncId) {
        await db.execute(
          'ALTER TABLE payments ADD COLUMN sync_id TEXT',
        );

        final paymentRows = await db.query(
          'payments',
          columns: ['id'],
          where: 'sync_id IS NULL',
        );

        const uuid = Uuid();
        for (final row in paymentRows) {
          await db.update(
            'payments',
            {'sync_id': uuid.v4()},
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        }
      }
    }

    if (oldVersion < 7) {
      final saleColumns = await db.rawQuery(
        'PRAGMA table_info(sales)',
      );
      final hasSaleSyncId = saleColumns.any(
        (column) => column['name'] == 'sync_id',
      );

      if (!hasSaleSyncId) {
        await db.execute(
          'ALTER TABLE sales ADD COLUMN sync_id TEXT',
        );

        final saleRows = await db.query(
          'sales',
          columns: ['id'],
          where: 'sync_id IS NULL',
        );

        const uuid = Uuid();
        for (final row in saleRows) {
          await db.update(
            'sales',
            {'sync_id': uuid.v4()},
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        }
      }
    }

    if (oldVersion < 6) {
      final operationColumns = await db.rawQuery(
        'PRAGMA table_info(filling_operations)',
      );
      final hasOperationSyncId = operationColumns.any(
        (column) => column['name'] == 'sync_id',
      );

      if (!hasOperationSyncId) {
        await db.execute(
          'ALTER TABLE filling_operations ADD COLUMN sync_id TEXT',
        );

        final operationRows = await db.query(
          'filling_operations',
          columns: ['id'],
          where: 'sync_id IS NULL',
        );

        const uuid = Uuid();
        for (final row in operationRows) {
          await db.update(
            'filling_operations',
            {'sync_id': uuid.v4()},
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        }
      }
    }

    if (oldVersion < 5) {
      final tankColumns = await db.rawQuery(
        'PRAGMA table_info(tanks)',
      );
      final hasTankSyncId = tankColumns.any(
        (column) => column['name'] == 'sync_id',
      );

      if (!hasTankSyncId) {
        await db.execute(
          'ALTER TABLE tanks ADD COLUMN sync_id TEXT',
        );

        final tankRows = await db.query(
          'tanks',
          columns: ['id'],
          where: 'sync_id IS NULL',
        );

        const uuid = Uuid();
        for (final row in tankRows) {
          await db.update(
            'tanks',
            {'sync_id': uuid.v4()},
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        }
      }
    }

    if (oldVersion < 4) {
      final columns = await db.rawQuery('PRAGMA table_info(clients)');
      final hasSyncId = columns.any(
        (column) => column['name'] == 'sync_id',
      );

      if (!hasSyncId) {
        await db.execute(
          'ALTER TABLE clients ADD COLUMN sync_id TEXT',
        );

        final rows = await db.query(
          'clients',
          columns: ['id'],
          where: 'sync_id IS NULL',
        );

        const uuid = Uuid();
        for (final row in rows) {
          await db.update(
            'clients',
            {'sync_id': uuid.v4()},
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        }
      }

      final driverColumns = await db.rawQuery(
        'PRAGMA table_info(drivers)',
      );
      final hasDriverSyncId = driverColumns.any(
        (column) => column['name'] == 'sync_id',
      );

      if (!hasDriverSyncId) {
        await db.execute(
          'ALTER TABLE drivers ADD COLUMN sync_id TEXT',
        );

        final driverRows = await db.query(
          'drivers',
          columns: ['id'],
          where: 'sync_id IS NULL',
        );

        const uuid = Uuid();
        for (final row in driverRows) {
          await db.update(
            'drivers',
            {'sync_id': uuid.v4()},
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        }
      }

      final supplierColumns = await db.rawQuery(
        'PRAGMA table_info(suppliers)',
      );
      final hasSupplierSyncId = supplierColumns.any(
        (column) => column['name'] == 'sync_id',
      );

      if (!hasSupplierSyncId) {
        await db.execute(
          'ALTER TABLE suppliers ADD COLUMN sync_id TEXT',
        );

        final supplierRows = await db.query(
          'suppliers',
          columns: ['id'],
          where: 'sync_id IS NULL',
        );

        const uuid = Uuid();
        for (final row in supplierRows) {
          await db.update(
            'suppliers',
            {'sync_id': uuid.v4()},
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        }
      }
    }
  }
}
