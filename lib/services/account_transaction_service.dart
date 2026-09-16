import '../core/auth/permission_service.dart';
import '../core/database/database_helper.dart';
import '../models/account_transaction.dart';

class AccountTransactionService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<int> addTransaction(AccountTransaction transaction) async {
    PermissionService.requireManagementRole();
    if (transaction.amount <= 0 || transaction.referenceId <= 0) {
      throw ArgumentError('بيانات الحركة المالية غير صالحة.');
    }
    if (transaction.accountType != 'supplier' && transaction.accountType != 'client') {
      throw ArgumentError('نوع الحساب غير صالح.');
    }
    if (transaction.purchaseInvoiceId != null) {
      throw StateError('حركة فاتورة الشراء تُدار من خلال خدمة المشتريات فقط.');
    }
    final db = await _dbHelper.database;
    final existing = await db.query(
      'account_transactions',
      columns: ['id', 'is_deleted'],
      where: 'sync_id = ?',
      whereArgs: [transaction.syncId],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      if ((existing.first['is_deleted'] as num? ?? 0).toInt() == 1) {
        throw StateError('هذه الحركة موجودة سابقًا وتم حذفها.');
      }
      return (existing.first['id'] as num).toInt();
    }
    return db.insert('account_transactions', transaction.toMap());
  }

  Future<List<AccountTransaction>> getTransactions({
    required String accountType,
    required int referenceId,
  }) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'account_transactions',
      where: 'account_type = ? AND reference_id = ? AND is_deleted = 0',
      whereArgs: [accountType, referenceId],
      orderBy: 'transaction_date ASC, id ASC',
    );
    return result.map(AccountTransaction.fromMap).toList();
  }

  Future<double> getBalance({
    required String accountType,
    required int referenceId,
  }) async {
    final db = await _dbHelper.database;
    final transactionResult = await db.rawQuery('''
      SELECT COALESCE(SUM(CASE WHEN transaction_type = 'adjustment' THEN -amount ELSE amount END),0) AS total
      FROM account_transactions
      WHERE account_type = ? AND reference_id = ? AND is_deleted = 0
    ''', [accountType, referenceId]);
    final paymentType = accountType == 'supplier' ? 'supplier_payment' : 'client_payment';
    final paymentResult = await db.rawQuery('''
      SELECT COALESCE(SUM(amount),0) AS total
      FROM payments
      WHERE payment_type = ? AND reference_id = ? AND is_deleted = 0
    ''', [paymentType, referenceId]);
    final transactions = (transactionResult.first['total'] as num?)?.toDouble() ?? 0.0;
    final payments = (paymentResult.first['total'] as num?)?.toDouble() ?? 0.0;
    return transactions - payments;
  }

  Future<double> getTotalAmount({required String accountType, required int referenceId}) async =>
      getBalance(accountType: accountType, referenceId: referenceId);

  Future<void> deleteTransaction(int id) async {
    PermissionService.requireManagementRole();
    if (id <= 0) throw ArgumentError('رقم الحركة غير صالح.');

    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'account_transactions',
        columns: ['id', 'purchase_invoice_id', 'account_type', 'transaction_type', 'is_deleted'],
        where: 'id = ? AND is_deleted = 0',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('الحركة المالية غير موجودة أو محذوفة.');
      }

      final row = rows.first;
      final purchaseInvoiceId = (row['purchase_invoice_id'] as num?)?.toInt();
      if (purchaseInvoiceId != null &&
          row['account_type'] == 'supplier' &&
          row['transaction_type'] == 'debt') {
        throw StateError(
          'لا يمكن حذف مديونية فاتورة الشراء مباشرة. استخدم حذف فاتورة الشراء.',
        );
      }

      await txn.update(
        'account_transactions',
        {
          'is_deleted': 1,
          'updated_at': DateTime.now().toIso8601String(),
          'is_synced': 0,
        },
        where: 'id = ? AND is_deleted = 0',
        whereArgs: [id],
      );
    });
  }
}
