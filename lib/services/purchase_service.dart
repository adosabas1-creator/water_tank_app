import '../core/auth/permission_service.dart';
import '../core/database/database_helper.dart';
import '../models/account_transaction.dart';
import '../models/inventory_layer.dart';
import '../models/purchase_invoice.dart';
import '../models/purchase_item.dart';

class PurchaseService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<int> addPurchase({required PurchaseInvoice invoice, required PurchaseItem item}) async {
    PermissionService.requireManagementRole();
    final db = await _dbHelper.database;
    final existing = await db.query('purchase_invoices', columns: ['id', 'is_deleted'], where: 'sync_id = ?', whereArgs: [invoice.syncId], limit: 1);
    if (existing.isNotEmpty) {
      if ((existing.first['is_deleted'] as num? ?? 0).toInt() == 1) throw StateError('هذه الفاتورة موجودة مسبقًا وتم حذفها. استخدم عملية شراء جديدة.');
      return (existing.first['id'] as num).toInt();
    }
    if (invoice.totalAmount < 0 || item.units <= 0 || item.purchasePrice < 0) throw ArgumentError('بيانات الشراء غير صالحة.');
    if (invoice.supplierId <= 0) throw ArgumentError('المورد غير صالح.');
    final supplier = await db.query('suppliers', columns: ['id'], where: 'id = ? AND is_deleted = 0', whereArgs: [invoice.supplierId], limit: 1);
    if (supplier.isEmpty) throw StateError('المورد غير موجود أو محذوف.');
    if (item.totalAmount < 0 || (item.totalAmount - item.units * item.purchasePrice).abs() > 0.01) throw ArgumentError('إجمالي صنف الشراء غير صالح.');
    if ((invoice.totalAmount - item.totalAmount).abs() > 0.01) throw ArgumentError('إجمالي الفاتورة لا يطابق إجمالي صنف الشراء.');

    return db.transaction((txn) async {
      final invoiceId = await txn.insert('purchase_invoices', invoice.toMap()..remove('id'));
      final itemExisting = await txn.query('purchase_items', columns: ['id'], where: 'sync_id = ?', whereArgs: [item.syncId], limit: 1);
      if (itemExisting.isNotEmpty) throw StateError('صنف الشراء موجود مسبقًا.');
      final itemWithInvoice = PurchaseItem(purchaseInvoiceId: invoiceId, itemType: item.itemType, units: item.units, purchasePrice: item.purchasePrice, totalAmount: item.totalAmount, createdAt: item.createdAt, updatedAt: item.updatedAt, isDeleted: item.isDeleted, isSynced: false, syncId: item.syncId);
      final itemId = await txn.insert('purchase_items', itemWithInvoice.toMap()..remove('id'));
      final layer = InventoryLayer(purchaseItemId: itemId, itemType: item.itemType, originalUnits: item.units, remainingUnits: item.units, unitCost: item.purchasePrice, layerDate: invoice.purchaseDate, createdAt: item.createdAt, updatedAt: item.updatedAt, syncId: 'layer_${invoice.syncId}_$itemId');
      await txn.insert('inventory_layers', layer.toMap()..remove('id'));
      if (invoice.paymentStatus == 'unpaid') {
        final debtSyncId = 'purchase_debt_${invoice.syncId}';
        final debtExisting = await txn.query('account_transactions', columns: ['id'], where: 'sync_id = ?', whereArgs: [debtSyncId], limit: 1);
        if (debtExisting.isNotEmpty) throw StateError('حركة مديونية الشراء موجودة مسبقًا.');
        final now = DateTime.now().toIso8601String();
        final transaction = AccountTransaction(accountType: 'supplier', referenceId: invoice.supplierId, amount: invoice.totalAmount, transactionType: 'debt', transactionDate: invoice.purchaseDate.toIso8601String(), notes: 'شراء آجل ${invoice.invoiceNumber}', createdBy: invoice.createdBy, createdAt: now, updatedAt: now, isDeleted: false, isSynced: false, syncId: debtSyncId);
        await txn.insert('account_transactions', transaction.toMap());
      }
      return invoiceId;
    });
  }
}
