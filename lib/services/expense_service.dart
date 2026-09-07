import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../models/expense.dart';

class ExpenseService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<int> addExpense(Expense expense) async {
    final db = await _dbHelper.database;
    return await db.insert('expenses', expense.toMap());
  }

  Future<List<Expense>> getAllExpenses() async {
    final db = await _dbHelper.database;
    final result = await db.query('expenses', where: 'is_deleted = 0', orderBy: 'expense_date DESC');
    return result.map((e) => Expense.fromMap(e)).toList();
  }
}
