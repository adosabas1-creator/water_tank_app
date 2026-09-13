import '../core/database/database_helper.dart';
import '../models/sale.dart';
import '../models/account_transaction.dart';

class SaleService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<int> addSale(Sale sale) async {
    final db = await _dbHelper.database;

    return await db.transaction((txn) async {
      final saleId = await txn.insert('sales', sale.toMap());

      if (sale.clientId != null && sale.clientPaymentStatus == 'credit') {
        final now = DateTime.now().toIso8601String();

        final transaction = AccountTransaction(
          accountType: 'client',
          referenceId: sale.clientId!,
          amount: sale.totalAmount,
          transactionType: 'debt',
          transactionDate: sale.saleDate,
          notes: 'دين مبيعة ${sale.saleNumber ?? saleId}',
          createdBy: sale.createdBy,
          createdAt: now,
          updatedAt: now,
          isDeleted: false,
          isSynced: false,
          syncId: 'sale_debt_${sale.syncId}',
        );

        await txn.insert(
          'account_transactions',
          transaction.toMap(),
        );
      }

      return saleId;
    });
  }

  Future<List<Sale>> getAllSales({int? driverId}) async {
    final db = await _dbHelper.database;

    final result = await db.query(
      'sales',
      where: driverId == null
          ? 'is_deleted = 0'
          : 'is_deleted = 0 AND driver_id = ?',
      whereArgs: driverId == null ? null : [driverId],
      orderBy: 'sale_date DESC',
    );

    return result.map((e) => Sale.fromMap(e)).toList();
  }

  Future<Sale?> getSaleById(int id) async {
    final db = await _dbHelper.database;

    final result = await db.query(
      'sales',
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [id],
    );

    if (result.isNotEmpty) {
      return Sale.fromMap(result.first);
    }

    return null;
  }

  Future<void> updateSale(Sale sale) async {
    final db = await _dbHelper.database;

    final data = sale.toMap();
    data['is_synced'] = 0;
    await db.update(
      'sales',
      data,
      where: 'id = ?',
      whereArgs: [sale.id],
    );
  }

  Future<void> deleteSale(int id) async {
    final db = await _dbHelper.database;

    await db.update(
      'sales',
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
