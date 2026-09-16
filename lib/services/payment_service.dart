import 'package:sqflite/sqflite.dart';

import '../core/auth/permission_service.dart';
import '../core/database/database_helper.dart';
import '../models/payment.dart';

class PaymentService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<int> addPayment(Payment payment) async {
    PermissionService.requireManagementRole();
    _validatePayment(payment);
    final db = await _dbHelper.database;

    return db.transaction((txn) async {
      await _validateReference(txn, payment);

      final key = payment.paymentKey.trim().isEmpty ? payment.syncId : payment.paymentKey.trim();
      final existing = await txn.query(
        'payments',
        columns: ['id', 'is_deleted'],
        where: 'sync_id = ? OR payment_key = ?',
        whereArgs: [payment.syncId, key],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        if ((existing.first['is_deleted'] as num? ?? 0).toInt() == 1) {
          throw StateError('هذه الدفعة موجودة مسبقًا وتم حذفها. استخدم عملية جديدة.');
        }
        return (existing.first['id'] as num).toInt();
      }

      await _validateInvoicePaymentLimit(txn, payment);
      final id = await txn.insert('payments', payment.toMap()..remove('id'));
      if (payment.purchaseInvoiceId != null) {
        await _refreshPurchaseInvoiceStatus(txn, payment.purchaseInvoiceId!);
      }