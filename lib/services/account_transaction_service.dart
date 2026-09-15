import '../core/database/database_helper.dart';
import '../models/account_transaction.dart';

class AccountTransactionService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<int> addTransaction(AccountTransaction transaction) async {
    final db = await _dbHelper.database;
    return db.insert('account_transactions', transaction.toMap());
  }

  Future<List<AccountTransaction>> getTransactions({
    required String accountType,
    required int referenceId,
  }) async {
    final db = await _dbHelper.database;

    final result = await db.query(
      'account_transactions',
      where: '''
        account_type = ?
        AND reference_id = ?
        AND is_deleted = 0
      ''',
      whereArgs: [accountType, referenceId],
      orderBy: 'transaction_date ASC, id ASC',
    );

    return result.map(AccountTransaction.fromMap).toList();
  }

  /// Returns the net account balance.
  /// Positive = amount owed by the account holder to the business.
  /// Negative = amount owed by the business to the account holder.
  ///
  /// Debts/opening balances/adjustments are treated as positive.
  /// Payments are stored separately and treated as negative.
  Future<double> getBalance({
    required String accountType,
    required int referenceId,
  }) async {
    final db = await _dbHelper.database;

    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(
        CASE
          WHEN transaction_type = 'payment' THEN -amount
          ELSE amount
        END
      ), 0) AS balance
      FROM account_transactions
      WHERE account_type = ?
        AND reference_id = ?
        AND is_deleted = 0
      ''',
      [accountType, referenceId],
    );

    return (result.first['balance'] as num?)?.toDouble() ?? 0.0;
  }

  /// Kept for compatibility with existing callers.
  /// For supplier/client balances prefer [getBalance].
  Future<double> getTotalAmount({
    required String accountType,
    required int referenceId,
  }) async {
    return getBalance(
      accountType: accountType,
      referenceId: referenceId,
    );
  }

  Future<void> deleteTransaction(int id) async {
    final db = await _dbHelper.database;

    await db.update(
      'account_transactions',
      {
        'is_deleted': 1,
        'updated_at': DateTime.now().toIso8601String(),
        'is_synced': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
