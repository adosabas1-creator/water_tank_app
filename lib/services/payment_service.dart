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
      return id;
    });
  }

  Future<List<Payment>> getAllPayments() async {
    final db = await _dbHelper.database;
    final result = await db.query('payments', where: 'is_deleted = 0', orderBy: 'payment_date DESC, id DESC');
    return result.map(Payment.fromMap).toList();
  }

  Future<List<Payment>> getPaymentsForClient(int clientId) async {
    final db = await _dbHelper.database;
    final result = await db.query('payments', where: 'payment_type = ? AND reference_id = ? AND is_deleted = 0', whereArgs: ['client_payment', clientId], orderBy: 'payment_date ASC, id ASC');
    return result.map(Payment.fromMap).toList();
  }

  Future<List<Payment>> getPaymentsForSupplier(int supplierId) async {
    final db = await _dbHelper.database;
    final result = await db.query('payments', where: 'payment_type = ? AND reference_id = ? AND is_deleted = 0', whereArgs: ['supplier_payment', supplierId], orderBy: 'payment_date ASC, id ASC');
    return result.map(Payment.fromMap).toList();
  }

  Future<List<Payment>> getPaymentsForPurchaseInvoice(int invoiceId) async {
    final db = await _dbHelper.database;
    final result = await db.query('payments', where: 'purchase_invoice_id = ? AND is_deleted = 0', whereArgs: [invoiceId], orderBy: 'payment_date ASC, id ASC');
    return result.map(Payment.fromMap).toList();
  }

  Future<double> getPaidAmountForPurchaseInvoice(int invoiceId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total FROM payments
      WHERE purchase_invoice_id = ? AND payment_type = 'supplier_payment' AND is_deleted = 0
    ''', [invoiceId]);
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  Future<double> getRemainingAmountForPurchaseInvoice(int invoiceId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('''
      SELECT MAX(pi.total_amount - COALESCE(p.paid_amount, 0), 0) AS remaining
      FROM purchase_invoices pi
      LEFT JOIN (
        SELECT purchase_invoice_id, SUM(amount) AS paid_amount
        FROM payments WHERE payment_type = 'supplier_payment' AND is_deleted = 0
        GROUP BY purchase_invoice_id
      ) p ON p.purchase_invoice_id = pi.id
      WHERE pi.id = ? AND pi.is_deleted = 0
    ''', [invoiceId]);
    return (result.first['remaining'] as num?)?.toDouble() ?? 0.0;
  }

  Future<void> updatePayment(Payment payment) async {
    PermissionService.requireManagementRole();
    _validatePayment(payment);
    if (payment.id == null || payment.id! <= 0) throw ArgumentError('رقم الدفعة غير صالح.');

    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final oldRows = await txn.query('payments', columns: ['purchase_invoice_id'], where: 'id = ? AND is_deleted = 0', whereArgs: [payment.id], limit: 1);
      if (oldRows.isEmpty) throw StateError('الدفعة غير موجودة أو محذوفة.');

      await _validateReference(txn, payment);

      final key = payment.paymentKey.trim().isEmpty ? payment.syncId : payment.paymentKey.trim();
      final duplicate = await txn.query(
        'payments',
        columns: ['id', 'is_deleted'],
        where: '(sync_id = ? OR payment_key = ?) AND id <> ?',
        whereArgs: [payment.syncId, key, payment.id],
        limit: 1,
      );
      if (duplicate.isNotEmpty) {
        throw StateError('معرف الدفعة أو مفتاحها مستخدم لدفعة أخرى.');
      }

      await _validateInvoicePaymentLimit(txn, payment, excludePaymentId: payment.id);

      final data = payment.toMap()..remove('id');
      data['is_synced'] = 0;
      data['updated_at'] = DateTime.now().toIso8601String();
      await txn.update('payments', data, where: 'id = ? AND is_deleted = 0', whereArgs: [payment.id]);

      final oldInvoiceId = (oldRows.first['purchase_invoice_id'] as num?)?.toInt();
      if (oldInvoiceId != null && oldInvoiceId != payment.purchaseInvoiceId) {
        await _refreshPurchaseInvoiceStatus(txn, oldInvoiceId);
      }
      if (payment.purchaseInvoiceId != null) {
        await _refreshPurchaseInvoiceStatus(txn, payment.purchaseInvoiceId!);
      }
    });
  }

  Future<void> deletePayment(int id) async {
    PermissionService.requireManagementRole();
    if (id <= 0) throw ArgumentError('رقم الدفعة غير صالح.');
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final rows = await txn.query('payments', columns: ['purchase_invoice_id'], where: 'id = ? AND is_deleted = 0', whereArgs: [id], limit: 1);
      if (rows.isEmpty) throw StateError('الدفعة غير موجودة أو محذوفة.');
      final invoiceId = (rows.first['purchase_invoice_id'] as num?)?.toInt();
      await txn.update('payments', {'is_deleted': 1, 'is_synced': 0, 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ? AND is_deleted = 0', whereArgs: [id]);
      if (invoiceId != null) await _refreshPurchaseInvoiceStatus(txn, invoiceId);
    });
  }

  void _validatePayment(Payment payment) {
    if (payment.amount <= 0) throw ArgumentError('مبلغ الدفعة يجب أن يكون أكبر من صفر.');
    if (payment.referenceId <= 0) throw ArgumentError('الجهة المرتبطة بالدفعة غير صالحة.');
    if (payment.paymentType != 'client_payment' && payment.paymentType != 'supplier_payment') throw ArgumentError('نوع الدفعة غير صالح.');
    if (payment.purchaseInvoiceId != null && payment.purchaseInvoiceId! <= 0) throw ArgumentError('رقم فاتورة الشراء غير صالح.');
    if (payment.paymentKey.trim().isEmpty && payment.syncId.trim().isEmpty) throw ArgumentError('معرف الدفعة غير صالح.');
  }

  Future<void> _validateReference(DatabaseExecutor db, Payment payment) async {
    final table = payment.paymentType == 'client_payment' ? 'clients' : 'suppliers';
    final reference = await db.query(table, columns: ['id'], where: 'id = ? AND is_deleted = 0', whereArgs: [payment.referenceId], limit: 1);
    if (reference.isEmpty) throw StateError('العميل أو المورد المرتبط بالدفعة غير موجود أو محذوف.');

    if (payment.purchaseInvoiceId != null) {
      final invoice = await db.query('purchase_invoices', columns: ['id', 'supplier_id', 'is_deleted'], where: 'id = ?', whereArgs: [payment.purchaseInvoiceId], limit: 1);
      if (invoice.isEmpty || (invoice.first['is_deleted'] as num? ?? 0).toInt() == 1) throw StateError('فاتورة الشراء غير موجودة أو محذوفة.');
      if (payment.paymentType != 'supplier_payment') throw StateError('لا يمكن ربط دفعة عميل بفاتورة شراء.');
      if ((invoice.first['supplier_id'] as num).toInt() != payment.referenceId) throw StateError('الفاتورة لا تنتمي إلى المورد المحدد.');
    }
  }

  Future<void> _validateInvoicePaymentLimit(DatabaseExecutor db, Payment payment, {int? excludePaymentId}) async {
    final invoiceId = payment.purchaseInvoiceId;
    if (invoiceId == null) return;
    final invoice = await db.query('purchase_invoices', columns: ['total_amount'], where: 'id = ? AND is_deleted = 0', whereArgs: [invoiceId], limit: 1);
    if (invoice.isEmpty) throw StateError('فاتورة الشراء غير موجودة أو محذوفة.');
    final paid = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total FROM payments
      WHERE purchase_invoice_id = ? AND payment_type = 'supplier_payment' AND is_deleted = 0
      ${excludePaymentId != null ? 'AND id <> ?' : ''}
    ''', excludePaymentId != null ? [invoiceId, excludePaymentId] : [invoiceId]);
    final alreadyPaid = (paid.first['total'] as num?)?.toDouble() ?? 0.0;
    final total = (invoice.first['total_amount'] as num).toDouble();
    if (alreadyPaid + payment.amount > total + 0.000001) throw StateError('لا يمكن تسجيل الدفعة: إجمالي الدفعات سيتجاوز قيمة الفاتورة.');
  }

  Future<void> _refreshPurchaseInvoiceStatus(DatabaseExecutor db, int invoiceId) async {
    final invoiceRows = await db.query('purchase_invoices', columns: ['total_amount'], where: 'id = ? AND is_deleted = 0', whereArgs: [invoiceId], limit: 1);
    if (invoiceRows.isEmpty) return;
    final total = (invoiceRows.first['total_amount'] as num).toDouble();
    final paidRows = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total FROM payments
      WHERE purchase_invoice_id = ? AND payment_type = 'supplier_payment' AND is_deleted = 0
    ''', [invoiceId]);
    final paid = (paidRows.first['total'] as num?)?.toDouble() ?? 0.0;
    final status = paid <= 0.000001 ? 'unpaid' : paid >= total - 0.000001 ? 'paid' : 'partial';
    await db.update('purchase_invoices', {'payment_status': status, 'updated_at': DateTime.now().toIso8601String(), 'is_synced': 0}, where: 'id = ? AND is_deleted = 0', whereArgs: [invoiceId]);
  }
}
