import '../core/auth/permission_service.dart';
import '../core/database/database_helper.dart';
import '../models/account_transaction.dart';

class AccountTransactionService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<int> addTransaction(AccountTransaction transaction) async {
    PermissionService.requireManagementRole();
    final db = await _dbHelper.database;
    return db.insert('account_transactions', transaction.toMap());
  }

  Future<List<AccountTransaction>> getTransactions({required String accountType, required int referenceId}) async {
    final db = await _dbHelper.database;
    final result = await db.query('account_transactions', where: 'account_type = ? AND reference_id = ? AND is_deleted = 0', whereArgs: [accountType, referenceId], orderBy: 'transaction_date ASC, id ASC');
    return result.map(AccountTransaction.fromMap).toList();
  }

  Future<double> getBalance({required String accountType, required int referenceId}) async {
    final db = await _dbHelper.database;
    final transactionResult = await db.rawQuery('''SELECT COALESCE(SUM(CASE WHEN transaction_type = 'adjustment' THEN -amount ELSE amount END),0) AS total FROM account_transactions WHERE account_type = ? AND reference_id = ? AND is_deleted = 0''', [accountType, referenceId]);
    final paymentType = accountType == 'supplier' ? 'supplier_payment' : 'client_payment';
    final paymentResult = await db.rawQuery('''SELECT COALESCE(SUM(amount),0) AS total FROM payments WHERE payment_type = ? AND reference_id = ? AND is_deleted = 0''', [paymentType, referenceId]);
    final transactions = (transactionResult.first['total'] as num?)?.toDouble() ?? 0.0;
    final payments = (paymentResult.first['total'] as num?)?.toDouble() ?? 0.0;
    return transactions - payments;
  }

  Future<double> getTotalAmount({required String accountType, required int referenceId}) async => getBalance(accountType: accountType, referenceId: referenceId);

  Future<void> deleteTransaction(int id) async {
    PermissionService.requireManagementRole();
    final db = await _dbHelper.database;
    await db.update('account_transactions', {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String(), 'is_synced': 0}, where: 'id = ? AND is_deleted = 0', whereArgs: [id]);
  }
}
