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

    final result = await db.query(
      'salaries',
      where: 'is_deleted = 0',
      orderBy: 'month DESC',
    );

    return result.map((e) => Salary.fromMap(e)).toList();
  }

  Future<void> updateSalary(Salary salary) async {
    final db = await _dbHelper.database;

    final data = salary.toMap();
    data['is_synced'] = 0;
    await db.update(
      'salaries',
      data,
      where: 'id = ?',
      whereArgs: [salary.id],
    );
  }

  Future<void> deleteSalary(int id) async {
    final db = await _dbHelper.database;

    await db.update(
      'salaries',
      {
        'is_deleted': 1,
        'is_synced': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
