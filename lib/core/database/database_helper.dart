import 'package:flutter/foundation.dart';
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
      onOpen: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        debugPrint('SQLite foreign_keys enabled');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        password_salt TEXT,
        password_hash_version INTEGER DEFAULT 1,
        recovery_code_hash TEXT,
        recovery_code_salt TEXT,
        recovery_code_hash_version INTEGER DEFAULT 1,
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
        client_id INTEGER,
        tank_id INTEGER,
        driver_id INTEGER,
        supplier_id INTEGER NOT NULL,
        units INTEGER NOT NULL,
        sale_price REAL NOT NULL,
        total_amount REAL NOT NULL,
        cost_amount REAL NOT NULL,
        profit_amount REAL NOT NULL,
        sale_date TEXT NOT NULL,
        payment_status TEXT NOT NULL,
        client_payment_status TEXT,
        supplier_payment_status TEXT,
        created_by_name TEXT,
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
        payment_method TEXT,
        reference_number TEXT,
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
      CREATE TABLE account_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_type TEXT NOT NULL,
        reference_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        transaction_type TEXT NOT NULL,
        transaction_date TEXT NOT NULL,
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
      CREATE INDEX idx_account_transactions_reference
      ON account_transactions (
        account_type,
        reference_id,
        transaction_date
      )
    ''');
    await db.execute('''
      CREATE TABLE purchase_invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_number TEXT UNIQUE NOT NULL,
        supplier_id INTEGER NOT NULL,
        purchase_date TEXT NOT NULL,
        total_amount REAL NOT NULL,
        payment_status TEXT NOT NULL,
        notes TEXT,
        created_by INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0,
        sync_id TEXT UNIQUE NOT NULL,
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id),
        FOREIGN KEY (created_by) REFERENCES users (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE purchase_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_invoice_id INTEGER NOT NULL,
        item_type TEXT NOT NULL DEFAULT 'tank',
        units INTEGER NOT NULL,
        purchase_price REAL NOT NULL,
        total_amount REAL NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0,
        sync_id TEXT UNIQUE NOT NULL,
        FOREIGN KEY (purchase_invoice_id) REFERENCES purchase_invoices (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE inventory_layers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_item_id INTEGER NOT NULL,
        item_type TEXT NOT NULL DEFAULT 'tank',
        original_units INTEGER NOT NULL,
        remaining_units INTEGER NOT NULL,
        unit_cost REAL NOT NULL,
        layer_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0,
        sync_id TEXT UNIQUE NOT NULL,
        FOREIGN KEY (purchase_item_id) REFERENCES purchase_items (id)
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_purchase_invoices_supplier
      ON purchase_invoices (supplier_id, purchase_date)
    ''');

    await db.execute('''
      CREATE INDEX idx_purchase_items_invoice
      ON purchase_items (purchase_invoice_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_inventory_layers_fifo
      ON inventory_layers (item_type, layer_date, id)
    ''');

    await db.execute('''
      CREATE TABLE sale_inventory_allocations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        inventory_layer_id INTEGER NOT NULL,
        purchase_item_id INTEGER NOT NULL,
        supplier_id INTEGER NOT NULL,
        units INTEGER NOT NULL,
        unit_cost REAL NOT NULL,
        cost_amount REAL NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0,
        sync_id TEXT UNIQUE NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales (id),
        FOREIGN KEY (inventory_layer_id) REFERENCES inventory_layers (id),
        FOREIGN KEY (purchase_item_id) REFERENCES purchase_items (id),
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id)
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_sale_inventory_allocations_sale
      ON sale_inventory_allocations (sale_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_sale_inventory_allocations_supplier
      ON sale_inventory_allocations (supplier_id, created_at)
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
        sync_id TEXT UNIQUE NOT NULL,
        user_id INTEGER NOT NULL,
        user_sync_id TEXT,
        action TEXT NOT NULL,
        table_name TEXT NOT NULL,
        record_id INTEGER NOT NULL,
        record_sync_id TEXT,
        details TEXT,
        timestamp TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    // فحص نهائي بعد الإنشاء: يضمن وجود أي جدول أساسي مفقود حتى لو
    // تغيّر ترتيب الإنشاء أو كان هناك اختلاف في نسخة قاعدة البيانات.
    await _ensureCoreTables(db);
    await _ensureFinancialSchema(db);
  }

  /// تصفير جميع البيانات التشغيلية محليًا بطريقة حذف منطقي.
  /// يتم الاحتفاظ بالمستخدمين والصلاحيات، بينما تُعلَّم جميع
  /// البيانات التشغيلية كمحذوفة وتُعاد مزامنتها مع Firestore.
  Future<void> resetTransactionalData() async {
    final db = await database;

    await db.transaction((txn) async {
      const tables = [
        'sale_inventory_allocations',
        'sales',
        'inventory_layers',
        'purchase_items',
        'purchase_invoices',
        'payments',
        'account_transactions',
        'expenses',
        'salaries',
        'filling_operations',
        'operation_logs',
        'clients',
        'suppliers',
        'drivers',
        'tanks',
      ];

      final now = DateTime.now().toIso8601String();

      for (final table in tables) {
        await txn.update(
          table,
          {
            'is_deleted': 1,
            'is_synced': 0,
            'updated_at': now,
          },
        );
      }
    });
  }

  Future<void> closeDatabase() async {
    final db = _database;
    _database = null;
    if (db != null && db.isOpen) {
      await db.close();
    }
  }

  /// يفحص كل الجداول الأساسية وينشئها إن كانت مفقودة.
  /// يعمل بغض النظر عن إصدار قاعدة البيانات الحالي.
  Future<void> _ensureCoreTables(Database db) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type=\"table\"",
    );
    final existing =
        rows.map((row) => row["name"]?.toString()).whereType<String>().toSet();

    const required = <String>[
      "users",
      "clients",
      "suppliers",
      "drivers",
      "tanks",
      "filling_operations",
      "sales",
      "payments",
      "account_transactions",
      "purchase_invoices",
      "purchase_items",
      "inventory_layers",
      "sale_inventory_allocations",
      "expenses",
      "salaries",
      "operation_logs",
    ];

    final missing = required.where((name) => !existing.contains(name)).toList();

    if (missing.isNotEmpty) {
      throw StateError(
        'قاعدة البيانات ناقصة جداول أساسية: ${missing.join(', ')}',
      );
    }

    debugPrint("✅ All core tables exist");
  }

  /// ينفذ SQL بشكل آمن ويتجاهل أخطاء "العمود موجود مسبقًا".
  /// مفيد لعمليات ALTER TABLE على قواعد بيانات قديمة تحتوي الأعمدة بالفعل.
  Future<void> _safeExec(Database db, String sql) async {
    try {
      await db.execute(sql);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('duplicate column') ||
          msg.contains('already exists') ||
          msg.contains('duplicate column name')) {
        debugPrint('⏭️ Skipped (already exists): $sql');
        return;
      }
      debugPrint('❌ _safeExec error: $e');
      rethrow;
    }
  }

  Future<void> _ensureFinancialSchema(DatabaseExecutor db) async {
    await _addColumnIfMissing(
      db,
      'payments',
      'purchase_invoice_id',
      'INTEGER',
    );

    await _addColumnIfMissing(
      db,
      'payments',
      'payment_key',
      'TEXT',
    );

    await _addColumnIfMissing(
      db,
      'account_transactions',
      'purchase_invoice_id',
      'INTEGER',
    );

    await db.execute('''
      UPDATE payments
      SET payment_key = 'legacy_payment_' || id
      WHERE payment_key IS NULL OR TRIM(payment_key) = ''
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS ux_payments_payment_key
      ON payments(payment_key)
      WHERE is_deleted = 0
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_payments_purchase_invoice
      ON payments(purchase_invoice_id, payment_date, id)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_payments_supplier_reference
      ON payments(payment_type, reference_id, is_deleted, payment_date, id)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_account_transactions_purchase_invoice
      ON account_transactions(purchase_invoice_id, is_deleted)
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS ux_account_purchase_debt_invoice
      ON account_transactions(purchase_invoice_id)
      WHERE purchase_invoice_id IS NOT NULL
        AND is_deleted = 0
        AND account_type = 'supplier'
        AND transaction_type = 'debt'
    ''');

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_payment_invoice_guard_insert
      BEFORE INSERT ON payments
      WHEN NEW.purchase_invoice_id IS NOT NULL AND NEW.is_deleted = 0
      BEGIN
        SELECT CASE
          WHEN NEW.payment_type <> 'supplier_payment'
            THEN RAISE(ABORT, 'دفعة الفاتورة يجب أن تكون دفعة مورد')
          WHEN NEW.amount <= 0
            THEN RAISE(ABORT, 'مبلغ الدفعة يجب أن يكون أكبر من صفر')
          WHEN NOT EXISTS (
            SELECT 1
            FROM purchase_invoices pi
            WHERE pi.id = NEW.purchase_invoice_id
              AND pi.is_deleted = 0
              AND pi.supplier_id = NEW.reference_id
          )
            THEN RAISE(ABORT, 'الفاتورة لا تنتمي إلى المورد المحدد')
          WHEN (
            SELECT COALESCE(SUM(p.amount), 0)
            FROM payments p
            WHERE p.purchase_invoice_id = NEW.purchase_invoice_id
              AND p.is_deleted = 0
          ) + NEW.amount >
          (
            SELECT pi.total_amount
            FROM purchase_invoices pi
            WHERE pi.id = NEW.purchase_invoice_id
          ) + 0.000001
            THEN RAISE(ABORT, 'إجمالي دفعات الفاتورة يتجاوز قيمة الفاتورة')
        END;
      END
    ''');

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_payment_invoice_guard_update
      BEFORE UPDATE OF purchase_invoice_id, reference_id,
        payment_type, amount, is_deleted ON payments
      WHEN NEW.purchase_invoice_id IS NOT NULL AND NEW.is_deleted = 0
      BEGIN
        SELECT CASE
          WHEN NEW.payment_type <> 'supplier_payment'
            THEN RAISE(ABORT, 'دفعة الفاتورة يجب أن تكون دفعة مورد')
          WHEN NEW.amount <= 0
            THEN RAISE(ABORT, 'مبلغ الدفعة يجب أن يكون أكبر من صفر')
          WHEN NOT EXISTS (
            SELECT 1
            FROM purchase_invoices pi
            WHERE pi.id = NEW.purchase_invoice_id
              AND pi.is_deleted = 0
              AND pi.supplier_id = NEW.reference_id
          )
            THEN RAISE(ABORT, 'الفاتورة لا تنتمي إلى المورد المحدد')
          WHEN (
            SELECT COALESCE(SUM(p.amount), 0)
            FROM payments p
            WHERE p.purchase_invoice_id = NEW.purchase_invoice_id
              AND p.is_deleted = 0
              AND p.id <> NEW.id
          ) + NEW.amount >
          (
            SELECT pi.total_amount
            FROM purchase_invoices pi
            WHERE pi.id = NEW.purchase_invoice_id
          ) + 0.000001
            THEN RAISE(ABORT, 'إجمالي دفعات الفاتورة يتجاوز قيمة الفاتورة')
        END;
      END
    ''');
  }

  Future<void> _addColumnIfMissing(
    DatabaseExecutor db,
    String table,
    String column,
    String definition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    if (!columns.any((row) => row['name'] == column)) {
      await db.execute(
        'ALTER TABLE $table ADD COLUMN $column $definition',
      );
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // ✅ إصلاح جذري: فحص كل الجداول الأساسية وإنشاؤها إن كانت مفقودة.
    // يُنفَّذ دائمًا (بغض النظر عن الإصدار) لضمان سلامة قاعدة البيانات.
    // ✅ إصلاح: إنشاء expenses إن كانت مفقودة
    if (oldVersion < 27) {
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='expenses'",
      );
      if (tables.isEmpty) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS expenses (
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
      }
    }

    if (oldVersion < 27) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS expenses (
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
    }

    if (oldVersion < 27) {
      final fillingColumns = await db.rawQuery(
        'PRAGMA table_info(filling_operations)',
      );

      final tankColumn = fillingColumns.firstWhere(
        (column) => column['name'] == 'tank_id',
        orElse: () => <String, Object?>{},
      );

      final tankIsNotNull = tankColumn['notnull'] == 1;

      if (tankIsNotNull) {
        await _safeExec(db,
            'ALTER TABLE filling_operations RENAME TO filling_operations_old');

        await db.execute('''
          CREATE TABLE filling_operations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            operation_number TEXT UNIQUE,
            tank_id INTEGER,
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
          INSERT INTO filling_operations (
            id,
            operation_number,
            tank_id,
            supplier_id,
            units,
            purchase_price,
            operation_date,
            employee_id,
            notes,
            created_by,
            created_at,
            updated_at,
            is_deleted,
            is_synced,
            sync_id
          )
          SELECT
            id,
            operation_number,
            tank_id,
            supplier_id,
            units,
            purchase_price,
            operation_date,
            employee_id,
            notes,
            created_by,
            created_at,
            updated_at,
            is_deleted,
            is_synced,
            sync_id
          FROM filling_operations_old
        ''');

        await db.execute('DROP TABLE filling_operations_old');
      }
    }

    if (oldVersion < 27) {
      final salesColumns = await db.rawQuery(
        'PRAGMA table_info(sales)',
      );

      final hasClientPaymentStatus = salesColumns.any(
        (column) => column['name'] == 'client_payment_status',
      );

      final hasSupplierPaymentStatus = salesColumns.any(
        (column) => column['name'] == 'supplier_payment_status',
      );

      final hasCreatedByName = salesColumns.any(
        (column) => column['name'] == 'created_by_name',
      );

      if (!hasClientPaymentStatus) {
        await _safeExec(
            db, 'ALTER TABLE sales ADD COLUMN client_payment_status TEXT');
      }

      if (!hasSupplierPaymentStatus) {
        await _safeExec(
            db, 'ALTER TABLE sales ADD COLUMN supplier_payment_status TEXT');
      }

      if (!hasCreatedByName) {
        await _safeExec(
            db, 'ALTER TABLE sales ADD COLUMN created_by_name TEXT');
      }
    }

    if (oldVersion < 27) {
      final salesColumns = await db.rawQuery(
        'PRAGMA table_info(sales)',
      );

      final clientColumn = salesColumns.firstWhere(
        (column) => column['name'] == 'client_id',
        orElse: () => <String, Object?>{},
      );

      final tankColumn = salesColumns.firstWhere(
        (column) => column['name'] == 'tank_id',
        orElse: () => <String, Object?>{},
      );

      final clientIsNotNull = clientColumn['notnull'] == 1;
      final tankIsNotNull = tankColumn['notnull'] == 1;

      if (clientIsNotNull || tankIsNotNull) {
        await _safeExec(db, 'ALTER TABLE sales RENAME TO sales_old');

        await db.execute('''
          CREATE TABLE sales (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sale_number TEXT UNIQUE,
            client_id INTEGER,
            tank_id INTEGER,
            driver_id INTEGER,
            supplier_id INTEGER NOT NULL,
            units INTEGER NOT NULL,
            sale_price REAL NOT NULL,
            total_amount REAL NOT NULL,
            cost_amount REAL NOT NULL,
            profit_amount REAL NOT NULL,
            sale_date TEXT NOT NULL,
            payment_status TEXT NOT NULL,
            client_payment_status TEXT,
            supplier_payment_status TEXT,
            created_by_name TEXT,
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
          INSERT INTO sales (
            id, sale_number, client_id, tank_id, driver_id,
            supplier_id, units, sale_price, total_amount,
            cost_amount, profit_amount, sale_date, payment_status,
            client_payment_status, supplier_payment_status, created_by_name,
            notes, created_by, created_at, updated_at,
            is_deleted, is_synced, sync_id
          )
          SELECT
            id, sale_number, client_id, tank_id, driver_id,
            supplier_id, units, sale_price, total_amount,
            cost_amount, profit_amount, sale_date, payment_status,
            client_payment_status, supplier_payment_status, created_by_name,
            notes, created_by, created_at, updated_at,
            is_deleted, is_synced, sync_id
          FROM sales_old
        ''');

        await db.execute('DROP TABLE sales_old');
      }
    }

    if (oldVersion < 27) {
      final clientColumns = await db.rawQuery(
        'PRAGMA table_info(clients)',
      );
      final hasClientPhone = clientColumns.any(
        (column) => column['name'] == 'phone',
      );
      if (!hasClientPhone) {
        await _safeExec(db, 'ALTER TABLE clients ADD COLUMN phone TEXT');
      }

      final supplierColumns = await db.rawQuery(
        'PRAGMA table_info(suppliers)',
      );
      final hasSupplierPhone = supplierColumns.any(
        (column) => column['name'] == 'phone',
      );
      if (!hasSupplierPhone) {
        await _safeExec(db, 'ALTER TABLE suppliers ADD COLUMN phone TEXT');
      }
    }

    if (oldVersion < 27) {
      final userColumns = await db.rawQuery(
        'PRAGMA table_info(users)',
      );
      final hasUserSyncId = userColumns.any(
        (column) => column['name'] == 'sync_id',
      );

      if (!hasUserSyncId) {
        await _safeExec(db, 'ALTER TABLE users ADD COLUMN sync_id TEXT');

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

    if (oldVersion < 27) {
      final userColumns = await db.rawQuery(
        'PRAGMA table_info(users)',
      );
      final hasMustChangePassword = userColumns.any(
        (column) => column['name'] == 'must_change_password',
      );

      if (!hasMustChangePassword) {
        await _safeExec(db,
            'ALTER TABLE users ADD COLUMN must_change_password INTEGER DEFAULT 0');
      }
    }

    if (oldVersion < 27) {
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
        await _safeExec(db, 'ALTER TABLE users ADD COLUMN firebase_uid TEXT');
      }

      if (!hasFirebaseEmail) {
        await _safeExec(db, 'ALTER TABLE users ADD COLUMN firebase_email TEXT');
      }
    }

    if (oldVersion < 27) {
      final columns = await db.rawQuery('PRAGMA table_info(users)');
      final hasDriverId = columns.any(
        (column) => column['name'] == 'driver_id',
      );

      if (!hasDriverId) {
        await _safeExec(db, 'ALTER TABLE users ADD COLUMN driver_id INTEGER');
      }
    }

    if (oldVersion < 27) {
      final columns = await db.rawQuery('PRAGMA table_info(users)');
      final hasRecoveryCodeHash = columns.any(
        (column) => column['name'] == 'recovery_code_hash',
      );

      if (!hasRecoveryCodeHash) {
        await _safeExec(
            db, 'ALTER TABLE users ADD COLUMN recovery_code_hash TEXT');
      }
    }

    if (oldVersion < 27) {
      final salaryColumns = await db.rawQuery(
        'PRAGMA table_info(salaries)',
      );
      final hasSalarySyncId = salaryColumns.any(
        (column) => column['name'] == 'sync_id',
      );

      if (!hasSalarySyncId) {
        await _safeExec(db, 'ALTER TABLE salaries ADD COLUMN sync_id TEXT');

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

    if (oldVersion < 27) {
      final expenseColumns = await db.rawQuery(
        'PRAGMA table_info(expenses)',
      );
      final hasExpenseSyncId = expenseColumns.any(
        (column) => column['name'] == 'sync_id',
      );

      if (!hasExpenseSyncId) {
        await _safeExec(db, 'ALTER TABLE expenses ADD COLUMN sync_id TEXT');

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

    if (oldVersion < 27) {
      final paymentColumns = await db.rawQuery(
        'PRAGMA table_info(payments)',
      );
      final hasPaymentSyncId = paymentColumns.any(
        (column) => column['name'] == 'sync_id',
      );

      if (!hasPaymentSyncId) {
        await _safeExec(db, 'ALTER TABLE payments ADD COLUMN sync_id TEXT');

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

    if (oldVersion < 27) {
      final saleColumns = await db.rawQuery(
        'PRAGMA table_info(sales)',
      );
      final hasSaleSyncId = saleColumns.any(
        (column) => column['name'] == 'sync_id',
      );

      if (!hasSaleSyncId) {
        await _safeExec(db, 'ALTER TABLE sales ADD COLUMN sync_id TEXT');

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

    if (oldVersion < 27) {
      final operationColumns = await db.rawQuery(
        'PRAGMA table_info(filling_operations)',
      );
      final hasOperationSyncId = operationColumns.any(
        (column) => column['name'] == 'sync_id',
      );

      if (!hasOperationSyncId) {
        await _safeExec(
            db, 'ALTER TABLE filling_operations ADD COLUMN sync_id TEXT');

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

    if (oldVersion < 27) {
      final tankColumns = await db.rawQuery(
        'PRAGMA table_info(tanks)',
      );
      final hasTankSyncId = tankColumns.any(
        (column) => column['name'] == 'sync_id',
      );

      if (!hasTankSyncId) {
        await _safeExec(db, 'ALTER TABLE tanks ADD COLUMN sync_id TEXT');

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

    if (oldVersion < 27) {
      final columns = await db.rawQuery('PRAGMA table_info(clients)');
      final hasSyncId = columns.any(
        (column) => column['name'] == 'sync_id',
      );

      if (!hasSyncId) {
        await _safeExec(db, 'ALTER TABLE clients ADD COLUMN sync_id TEXT');

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
        await _safeExec(db, 'ALTER TABLE drivers ADD COLUMN sync_id TEXT');

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
        await _safeExec(db, 'ALTER TABLE suppliers ADD COLUMN sync_id TEXT');

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

    if (oldVersion < 27) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS account_transactions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          account_type TEXT NOT NULL,
          reference_id INTEGER NOT NULL,
          amount REAL NOT NULL,
          transaction_type TEXT NOT NULL,
          transaction_date TEXT NOT NULL,
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
        CREATE INDEX IF NOT EXISTS idx_account_transactions_reference
        ON account_transactions (account_type, reference_id, transaction_date)
      ''');
    }
    if (oldVersion < 27) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS purchase_invoices (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          invoice_number TEXT UNIQUE NOT NULL,
          supplier_id INTEGER NOT NULL,
          purchase_date TEXT NOT NULL,
          total_amount REAL NOT NULL,
          payment_status TEXT NOT NULL,
          notes TEXT,
          created_by INTEGER NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          is_deleted INTEGER DEFAULT 0,
          is_synced INTEGER DEFAULT 0,
          sync_id TEXT UNIQUE NOT NULL,
          FOREIGN KEY (supplier_id) REFERENCES suppliers (id),
          FOREIGN KEY (created_by) REFERENCES users (id)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS purchase_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          purchase_invoice_id INTEGER NOT NULL,
          item_type TEXT NOT NULL DEFAULT 'tank',
          units INTEGER NOT NULL,
          purchase_price REAL NOT NULL,
          total_amount REAL NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          is_deleted INTEGER DEFAULT 0,
          is_synced INTEGER DEFAULT 0,
          sync_id TEXT UNIQUE NOT NULL,
          FOREIGN KEY (purchase_invoice_id) REFERENCES purchase_invoices (id)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS inventory_layers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          purchase_item_id INTEGER NOT NULL,
          item_type TEXT NOT NULL DEFAULT 'tank',
          original_units INTEGER NOT NULL,
          remaining_units INTEGER NOT NULL,
          unit_cost REAL NOT NULL,
          layer_date TEXT NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          is_deleted INTEGER DEFAULT 0,
          is_synced INTEGER DEFAULT 0,
          sync_id TEXT UNIQUE NOT NULL,
          FOREIGN KEY (purchase_item_id) REFERENCES purchase_items (id)
        )
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_purchase_invoices_supplier
        ON purchase_invoices (supplier_id, purchase_date)
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_purchase_items_invoice
        ON purchase_items (purchase_invoice_id)
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_inventory_layers_fifo
        ON inventory_layers (item_type, layer_date, id)
      ''');
    }

    if (oldVersion < 27) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sale_inventory_allocations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sale_id INTEGER NOT NULL,
          inventory_layer_id INTEGER NOT NULL,
          purchase_item_id INTEGER NOT NULL,
          supplier_id INTEGER NOT NULL,
          units INTEGER NOT NULL,
          unit_cost REAL NOT NULL,
          cost_amount REAL NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          is_deleted INTEGER DEFAULT 0,
          is_synced INTEGER DEFAULT 0,
          sync_id TEXT UNIQUE NOT NULL,
          FOREIGN KEY (sale_id) REFERENCES sales (id),
          FOREIGN KEY (inventory_layer_id) REFERENCES inventory_layers (id),
          FOREIGN KEY (purchase_item_id) REFERENCES purchase_items (id),
          FOREIGN KEY (supplier_id) REFERENCES suppliers (id)
        )
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_sale_inventory_allocations_sale
        ON sale_inventory_allocations (sale_id)
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_sale_inventory_allocations_supplier
        ON sale_inventory_allocations (supplier_id, created_at)
      ''');
    }

    if (oldVersion < 27) {
      await _safeExec(
          db, 'ALTER TABLE payments ADD COLUMN payment_method TEXT');
      await _safeExec(
          db, 'ALTER TABLE payments ADD COLUMN reference_number TEXT');
    }

    // الإصدار 28: فحص شامل وإنشاء أي جدول أساسي مفقود.
    // يعمل بعد جميع ترقيات الإصدارات السابقة.
    if (oldVersion < 29) {
      await _ensureCoreTables(db);
    }

    // الإصدار 30: إضافة مفتاح فريد لسندات القبض/الصرف.
    // _safeExec يجعل الترقية آمنة حتى لو كان العمود موجودًا مسبقًا.
    if (oldVersion < 30) {
      await _safeExec(
        db,
        'ALTER TABLE payments ADD COLUMN purchase_invoice_id INTEGER',
      );
      await _safeExec(
        db,
        'ALTER TABLE payments ADD COLUMN payment_key TEXT',
      );
      await _safeExec(
        db,
        'ALTER TABLE payments ADD COLUMN payment_method TEXT',
      );
      await _safeExec(
        db,
        'ALTER TABLE payments ADD COLUMN reference_number TEXT',
      );
    }

    // الإصدار 31: توحيد وإكمال البنية المالية بعد إنشاء جميع الجداول.
    if (oldVersion < 31) {
      await _ensureFinancialSchema(db);
    }

    // الإصدار 32: توحيد بنية operation_logs مع النموذج والخدمات والتصفير.
    if (oldVersion < 32) {
      await db.transaction((txn) async {
        final columns = await txn.rawQuery('PRAGMA table_info(operation_logs)');
        final existingColumns = columns
            .map((row) => row['name']?.toString())
            .whereType<String>()
            .toSet();

        if (existingColumns.isEmpty) {
          await txn.execute('''
            CREATE TABLE operation_logs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              sync_id TEXT UNIQUE NOT NULL,
              user_id INTEGER NOT NULL,
            user_sync_id TEXT,
              action TEXT NOT NULL,
              table_name TEXT NOT NULL,
              record_id INTEGER NOT NULL,
            record_sync_id TEXT,
              details TEXT,
              timestamp TEXT NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              is_deleted INTEGER DEFAULT 0,
              is_synced INTEGER DEFAULT 0,
              FOREIGN KEY (user_id) REFERENCES users (id)
            )
          ''');
          return;
        }

        await txn
            .execute('ALTER TABLE operation_logs RENAME TO operation_logs_old');

        await txn.execute('''
          CREATE TABLE operation_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sync_id TEXT UNIQUE NOT NULL,
            user_id INTEGER NOT NULL,
            user_sync_id TEXT,
            action TEXT NOT NULL,
            table_name TEXT NOT NULL,
            record_id INTEGER NOT NULL,
            record_sync_id TEXT,
            details TEXT,
            timestamp TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            is_deleted INTEGER DEFAULT 0,
            is_synced INTEGER DEFAULT 0,
            FOREIGN KEY (user_id) REFERENCES users (id)
          )
        ''');

        final oldColumns =
            await txn.rawQuery('PRAGMA table_info(operation_logs_old)');
        final oldNames = oldColumns
            .map((row) => row['name']?.toString())
            .whereType<String>()
            .toSet();

        final now = DateTime.now().toIso8601String();

        final actionExpr = oldNames.contains('action')
            ? 'action'
            : oldNames.contains('operation_type')
                ? 'operation_type'
                : "''";

        final timestampExpr = oldNames.contains('timestamp')
            ? 'timestamp'
            : oldNames.contains('created_at')
                ? 'created_at'
                : "'$now'";

        final detailsExpr = oldNames.contains('details') ? 'details' : 'NULL';

        // operation_logs.user_id يرتبط بـ users عبر Foreign Key.
        // عند ترقية قاعدة قديمة قد توجد سجلات تشير إلى مستخدم غير موجود.
        // نستخدم مستخدمًا صالحًا كمرجع بديل، أو نحذف سجلات السجل القديمة
        // إذا لم يوجد أي مستخدم بعد، بدل فشل ترقية قاعدة البيانات بالكامل.
        final users = await txn.query(
          'users',
          columns: ['id'],
          where: 'is_deleted = 0',
          orderBy: 'id ASC',
          limit: 1,
        );

        final fallbackUserId =
            users.isNotEmpty ? (users.first['id'] as num).toInt() : null;

        if (fallbackUserId == null) {
          await txn.execute('DELETE FROM operation_logs_old');
        }

        final userIdExpr = fallbackUserId != null
            ? (oldNames.contains('user_id')
                ? 'CASE WHEN EXISTS (SELECT 1 FROM users WHERE id = user_id AND is_deleted = 0) THEN user_id ELSE $fallbackUserId END'
                : '$fallbackUserId')
            : 'NULL';

        final tableNameExpr =
            oldNames.contains('table_name') ? 'table_name' : "''";

        final recordIdExpr = oldNames.contains('record_id') ? 'record_id' : '0';

        final isDeletedExpr =
            oldNames.contains('is_deleted') ? 'COALESCE(is_deleted, 0)' : '0';

        final isSyncedExpr =
            oldNames.contains('is_synced') ? 'COALESCE(is_synced, 0)' : '0';

        final syncIdExpr = oldNames.contains('sync_id')
            ? "CASE WHEN sync_id IS NULL OR TRIM(sync_id) = '' THEN 'legacy_operation_log_' || id ELSE sync_id END"
            : "'legacy_operation_log_' || id";

        await txn.execute('''
          INSERT INTO operation_logs (
            id,
            sync_id,
            user_id,
            action,
            table_name,
            record_id,
            details,
            timestamp,
            created_at,
            updated_at,
            is_deleted,
            is_synced
          )
          SELECT
            id,
            $syncIdExpr,
            $userIdExpr,
            $actionExpr,
            $tableNameExpr,
            $recordIdExpr,
            $detailsExpr,
            $timestampExpr,
            $timestampExpr,
            $timestampExpr,
            $isDeletedExpr,
            $isSyncedExpr
          FROM operation_logs_old
        ''');

        await txn.execute('DROP TABLE operation_logs_old');
      });
    }

    // الإصدار 33: إصلاح سلامة operation_logs بعد الترقية.
    if (oldVersion < 33) {
      await _ensureFinancialSchema(db);

      final users = await db.query(
        'users',
        columns: ['id'],
        where: 'is_deleted = 0',
        orderBy: 'id ASC',
        limit: 1,
      );

      final now = DateTime.now().toIso8601String();

      if (users.isNotEmpty) {
        final fallbackUserId = users.first['id'];

        await db.rawUpdate(
          'UPDATE operation_logs SET user_id = ?, is_synced = 0, updated_at = ? WHERE user_id NOT IN (SELECT id FROM users)',
          [fallbackUserId, now],
        );
      } else {
        await db.rawUpdate(
          'UPDATE operation_logs SET is_deleted = 1, is_synced = 0, updated_at = ? WHERE user_id NOT IN (SELECT id FROM users)',
          [now],
        );
      }
    }

    // الإصدار 34: السماح بإعادة استخدام payment_key بعد الحذف المنطقي.
    // السجلات النشطة فقط يجب أن تكون فريدة.
    if (oldVersion < 34) {
      await db.execute('DROP INDEX IF EXISTS ux_payments_payment_key');

      await db.execute('''
        CREATE UNIQUE INDEX ux_payments_payment_key
        ON payments(payment_key)
        WHERE is_deleted = 0
      ''');

      // الإصدار 35: ضمان وجود sync_id لكل السجلات القديمة
      // التي كانت موجودة قبل تفعيل المزامنة الكاملة.
    }

    if (oldVersion < 35) {
      const syncTables = <String>[
        'users',
        'clients',
        'suppliers',
        'drivers',
        'tanks',
        'filling_operations',
        'sales',
        'payments',
        'account_transactions',
        'purchase_invoices',
        'purchase_items',
        'inventory_layers',
        'sale_inventory_allocations',
        'expenses',
        'salaries',
        'operation_logs',
      ];

      const uuid = Uuid();

      for (final table in syncTables) {
        final rows = await db.query(
          table,
          columns: ['id'],
          where: "sync_id IS NULL OR TRIM(sync_id) = ''",
        );

        for (final row in rows) {
          await db.update(
            table,
            {
              'sync_id': uuid.v4(),
              'is_synced': 0,
            },
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        }
      }
    }

    if (oldVersion < 36) {
      await _addColumnIfMissing(
        db,
        'operation_logs',
        'user_sync_id',
        'TEXT',
      );

      await _addColumnIfMissing(
        db,
        'operation_logs',
        'record_sync_id',
        'TEXT',
      );

      await db.execute('''
          UPDATE operation_logs
          SET user_sync_id = (
            SELECT u.sync_id
            FROM users u
            WHERE u.id = operation_logs.user_id
          )
          WHERE user_sync_id IS NULL
             OR TRIM(user_sync_id) = ''
        ''');

      await db.execute('''
          UPDATE operation_logs
          SET record_sync_id = (
            SELECT c.sync_id
            FROM clients c
            WHERE c.id = operation_logs.record_id
          )
          WHERE table_name = 'clients'
            AND (record_sync_id IS NULL OR TRIM(record_sync_id) = '')
        ''');

      await db.execute('''
          UPDATE operation_logs
          SET record_sync_id = (
            SELECT s.sync_id
            FROM suppliers s
            WHERE s.id = operation_logs.record_id
          )
          WHERE table_name = 'suppliers'
            AND (record_sync_id IS NULL OR TRIM(record_sync_id) = '')
        ''');

      await db.execute('''
          UPDATE operation_logs
          SET is_synced = 0
          WHERE user_sync_id IS NOT NULL
             OR record_sync_id IS NOT NULL
        ''');
    }

    // الإصدار 37: تجهيز تخزين آمن لكلمات المرور وأكواد الاسترداد.
    // لا نغيّر طريقة التحقق القديمة هنا؛ المستخدمون الحاليون
    // سيبقون متوافقين مع SHA-256 حتى تتم ترقيتهم بعد تسجيل دخول ناجح.
    if (oldVersion < 37) {
      await _addColumnIfMissing(
        db,
        'users',
        'password_salt',
        'TEXT',
      );

      await _addColumnIfMissing(
        db,
        'users',
        'password_hash_version',
        'INTEGER DEFAULT 1',
      );

      await _addColumnIfMissing(
        db,
        'users',
        'recovery_code_salt',
        'TEXT',
      );

      await _addColumnIfMissing(
        db,
        'users',
        'recovery_code_hash_version',
        'INTEGER DEFAULT 1',
      );
    }
  }
}
