import '../core/auth/permission_service.dart';
import '../core/database/database_helper.dart';
import '../models/expense.dart';

class ExpenseService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<int> addExpense(Expense expense) async {
    PermissionService.requireManagementRole();
    final db = await _dbHelper.database;
    return await db.insert('expenses', expense.toMap());
  }

  Future<List<Expense>> getAllExpenses() async {
    final db = await _dbHelper.database;
    final result = await db.query('expenses', where: 'is_deleted = 0', orderBy: 'expense_date DESC');
    return result.map((e) => Expense.fromMap(e)).toList();
  }

  Future<void> updateExpense(Expense expense) async {
    PermissionService.requireManagementRole();
    final db = await _dbHelper.database;
    final data = expense.toMap();
    data['is_synced'] = 0;
    await db.update('expenses', data, where: 'id = ? AND is_deleted = 0', whereArgs: [expense.id]);
  }

  Future<void> deleteExpense(int id) async {
    PermissionService.requireManagementRole();
    final db = await _dbHelper.database;
    await db.update('expenses', {'is_deleted': 1, 'is_synced': 0, 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ? AND is_deleted = 0', whereArgs: [id]);
  }
}
