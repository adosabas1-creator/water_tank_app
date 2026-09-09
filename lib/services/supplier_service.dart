import '../core/database/database_helper.dart';
import '../models/supplier.dart';

class SupplierService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<int> addSupplier(Supplier supplier) async {
    final db = await _dbHelper.database;
    return await db.insert('suppliers', supplier.toMap());
  }

  Future<List<Supplier>> getAllSuppliers() async {
    final db = await _dbHelper.database;
    final result = await db.query('suppliers',
        where: 'is_deleted = 0', orderBy: 'name ASC');
    return result.map((e) => Supplier.fromMap(e)).toList();
  }

  Future<Supplier?> getSupplierById(int id) async {
    final db = await _dbHelper.database;
    final result = await db.query('suppliers',
        where: 'id = ? AND is_deleted = 0', whereArgs: [id]);
    if (result.isNotEmpty) return Supplier.fromMap(result.first);
    return null;
  }

  Future<void> updateSupplier(Supplier supplier) async {
    final db = await _dbHelper.database;
    final data = supplier.toMap();
    data['is_synced'] = 0;
    await db
        .update('suppliers', data, where: 'id = ?', whereArgs: [supplier.id]);
  }

  Future<void> deleteSupplier(int id) async {
    final db = await _dbHelper.database;
    await db.update(
      'suppliers',
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
