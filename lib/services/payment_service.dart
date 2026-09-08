import '../core/database/database_helper.dart';
import '../models/payment.dart';

class PaymentService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<int> addPayment(Payment payment) async {
    final db = await _dbHelper.database;
    return await db.insert('payments', payment.toMap());
  }

  Future<List<Payment>> getAllPayments() async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'payments',
      where: 'is_deleted = 0',
      orderBy: 'payment_date DESC',
    );
    return result.map((e) => Payment.fromMap(e)).toList();
  }

  Future<List<Payment>> getPaymentsForClient(int clientId) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'payments',
      where:
          'payment_type = ? AND reference_id = ? AND is_deleted = 0',
      whereArgs: ['client_payment', clientId],
      orderBy: 'payment_date ASC',
    );
    return result.map((e) => Payment.fromMap(e)).toList();
  }

  Future<List<Payment>> getPaymentsForSupplier(int supplierId) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'payments',
      where:
          'payment_type = ? AND reference_id = ? AND is_deleted = 0',
      whereArgs: ['supplier_payment', supplierId],
      orderBy: 'payment_date ASC',
    );
    return result.map((e) => Payment.fromMap(e)).toList();
  }

  Future<void> updatePayment(Payment payment) async {
    final db = await _dbHelper.database;
    await db.update(
      'payments',
      payment.toMap(),
      where: 'id = ?',
      whereArgs: [payment.id],
    );
  }

  Future<void> deletePayment(int id) async {
    final db = await _dbHelper.database;
    await db.update(
      'payments',
      {
        'is_deleted': 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
