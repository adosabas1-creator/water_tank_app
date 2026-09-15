import '../core/auth/permission_service.dart';
import '../core/database/database_helper.dart';
import '../models/payment.dart';

class PaymentService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<int> addPayment(Payment payment) async {
    PermissionService.requireManagementRole();

    if (payment.amount <= 0) {
      throw ArgumentError('مبلغ الدفعة يجب أن يكون أكبر من صفر.');
    }
    if (payment.referenceId <= 0) {
      throw ArgumentError('الجهة المرتبطة بالدفعة غير صالحة.');
    }
    if (payment.paymentType != 'client_payment' &&
        payment.paymentType != 'supplier_payment') {
      throw ArgumentError('نوع الدفعة غير صالح.');
    }

    final db = await _dbHelper.database;
    final referenceTable = payment.paymentType == 'client_payment' ? 'clients' : 'suppliers';
    final reference = await db.query(referenceTable, columns: ['id'], where: 'id = ? AND is_deleted = 0', whereArgs: [payment.referenceId], limit: 1);
    if (reference.isEmpty) {
      throw StateError('العميل أو المورد المرتبط بالدفعة غير موجود أو محذوف.');
    }

    final existing = await db.query(
      'payments',
      columns: ['id', 'is_deleted'],
      where: 'sync_id = ?',
      whereArgs: [payment.syncId],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      if ((existing.first['is_deleted'] as num?)?.toInt() == 1) {
        throw StateError('هذه الدفعة موجودة مسبقًا وتم حذفها. استخدم عملية جديدة.');
      }
      return (existing.first['id'] as num).toInt();
    }

    return db.insert('payments', payment.toMap());
  }

  Future<List<Payment>> getAllPayments() async {
    final db = await _dbHelper.database;
    final result = await db.query('payments', where: 'is_deleted = 0', orderBy: 'payment_date DESC');
    return result.map((e) => Payment.fromMap(e)).toList();
  }

  Future<List<Payment>> getPaymentsForClient(int clientId) async {
    final db = await _dbHelper.database;
    final result = await db.query('payments', where: 'payment_type = ? AND reference_id = ? AND is_deleted = 0', whereArgs: ['client_payment', clientId], orderBy: 'payment_date ASC');
    return result.map((e) => Payment.fromMap(e)).toList();
  }

  Future<List<Payment>> getPaymentsForSupplier(int supplierId) async {
    final db = await _dbHelper.database;
    final result = await db.query('payments', where: 'payment_type = ? AND reference_id = ? AND is_deleted = 0', whereArgs: ['supplier_payment', supplierId], orderBy: 'payment_date ASC');
    return result.map((e) => Payment.fromMap(e)).toList();
  }

  Future<void> updatePayment(Payment payment) async {
    PermissionService.requireManagementRole();
    if (payment.id == null || payment.id! <= 0 || payment.amount <= 0 || payment.referenceId <= 0) {
      throw ArgumentError('بيانات الدفعة غير صالحة.');
    }
    if (payment.paymentType != 'client_payment' && payment.paymentType != 'supplier_payment') {
      throw ArgumentError('نوع الدفعة غير صالح.');
    }
    final db = await _dbHelper.database;
    final referenceTable = payment.paymentType == 'client_payment' ? 'clients' : 'suppliers';
    final reference = await db.query(referenceTable, columns: ['id'], where: 'id = ? AND is_deleted = 0', whereArgs: [payment.referenceId], limit: 1);
    if (reference.isEmpty) {
      throw StateError('العميل أو المورد المرتبط بالدفعة غير موجود أو محذوف.');
    }
    final existing = await db.query('payments', columns: ['sync_id'], where: 'id = ? AND is_deleted = 0', whereArgs: [payment.id], limit: 1);
    if (existing.isEmpty) throw StateError('الدفعة غير موجودة أو محذوفة.');
    final data = payment.toMap();
    data.remove('id');
    data['is_synced'] = 0;
    data['updated_at'] = DateTime.now().toIso8601String();
    await db.update('payments', data, where: 'id = ? AND is_deleted = 0', whereArgs: [payment.id]);
  }

  Future<void> deletePayment(int id) async {
    PermissionService.requireManagementRole();
    if (id <= 0) throw ArgumentError('رقم الدفعة غير صالح.');
    final db = await _dbHelper.database;
    final changed = await db.update('payments', {'is_deleted': 1, 'is_synced': 0, 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ? AND is_deleted = 0', whereArgs: [id]);
    if (changed == 0) throw StateError('الدفعة غير موجودة أو محذوفة.');
  }
}
