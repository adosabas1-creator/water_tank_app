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

  Future<double> getTotalAmount({
    required String accountType,
    required int referenceId,
  }) async {
    final db = await _dbHelper.database;

    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM account_transactions
      WHERE account_type = ?
        AND reference_id = ?
        AND is_deleted = 0
      ''',
      [accountType, referenceId],
    );

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<void> deleteTransaction(int id) async {
    final db = await _dbHelper.database;

    await db.update(
      'account_transactions',
      {
        'is_deleted': 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
