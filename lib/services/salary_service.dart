import 'package:sqflite/sqflite.dart';
import '../core/database/database_helper.dart';
import '../models/salary.dart';

class SalaryService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<int> addSalary(Salary salary) async {
    final db = await _dbHelper.database;
    return await db.insert('salaries', salary.toMap());
  }

  Future<List<Salary>> getAllSalaries() async {
    final db = await _dbHelper.database;
    final result = await db.query('salaries', where: 'is_deleted = 0', orderBy: 'month DESC');
    return result.map((e) => Salary.fromMap(e)).toList();
  }
}
