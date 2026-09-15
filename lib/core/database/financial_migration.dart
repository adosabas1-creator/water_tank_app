import 'package:sqflite/sqflite.dart';

/// Idempotent financial schema migration.
///
/// This migration deliberately keeps the new invoice links nullable so all
/// existing payments/account transactions remain valid. New financial code
/// should populate the links whenever the operation is invoice-specific.
class FinancialMigration {
  static const int schemaRevision = 22;

  static Future<void> migrate(Database db) async {
    await db.transaction((txn) async {
      await _addColumnIfMissing(
        txn,
        'payments',
        'purchase_invoice_id',
        'INTEGER',
      );
      await _addColumnIfMissing(
        txn,
        'payments',
        'payment_key',
        'TEXT',
      );
      await _addColumnIfMissing(
        txn,
        'account_transactions',
        'purchase_invoice_id',
        'INTEGER',
      );

      // Give every legacy payment a stable unique key before adding the
      // unique index. Existing rows are never deleted or rewritten except
      // for this newly introduced nullable identifier.
      await txn.execute('''
        UPDATE payments
        SET payment_key = 'legacy_payment_' || id
        WHERE payment_key IS NULL OR TRIM(payment_key) = ''
      ''');

      await txn.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS ux_payments_payment_key
        ON payments(payment_key)
      ''');

      await txn.execute('''
        CREATE INDEX IF NOT EXISTS idx_payments_purchase_invoice
        ON payments(purchase_invoice_id, payment_date, id)
      ''');

      await txn.execute('''
        CREATE INDEX IF NOT EXISTS idx_payments_supplier_reference
        ON payments(payment_type, reference_id, is_deleted, payment_date, id)
      ''');

      await txn.execute('''
        CREATE INDEX IF NOT EXISTS idx_account_transactions_purchase_invoice
        ON account_transactions(purchase_invoice_id, is_deleted)
      ''');

      // Only one active purchase-debt entry may represent an invoice.
      // Historical/deleted rows remain preserved and do not block a valid
      // replacement during an explicit correction workflow.
      await txn.execute('''
        CREATE UNIQUE INDEX IF NOT EXISTS ux_account_purchase_debt_invoice
        ON account_transactions(purchase_invoice_id)
        WHERE purchase_invoice_id IS NOT NULL
          AND is_deleted = 0
          AND account_type = 'supplier'
          AND transaction_type = 'purchase_debt'
      ''');

      // Invoice-specific supplier payments must belong to the same supplier
      // as the invoice and may never make cumulative payments exceed it.
      await txn.execute('''
        CREATE TRIGGER IF NOT EXISTS trg_payment_invoice_guard_insert
        BEFORE INSERT ON payments
        WHEN NEW.purchase_invoice_id IS NOT NULL
          AND NEW.is_deleted = 0
        BEGIN
          SELECT CASE
            WHEN NEW.payment_type <> 'supplier_payment'
              THEN RAISE(ABORT, 'دفعة الفاتورة يجب أن تكون دفعة مورد')
            WHEN NOT EXISTS (
              SELECT 1 FROM purchase_invoices pi
              WHERE pi.id = NEW.purchase_invoice_id
                AND pi.is_deleted = 0
                AND pi.supplier_id = NEW.reference_id
            )
              THEN RAISE(ABORT, 'الفاتورة لا تنتمي إلى المورد المحدد')
            WHEN NEW.amount <= 0
              THEN RAISE(ABORT, 'مبلغ الدفعة يجب أن يكون أكبر من صفر')
            WHEN (
              SELECT COALESCE(SUM(p.amount), 0)
              FROM payments p
              WHERE p.purchase_invoice_id = NEW.purchase_invoice_id
                AND p.is_deleted = 0
            ) + NEW.amount > (
              SELECT pi.total_amount
              FROM purchase_invoices pi
              WHERE pi.id = NEW.purchase_invoice_id
            ) + 0.000001
              THEN RAISE(ABORT, 'إجمالي دفعات الفاتورة يتجاوز قيمة الفاتورة')
          END;
        END
      ''');

      await txn.execute('''
        CREATE TRIGGER IF NOT EXISTS trg_payment_invoice_guard_update
        BEFORE UPDATE OF purchase_invoice_id, reference_id, payment_type, amount, is_deleted
        ON payments
        WHEN NEW.purchase_invoice_id IS NOT NULL
          AND NEW.is_deleted = 0
        BEGIN
          SELECT CASE
            WHEN NEW.payment_type <> 'supplier_payment'
              THEN RAISE(ABORT, 'دفعة الفاتورة يجب أن تكون دفعة مورد')
            WHEN NOT EXISTS (
              SELECT 1 FROM purchase_invoices pi
              WHERE pi.id = NEW.purchase_invoice_id
                AND pi.is_deleted = 0
                AND pi.supplier_id = NEW.reference_id
            )
              THEN RAISE(ABORT, 'الفاتورة لا تنتمي إلى المورد المحدد')
            WHEN NEW.amount <= 0
              THEN RAISE(ABORT, 'مبلغ الدفعة يجب أن يكون أكبر من صفر')
            WHEN (
              SELECT COALESCE(SUM(p.amount), 0)
              FROM payments p
              WHERE p.purchase_invoice_id = NEW.purchase_invoice_id
                AND p.is_deleted = 0
                AND p.id <> NEW.id
            ) + NEW.amount > (
              SELECT pi.total_amount
              FROM purchase_invoices pi
              WHERE pi.id = NEW.purchase_invoice_id
            ) + 0.000001
              THEN RAISE(ABORT, 'إجمالي دفعات الفاتورة يتجاوز قيمة الفاتورة')
          END;
        END
      ''');
    });
  }

  static Future<void> _addColumnIfMissing(
    DatabaseExecutor db,
    String table,
    String column,
    String definition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute(
        'ALTER TABLE $table ADD COLUMN $column $definition',
      );
    }
  }
}
