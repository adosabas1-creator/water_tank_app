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
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
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
        purchase_invoice_id INTEGER,
        payment_key TEXT,
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
        purchase_invoice_id INTEGER,
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
      ON account_transactions (account_type, reference_id, transaction_date)
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
      );
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
      );
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
      );
      CREATE INDEX idx_purchase_invoices_supplier ON purchase_invoices (supplier_id, purchase_date);
      CREATE INDEX idx_purchase_items_invoice ON purchase_items (purchase_invoice_id);
      CREATE INDEX idx_inventory_layers_fifo ON inventory_layers (item_type, layer_date, id);
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
      );
      CREATE INDEX idx_sale_inventory_allocations_sale ON sale_inventory_allocations (sale_id);
      CREATE INDEX idx_sale_inventory_allocations_supplier ON sale_inventory_allocations (supplier_id, created_at);
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
      );
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
      );
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

  Future<void> resetTransactionalData() async {
    final db = await database;
    await db.transaction((txn) async {
      const tables = [
        'sale_inventory_allocations', 'sales', 'inventory_layers',
        'purchase_items', 'purchase_invoices', 'payments',
        'account_transactions', 'expenses', 'salaries',
        'filling_operations', 'operation_logs',
      ];
      for (final table in tables) {
        await txn.delete(table);
      }
    });
  }

  Future<void> closeDatabase() async {
    final db = _database;
    _database = null;
    if (db != null && db.isOpen) await db.close();
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 17) {
      final columns = await db.rawQuery('PRAGMA table_info(filling_operations)');
      final tankColumn = columns.firstWhere((c) => c['name'] == 'tank_id', orElse: () => <String, Object?>{});
      if (tankColumn['notnull'] == 1) {
        await db.execute('ALTER TABLE filling_operations RENAME TO filling_operations_old');
        await db.execute('''CREATE TABLE filling_operations (
          id INTEGER PRIMARY KEY AUTOINCREMENT, operation_number TEXT UNIQUE, tank_id INTEGER,
          supplier_id INTEGER NOT NULL, units INTEGER NOT NULL, purchase_price REAL NOT NULL,
          operation_date TEXT NOT NULL, employee_id INTEGER, notes TEXT, created_by INTEGER NOT NULL,
          created_at TEXT NOT NULL, updated_at TEXT NOT NULL, is_deleted INTEGER DEFAULT 0,
          is_synced INTEGER DEFAULT 0, sync_id TEXT UNIQUE NOT NULL,
          FOREIGN KEY (tank_id) REFERENCES tanks (id), FOREIGN KEY (supplier_id) REFERENCES suppliers (id),
          FOREIGN KEY (employee_id) REFERENCES users (id), FOREIGN KEY (created_by) REFERENCES users (id))''');
        await db.execute('''INSERT INTO filling_operations
          (id,operation_number,tank_id,supplier_id,units,purchase_price,operation_date,employee_id,notes,created_by,created_at,updated_at,is_deleted,is_synced,sync_id)
          SELECT id,operation_number,tank_id,supplier_id,units,purchase_price,operation_date,employee_id,notes,created_by,created_at,updated_at,is_deleted,is_synced,sync_id FROM filling_operations_old''');
        await db.execute('DROP TABLE filling_operations_old');
      }
    }
    if (oldVersion < 16) {
      final c = await db.rawQuery('PRAGMA table_info(sales)');
      if (!c.any((x) => x['name'] == 'client_payment_status')) await db.execute('ALTER TABLE sales ADD COLUMN client_payment_status TEXT');
      if (!c.any((x) => x['name'] == 'supplier_payment_status')) await db.execute('ALTER TABLE sales ADD COLUMN supplier_payment_status TEXT');
      if (!c.any((x) => x['name'] == 'created_by_name')) await db.execute('ALTER TABLE sales ADD COLUMN created_by_name TEXT');
    }
    if (oldVersion < 18) {
      await db.execute('''CREATE TABLE IF NOT EXISTS account_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT, account_type TEXT NOT NULL, reference_id INTEGER NOT NULL,
        amount REAL NOT NULL, transaction_type TEXT NOT NULL, transaction_date TEXT NOT NULL, notes TEXT,
        created_by INTEGER NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
        is_deleted INTEGER DEFAULT 0, is_synced INTEGER DEFAULT 0, sync_id TEXT UNIQUE NOT NULL,
        FOREIGN KEY (created_by) REFERENCES users (id))''');
      await db.execute('''CREATE INDEX IF NOT EXISTS idx_account_transactions_reference
        ON account_transactions (account_type, reference_id, transaction_date)''');
    }
    if (oldVersion < 19) {
      final p = await db.rawQuery('PRAGMA table_info(purchase_invoices)');
      if (p.isEmpty) {
        await db.execute('''CREATE TABLE purchase_invoices (
          id INTEGER PRIMARY KEY AUTOINCREMENT, invoice_number TEXT UNIQUE NOT NULL, supplier_id INTEGER NOT NULL,
          purchase_date TEXT NOT NULL, total_amount REAL NOT NULL, payment_status TEXT NOT NULL, notes TEXT,
          created_by INTEGER NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL,
          is_deleted INTEGER DEFAULT 0, is_synced INTEGER DEFAULT 0, sync_id TEXT UNIQUE NOT NULL,
          FOREIGN KEY (supplier_id) REFERENCES suppliers (id), FOREIGN KEY (created_by) REFERENCES users (id))''');
      }
    }
    if (oldVersion < 22) {
      final paymentColumns = await db.rawQuery('PRAGMA table_info(payments)');
      if (!paymentColumns.any((c) => c['name'] == 'purchase_invoice_id')) await db.execute('ALTER TABLE payments ADD COLUMN purchase_invoice_id INTEGER');
      if (!paymentColumns.any((c) => c['name'] == 'payment_key')) await db.execute('ALTER TABLE payments ADD COLUMN payment_key TEXT');
      final txColumns = await db.rawQuery('PRAGMA table_info(account_transactions)');
      if (!txColumns.any((c) => c['name'] == 'purchase_invoice_id')) await db.execute('ALTER TABLE account_transactions ADD COLUMN purchase_invoice_id INTEGER');
    }
  }
}
