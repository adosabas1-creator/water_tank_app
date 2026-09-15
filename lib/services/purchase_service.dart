import '../core/auth/permission_service.dart';
import '../core/database/database_helper.dart';
import '../models/account_transaction.dart';
import '../models/inventory_layer.dart';
import '../models/payment.dart';
import '../models/purchase_invoice.dart';
import '../models/purchase_item.dart';

class PurchaseService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// Adds the invoice, inventory layer, supplier debt and initial payment as
  /// one atomic operation.
  ///
  /// paidAmount is optional for backward compatibility:
  /// - paid     => full invoice amount
  /// - partial  => must be supplied and be between zero and total
  /// - unpaid   => zero
  Future<int> addPurchase({
    required PurchaseInvoice invoice,
    required PurchaseItem item,
    double? paidAmount,
  }) async {
    PermissionService.requireManagementRole();

    if (invoice.supplierId <= 0) {
      throw ArgumentError('المورد غير صالح.');
    }
    if (invoice.totalAmount <= 0) {
      throw ArgumentError('إجمالي الفاتورة يجب أن يكون أكبر من صفر.');
    }
    if (item.units <= 0 || item.purchasePrice < 0) {
      throw ArgumentError('بيانات صنف الشراء غير صالحة.');
    }
    if (item.totalAmount < 0 ||
        (item.totalAmount - item.units * item.purchasePrice).abs() > 0.01) {
      throw ArgumentError('إجمالي صنف الشراء غير صالح.');
    }
    if ((invoice.totalAmount - item.totalAmount).abs() > 0.01) {
      throw ArgumentError('إجمالي الفاتورة لا يطابق إجمالي صنف الشراء.');
    }

    final status = invoice.paymentStatus.trim().toLowerCase();
    if (status != 'paid' && status != 'partial' && status != 'unpaid') {
      throw ArgumentError('حالة السداد غير صالحة.');
    }

    final resolvedPaidAmount = paidAmount ??
        (status == 'paid'
            ? invoice.totalAmount
            : status == 'unpaid'
                ? 0.0
                : -1.0);

    if (resolvedPaidAmount < 0) {
      throw ArgumentError('يجب إدخال المبلغ المدفوع عند اختيار السداد الجزئي.');
    }
    if (resolvedPaidAmount > invoice.totalAmount + 0.000001) {
      throw ArgumentError('المبلغ المدفوع لا يمكن أن يتجاوز قيمة الفاتورة.');
    }

    final expectedStatus = resolvedPaidAmount <= 0.000001
        ? 'unpaid'
        : resolvedPaidAmount >= invoice.totalAmount - 0.000001
            ? 'paid'
            : 'partial';
    if (expectedStatus != status) {
      throw ArgumentError('حالة السداد لا تطابق المبلغ المدفوع.');
    }

    final db = await _dbHelper.database;

    final existing = await db.query(
      'purchase_invoices',
      columns: ['id', 'is_deleted'],
      where: 'sync_id = ?',
      whereArgs: [invoice.syncId],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      if ((existing.first['is_deleted'] as num? ?? 0).toInt() == 1) {
        throw StateError(
          'هذه الفاتورة موجودة مسبقًا وتم حذفها. استخدم عملية شراء جديدة.',
        );
      }
      return (existing.first['id'] as num).toInt();
    }

    final supplier = await db.query(
      'suppliers',
      columns: ['id'],
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [invoice.supplierId],
      limit: 1,
    );
    if (supplier.isEmpty) {
      throw StateError('المورد غير موجود أو محذوف.');
    }

    return db.transaction((txn) async {
      final invoiceData = invoice.toMap()..remove('id');
      invoiceData['payment_status'] = expectedStatus;

      final invoiceId = await txn.insert('purchase_invoices', invoiceData);

      final itemExisting = await txn.query(
        'purchase_items',
        columns: ['id'],
        where: 'sync_id = ?',
        whereArgs: [item.syncId],
        limit: 1,
      );
      if (itemExisting.isNotEmpty) {
        throw StateError('صنف الشراء موجود مسبقًا.');
      }

      final itemWithInvoice = PurchaseItem(
        purchaseInvoiceId: invoiceId,
        itemType: item.itemType,
        units: item.units,
        purchasePrice: item.purchasePrice,
        totalAmount: item.totalAmount,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
        isDeleted: item.isDeleted,
        isSynced: false,
        syncId: item.syncId,
      );
      final itemId = await txn.insert(
        'purchase_items',
        itemWithInvoice.toMap()..remove('id'),
      );

      final layer = InventoryLayer(
        purchaseItemId: itemId,
        itemType: item.itemType,
        originalUnits: item.units,
        remainingUnits: item.units,
        unitCost: item.purchasePrice,
        layerDate: invoice.purchaseDate,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
        syncId: 'layer_${invoice.syncId}_$itemId',
      );
      await txn.insert('inventory_layers', layer.toMap()..remove('id'));

      final debtSyncId = 'purchase_debt_${invoice.syncId}';
      final debtExisting = await txn.query(
        'account_transactions',
        columns: ['id', 'is_deleted'],
        where: 'sync_id = ?',
        whereArgs: [debtSyncId],
        limit: 1,
      );
      if (debtExisting.isNotEmpty) {
        throw StateError('حركة مديونية الشراء موجودة مسبقًا.');
      }

      final now = DateTime.now().toIso8601String();
      final debt = AccountTransaction(
        accountType: 'supplier',
        referenceId: invoice.supplierId,
        purchaseInvoiceId: invoiceId,
        amount: invoice.totalAmount,
        transactionType: 'debt',
        transactionDate: invoice.purchaseDate.toIso8601String(),
        notes: 'شراء ${invoice.invoiceNumber}',
        createdBy: invoice.createdBy,
        createdAt: now,
        updatedAt: now,
        isDeleted: false,
        isSynced: false,
        syncId: debtSyncId,
      );
      await txn.insert('account_transactions', debt.toMap());

      if (resolvedPaidAmount > 0.000001) {
        final paymentSyncId = 'purchase_payment_${invoice.syncId}';
        final payment = Payment(
          syncId: paymentSyncId,
          paymentKey: paymentSyncId,
          paymentType: 'supplier_payment',
          referenceId: invoice.supplierId,
          purchaseInvoiceId: invoiceId,
          amount: resolvedPaidAmount,
          paymentMethod: null,
          referenceNumber: invoice.invoiceNumber,
          paymentDate: invoice.purchaseDate.toIso8601String(),
          notes: 'دفعة عند إنشاء فاتورة ${invoice.invoiceNumber}',
          createdBy: invoice.createdBy,
          createdAt: now,
          updatedAt: now,
          isDeleted: false,
          isSynced: false,
        );
        await txn.insert('payments', payment.toMap()..remove('id'));
      }

      return invoiceId;
    });
  }
}
