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
        user_id INTEGER NOT NULL,
        action TEXT NOT NULL,
        table_name TEXT NOT NULL,
        record_id INTEGER NOT NULL,
        details TEXT,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users (id)
      )
    ''');

    // فحص نهائي بعد الإنشاء: يضمن وجود أي جدول أساسي مفقود حتى لو
    // تغيّر ترتيب الإنشاء أو كان هناك اختلاف في نسخة قاعدة البيانات.
    await _ensureCoreTables(db);
  }

  /// تصفير البيانات التشغيلية فقط.
  /// لا يحذف المستخدمين أو الموردين أو العملاء أو السائقين أو الخزانات.
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
      ];

      for (final table in tables) {
        await txn.delete(table);
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
    final existing = <String>{};
    try {
      final rows = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );
      for (final row in rows) {
        existing.add(row['name'].toString());
      }
    } catch (e) {
      debugPrint('Error listing tables: $e');
      return;
    }

    debugPrint('Existing tables: $existing');

    // كل جدول: (الاسم، كود الإنشاء)
    final tablesToCheck = <String, String>{
      'users': '''
        CREATE TABLE IF NOT EXISTS users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sync_id TEXT UNIQUE NOT NULL,
          firebase_uid TEXT,
          firebase_email TEXT,
          username TEXT UNIQUE NOT NULL,
          password_hash TEXT NOT NULL,
          recovery_code_hash TEXT,
          full_name TEXT NOT NULL,
          role TEXT NOT NULL,
          driver_id INTEGER,
          permissions TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          must_change_password INTEGER DEFAULT 0,
          is_deleted INTEGER DEFAULT 0,
          is_synced INTEGER DEFAULT 0
        )
      ''',
      'clients': '''
        CREATE TABLE IF NOT EXISTS clients (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sync_id TEXT UNIQUE NOT NULL,
          name TEXT NOT NULL,
          phone TEXT,
          address TEXT,
          notes TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          is_deleted INTEGER DEFAULT 0,
          is_synced INTEGER DEFAULT 0
        )
      ''',
      'suppliers': '''
        CREATE TABLE IF NOT EXISTS suppliers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sync_id TEXT UNIQUE NOT NULL,
          name TEXT NOT NULL,
          phone TEXT,
          address TEXT,
          notes TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          is_deleted INTEGER DEFAULT 0,
          is_synced INTEGER DEFAULT 0
        )
      ''',
      'drivers': '''
        CREATE TABLE IF NOT EXISTS drivers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sync_id TEXT UNIQUE NOT NULL,
          name TEXT NOT NULL,
          phone TEXT,
          notes TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          is_deleted INTEGER DEFAULT 0,
          is_synced INTEGER DEFAULT 0
        )
      ''',
      'tanks': '''
        CREATE TABLE IF NOT EXISTS tanks (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sync_id TEXT UNIQUE NOT NULL,
          name TEXT NOT NULL,
          capacity INTEGER,
          notes TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          is_deleted INTEGER DEFAULT 0,
          is_synced INTEGER DEFAULT 0
        )
      ''',
      'filling_operations': '''
        CREATE TABLE IF NOT EXISTS filling_operations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sync_id TEXT UNIQUE NOT NULL,
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
          is_synced INTEGER DEFAULT 0
        )
      ''',
      'sales': '''
        CREATE TABLE IF NOT EXISTS sales (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sync_id TEXT UNIQUE NOT NULL,
          customer_id INTEGER,
          driver_id INTEGER,
          tank_id INTEGER,
          quantity INTEGER NOT NULL,
          unit_price REAL NOT NULL,
          total_amount REAL NOT NULL,
          paid_amount REAL DEFAULT 0,
          sale_date TEXT NOT NULL,
          notes TEXT,
          created_by INTEGER NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          is_deleted INTEGER DEFAULT 0,
          is_synced INTEGER DEFAULT 0
        )
      ''',
      'payments': '''
        CREATE TABLE IF NOT EXISTS payments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sync_id TEXT UNIQUE NOT NULL,
          client_id INTEGER,
          supplier_id INTEGER,
          amount REAL NOT NULL,
          payment_type TEXT NOT NULL,
          payment_date TEXT NOT NULL,
          notes TEXT,
          created_by INTEGER NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          is_deleted INTEGER DEFAULT 0,
          is_synced INTEGER DEFAULT 0
        )
      ''',
      'account_transactions': '''
        CREATE TABLE IF NOT EXISTS account_transactions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sync_id TEXT UNIQUE NOT NULL,
          account_type TEXT NOT NULL,
          account_id INTEGER NOT NULL,
          transaction_type TEXT NOT NULL,
          amount REAL NOT NULL,
          description TEXT,
          reference_type TEXT,
          reference_id INTEGER,
          transaction_date TEXT NOT NULL,
          created_by INTEGER NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          is_deleted INTEGER DEFAULT 0,
          is_synced INTEGER DEFAULT 0
        )
      ''',
      'purchase_invoices': '''
        CREATE TABLE IF NOT EXISTS purchase_invoices (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sync_id TEXT UNIQUE NOT NULL,
          supplier_id INTEGER,
          invoice_number TEXT,
          total_amount REAL NOT NULL,
          paid_amount REAL DEFAULT 0,
          purchase_date TEXT NOT NULL,
          notes TEXT,
          created_by INTEGER NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          is_deleted INTEGER DEFAULT 0,
          is_synced INTEGER DEFAULT 0
        )
      ''',
      'purchase_items': '''
        CREATE TABLE IF NOT EXISTS purchase_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sync_id TEXT UNIQUE NOT NULL,
          invoice_id INTEGER NOT NULL,
          item_type TEXT NOT NULL,
          item_id INTEGER,
          quantity INTEGER NOT NULL,
          unit_price REAL NOT NULL,
          total_price REAL NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          is_deleted INTEGER DEFAULT 0,
          is_synced INTEGER DEFAULT 0
        )
      ''',
      'inventory_layers': '''
        CREATE TABLE IF NOT EXISTS inventory_layers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sync_id TEXT UNIQUE NOT NULL,
          item_type TEXT NOT NULL,
          item_id INTEGER,
          original_units INTEGER NOT NULL,
          remaining_units INTEGER NOT NULL,
          unit_cost REAL NOT NULL,
          layer_date TEXT NOT NULL,
          reference_type TEXT,
          reference_id INTEGER,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          is_deleted INTEGER DEFAULT 0,
          is_synced INTEGER DEFAULT 0
        )
      ''',
      'sale_inventory_allocations': '''
        CREATE TABLE IF NOT EXISTS sale_inventory_allocations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sync_id TEXT UNIQUE NOT NULL,
          sale_id INTEGER NOT NULL,
          layer_id INTEGER NOT NULL,
          units INTEGER NOT NULL,
          unit_cost REAL NOT NULL,
          total_cost REAL NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          is_deleted INTEGER DEFAULT 0,
          is_synced INTEGER DEFAULT 0
        )
      ''',
      'expenses': '''
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
          sync_id TEXT UNIQUE NOT NULL
        )
      ''',
      'salaries': '''
        CREATE TABLE IF NOT EXISTS salaries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sync_id TEXT UNIQUE NOT NULL,
          employee_id INTEGER NOT NULL,
          month TEXT NOT NULL,
          base_salary REAL NOT NULL,
          advances REAL DEFAULT 0,
          deductions REAL DEFAULT 0,
          net_salary REAL NOT NULL,
          payment_date TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          is_deleted INTEGER DEFAULT 0,
          is_synced INTEGER DEFAULT 0
        )
      ''',
      'operation_logs': '''
        CREATE TABLE IF NOT EXISTS operation_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sync_id TEXT UNIQUE NOT NULL,
          user_id INTEGER NOT NULL,
          operation_type TEXT NOT NULL,
          table_name TEXT,
          record_id INTEGER,
          details TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          is_deleted INTEGER DEFAULT 0,
          is_synced INTEGER DEFAULT 0
        )
      ''',
    };

    int created = 0;
    for (final entry in tablesToCheck.entries) {
      final tableName = entry.key;
      if (!existing.contains(tableName)) {
        try {
          await db.execute(entry.value);
          debugPrint('✅ Table created: $tableName');
          created++;
        } catch (e) {
          debugPrint('❌ Failed to create $tableName: $e');
        }
      }
    }

    if (created > 0) {
      debugPrint('✅ Created $created missing tables');
    } else {
      debugPrint('✅ All tables exist');
    }
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
            notes, created_by, created_at, updated_at,
            is_deleted, is_synced, sync_id
          )
          SELECT
            id, sale_number, client_id, tank_id, driver_id,
            supplier_id, units, sale_price, total_amount,
            cost_amount, profit_amount, sale_date, payment_status,
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
  }
}
