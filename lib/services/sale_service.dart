import '../core/auth/permission_service.dart';
import '../core/constants/permissions.dart';
import '../core/database/database_helper.dart';
import '../models/account_transaction.dart';
import '../models/payment.dart';
import '../models/sale.dart';

class SaleService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<Sale> addSale(Sale sale, {double? paidAmount}) async {
    PermissionService.requirePermission(PermissionKeys.salesAdd);
    final db = await _dbHelper.database;
    final effectivePaidAmount = _validateSaleInput(
      sale,
      paidAmount: paidAmount,
    );

    return await db.transaction((txn) async {
      await _validateSaleReferences(txn, sale);
      final allocationResult =
          await _allocateInventoryFIFO(txn, sale.units, sale.supplierId);
      final now = DateTime.now().toIso8601String();
      final profitAmount = sale.totalAmount - allocationResult.totalCost;

      final calculatedSale = Sale(
        id: sale.id,
        syncId: sale.syncId,
        saleNumber: sale.saleNumber,
        clientId: sale.clientId,
        tankId: sale.tankId,
        driverId: sale.driverId,
        supplierId: sale.supplierId,
        units: sale.units,
        salePrice: sale.salePrice,
        totalAmount: sale.totalAmount,
        costAmount: allocationResult.totalCost,
        profitAmount: profitAmount,
        saleDate: sale.saleDate,
        paymentStatus: sale.paymentStatus,
        clientPaymentStatus: sale.clientPaymentStatus,
        supplierPaymentStatus: sale.supplierPaymentStatus,
        createdByName: sale.createdByName,
        notes: sale.notes,
        createdBy: sale.createdBy,
        createdAt: sale.createdAt,
        updatedAt: now,
        isDeleted: false,
        isSynced: false,
      );

      final saleId =
          await txn.insert('sales', calculatedSale.toMap()..remove('id'));
      await _insertAllocations(
          txn, saleId, sale.syncId, allocationResult.allocations, now);
      await _createClientDebtIfNeeded(txn, calculatedSale, saleId, now);

      if (calculatedSale.clientId != null &&
          calculatedSale.clientPaymentStatus == 'partial') {
        final paymentSyncId = 'sale_payment_${calculatedSale.syncId}';

        final payment = Payment(
          syncId: paymentSyncId,
          paymentType: 'client_payment',
          referenceId: calculatedSale.clientId!,
          paymentKey: paymentSyncId,
          amount: effectivePaidAmount,
          paymentDate: calculatedSale.saleDate,
          notes: 'دفعة من مبيعة ${calculatedSale.saleNumber ?? saleId}',
          createdBy: calculatedSale.createdBy,
          createdAt: now,
          updatedAt: now,
          isDeleted: false,
          isSynced: false,
        );

        await txn.insert(
          'payments',
          payment.toMap()..remove('id'),
        );
      }

      return Sale(
        id: saleId,
        syncId: calculatedSale.syncId,
        saleNumber: calculatedSale.saleNumber,
        clientId: calculatedSale.clientId,
        tankId: calculatedSale.tankId,
        driverId: calculatedSale.driverId,
        supplierId: calculatedSale.supplierId,
        units: calculatedSale.units,
        salePrice: calculatedSale.salePrice,
        totalAmount: calculatedSale.totalAmount,
        costAmount: calculatedSale.costAmount,
        profitAmount: calculatedSale.profitAmount,
        saleDate: calculatedSale.saleDate,
        paymentStatus: calculatedSale.paymentStatus,
        clientPaymentStatus: calculatedSale.clientPaymentStatus,
        supplierPaymentStatus: calculatedSale.supplierPaymentStatus,
        createdByName: calculatedSale.createdByName,
        notes: calculatedSale.notes,
        createdBy: calculatedSale.createdBy,
        createdAt: calculatedSale.createdAt,
        updatedAt: calculatedSale.updatedAt,
        isDeleted: calculatedSale.isDeleted,
        isSynced: calculatedSale.isSynced,
      );
    });
  }

  double _validateSaleInput(
    Sale sale, {
    double? paidAmount,
  }) {
    if (sale.units <= 0) {
      throw ArgumentError('يجب أن تكون كمية البيع أكبر من صفر.');
    }

    if (sale.salePrice <= 0) {
      throw ArgumentError('سعر البيع يجب أن يكون أكبر من صفر.');
    }

    if (sale.totalAmount <= 0) {
      throw ArgumentError('إجمالي البيع يجب أن يكون أكبر من صفر.');
    }

    final calculatedTotal = sale.units * sale.salePrice;

    if ((calculatedTotal - sale.totalAmount).abs() > 0.000001) {
      throw ArgumentError(
        'إجمالي البيع لا يطابق الكمية × سعر الوحدة.',
      );
    }

    const validStatuses = {'paid', 'partial', 'unpaid'};

    final clientStatus = sale.clientPaymentStatus ?? sale.paymentStatus;

    if (!validStatuses.contains(clientStatus)) {
      throw ArgumentError('حالة دفع العميل غير صالحة.');
    }

    if (!validStatuses.contains(sale.paymentStatus)) {
      throw ArgumentError('حالة الدفع غير صالحة.');
    }

    if (sale.clientPaymentStatus != null &&
        sale.paymentStatus != sale.clientPaymentStatus) {
      throw ArgumentError(
        'حالة الدفع القديمة والجديدة غير متطابقة.',
      );
    }

    if (sale.clientId == null && clientStatus != 'paid') {
      throw ArgumentError(
        'البيع بدون عميل يجب أن يكون مدفوعًا بالكامل.',
      );
    }

    final effectivePaidAmount =
        paidAmount ?? (clientStatus == 'paid' ? sale.totalAmount : 0.0);

    if (effectivePaidAmount < 0 ||
        effectivePaidAmount > sale.totalAmount + 0.000001) {
      throw ArgumentError('مبلغ المدفوع غير صالح.');
    }

    if (clientStatus == 'paid' &&
        (effectivePaidAmount - sale.totalAmount).abs() > 0.000001) {
      throw ArgumentError(
        'عند اختيار مدفوع بالكامل يجب أن يساوي المدفوع إجمالي المبيعة.',
      );
    }

    if (clientStatus == 'unpaid' && effectivePaidAmount.abs() > 0.000001) {
      throw ArgumentError(
        'عند اختيار غير مدفوع يجب أن يكون المبلغ المدفوع صفرًا.',
      );
    }

    if (clientStatus == 'partial' &&
        (effectivePaidAmount <= 0 || effectivePaidAmount >= sale.totalAmount)) {
      throw ArgumentError(
        'في السداد الجزئي يجب أن يكون المدفوع أكبر من صفر وأقل من الإجمالي.',
      );
    }

    return effectivePaidAmount;
  }

  Future<void> _validateSaleReferences(dynamic txn, Sale sale) async {
    if (sale.supplierId <= 0) throw ArgumentError('المورد المحدد غير صالح.');
    final supplier = await txn.query('suppliers',
        columns: ['id'],
        where: 'id = ? AND is_deleted = 0',
        whereArgs: [sale.supplierId],
        limit: 1);
    if (supplier.isEmpty) throw StateError('المورد غير موجود أو محذوف.');

    if (sale.clientId != null) {
      if (sale.clientId! <= 0) throw ArgumentError('العميل المحدد غير صالح.');
      final client = await txn.query('clients',
          columns: ['id'],
          where: 'id = ? AND is_deleted = 0',
          whereArgs: [sale.clientId],
          limit: 1);
      if (client.isEmpty) throw StateError('العميل غير موجود أو محذوف.');
    }
  }

  Future<_InventoryAllocationResult> _allocateInventoryFIFO(
      dynamic txn, int requestedUnits, int supplierId) async {
    if (requestedUnits <= 0) {
      throw Exception('كمية البيع يجب أن تكون أكبر من صفر.');
    }

    final layers = await txn.query(
      'inventory_layers',
      where: 'item_type = ? AND is_deleted = 0 AND remaining_units > 0',
      whereArgs: ['tank'],
      orderBy: 'layer_date ASC, id ASC',
    );

    var availableSupplierUnits = 0;
    final supplierLayers = <Map<String, dynamic>>[];

    for (final layer in layers) {
      final purchaseItemId = layer['purchase_item_id'] as int;
      final purchaseItem = await txn.query('purchase_items',
          columns: ['purchase_invoice_id'],
          where: 'id = ? AND is_deleted = 0',
          whereArgs: [purchaseItemId],
          limit: 1);
      if (purchaseItem.isEmpty) {
        throw Exception('تعذر العثور على صنف الشراء المرتبط بطبقة المخزون.');
      }

      final purchaseInvoiceId =
          purchaseItem.first['purchase_invoice_id'] as int;
      final purchaseInvoice = await txn.query('purchase_invoices',
          columns: ['supplier_id'],
          where: 'id = ? AND is_deleted = 0',
          whereArgs: [purchaseInvoiceId],
          limit: 1);
      if (purchaseInvoice.isEmpty) {
        throw Exception(
            'تعذر العثور على فاتورة الشراء المرتبطة بطبقة المخزون.');
      }

      final layerSupplierId = purchaseInvoice.first['supplier_id'] as int;
      if (layerSupplierId != supplierId) continue;
      supplierLayers.add(layer);
      availableSupplierUnits +=
          ((layer['remaining_units'] as num?)?.toInt() ?? 0);
    }

    if (availableSupplierUnits < requestedUnits) {
      throw Exception(
          'مخزون المورد المحدد غير كافٍ. المتوفر للمورد: $availableSupplierUnits وحدة، والمطلوب: $requestedUnits وحدة.');
    }

    var remainingToConsume = requestedUnits;
    var totalCost = 0.0;
    final allocations = <Map<String, dynamic>>[];
    final now = DateTime.now().toIso8601String();

    for (final layer in supplierLayers) {
      if (remainingToConsume <= 0) break;
      final layerId = layer['id'] as int;
      final purchaseItemId = layer['purchase_item_id'] as int;
      final remainingUnits = (layer['remaining_units'] as num).toInt();
      final unitCost = (layer['unit_cost'] as num).toDouble();
      final consumedUnits = remainingToConsume < remainingUnits
          ? remainingToConsume
          : remainingUnits;
      final costAmount = consumedUnits * unitCost;
      final newRemainingUnits = remainingUnits - consumedUnits;

      final changed = await txn.update(
          'inventory_layers',
          {
            'remaining_units': newRemainingUnits,
            'updated_at': now,
            'is_synced': 0
          },
          where: 'id = ? AND is_deleted = 0',
          whereArgs: [layerId]);
      if (changed != 1) {
        throw StateError('تعذر تحديث طبقة المخزون أثناء البيع.');
      }

      allocations.add({
        'inventory_layer_id': layerId,
        'purchase_item_id': purchaseItemId,
        'supplier_id': supplierId,
        'units': consumedUnits,
        'unit_cost': unitCost,
        'cost_amount': costAmount
      });
      totalCost += costAmount;
      remainingToConsume -= consumedUnits;
    }

    if (remainingToConsume != 0) {
      throw Exception('تعذر إكمال استهلاك مخزون المورد بطريقة FIFO.');
    }
    return _InventoryAllocationResult(
        allocations: allocations, totalCost: totalCost);
  }

  Future<void> _insertAllocations(dynamic txn, int saleId, String saleSyncId,
      List<Map<String, dynamic>> allocations, String now) async {
    for (final allocation in allocations) {
      await txn.insert('sale_inventory_allocations', {
        'sale_id': saleId,
        'inventory_layer_id': allocation['inventory_layer_id'],
        'purchase_item_id': allocation['purchase_item_id'],
        'supplier_id': allocation['supplier_id'],
        'units': allocation['units'],
        'unit_cost': allocation['unit_cost'],
        'cost_amount': allocation['cost_amount'],
        'created_at': now,
        'updated_at': now,
        'is_deleted': 0,
        'is_synced': 0,
        'sync_id':
            'sale_alloc_${saleSyncId}_${allocation['inventory_layer_id']}_$saleId',
      });
    }
  }

  Future<void> _restoreSaleInventory(dynamic txn, int saleId) async {
    final allocations = await txn.query('sale_inventory_allocations',
        where: 'sale_id = ? AND is_deleted = 0', whereArgs: [saleId]);
    for (final allocation in allocations) {
      final layerId = allocation['inventory_layer_id'] as int;
      final units = (allocation['units'] as num).toInt();
      if (units <= 0) throw StateError('تخصيص مخزون غير صالح مرتبط بالمبيعة.');

      final layer = await txn.query('inventory_layers',
          columns: ['remaining_units'],
          where: 'id = ? AND is_deleted = 0',
          whereArgs: [layerId],
          limit: 1);
      if (layer.isEmpty) {
        throw StateError('تعذر العثور على طبقة مخزون نشطة لإرجاع كمية البيع.');
      }

      final remainingUnits =
          (layer.first['remaining_units'] as num?)?.toInt() ?? 0;
      final changed = await txn.update(
          'inventory_layers',
          {
            'remaining_units': remainingUnits + units,
            'updated_at': DateTime.now().toIso8601String(),
            'is_synced': 0
          },
          where: 'id = ? AND is_deleted = 0',
          whereArgs: [layerId]);
      if (changed != 1) throw StateError('تعذر إرجاع كمية البيع إلى المخزون.');
    }
  }

  Future<void> _softDeleteSaleAllocations(dynamic txn, int saleId) async {
    await txn.update(
        'sale_inventory_allocations',
        {
          'is_deleted': 1,
          'is_synced': 0,
          'updated_at': DateTime.now().toIso8601String()
        },
        where: 'sale_id = ? AND is_deleted = 0',
        whereArgs: [saleId]);
  }

  Future<void> _createClientDebtIfNeeded(
      dynamic txn, Sale sale, int saleId, String now) async {
    if (sale.clientId == null ||
        (sale.clientPaymentStatus != 'unpaid' &&
            sale.clientPaymentStatus != 'partial')) {
      return;
    }
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
    await txn.insert('account_transactions', transaction.toMap());
  }

  Future<void> _softDeleteClientDebt(dynamic txn, Sale sale) async {
    await txn.update(
        'account_transactions',
        {
          'is_deleted': 1,
          'is_synced': 0,
          'updated_at': DateTime.now().toIso8601String()
        },
        where:
            'account_type = ? AND reference_id = ? AND transaction_type = ? AND sync_id = ? AND is_deleted = 0',
        whereArgs: [
          'client',
          sale.clientId,
          'debt',
          'sale_debt_${sale.syncId}'
        ]);
  }

  Future<List<Map<String, dynamic>>> getSupplierSalesShareReport() async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT sia.supplier_id AS supplier_id, s.name AS supplier_name,
        SUM(sia.units) AS sold_units, SUM(sia.cost_amount) AS cost_amount,
        SUM(sia.units * sales.sale_price) AS sales_amount,
        SUM((sia.units * sales.sale_price) - sia.cost_amount) AS profit_amount
      FROM sale_inventory_allocations sia
      INNER JOIN sales ON sales.id = sia.sale_id
      INNER JOIN suppliers s ON s.id = sia.supplier_id
      WHERE sia.is_deleted = 0 AND sales.is_deleted = 0 AND s.is_deleted = 0
      GROUP BY sia.supplier_id, s.name ORDER BY s.name ASC
    ''');
  }

  Future<List<Sale>> getAllSales({int? driverId}) async {
    final db = await _dbHelper.database;
    final result = await db.query('sales',
        where: driverId == null
            ? 'is_deleted = 0'
            : 'is_deleted = 0 AND driver_id = ?',
        whereArgs: driverId == null ? null : [driverId],
        orderBy: 'sale_date DESC');
    return result.map((e) => Sale.fromMap(e)).toList();
  }

  Future<Sale?> getSaleById(int id) async {
    final db = await _dbHelper.database;
    final result = await db
        .query('sales', where: 'id = ? AND is_deleted = 0', whereArgs: [id]);
    if (result.isNotEmpty) return Sale.fromMap(result.first);
    return null;
  }

  Future<void> updateSale(Sale sale, {double? paidAmount}) async {
    PermissionService.requirePermission(PermissionKeys.salesEdit);

    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      final oldRows = await txn.query('sales',
          where: 'id = ? AND is_deleted = 0', whereArgs: [sale.id], limit: 1);
      if (oldRows.isEmpty) throw Exception('البيع غير موجود أو تم حذفه.');
      final oldSale = Sale.fromMap(oldRows.first);

      final oldPaymentRows = await txn.query(
        'payments',
        columns: ['id', 'amount'],
        where: 'sync_id = ? AND payment_type = ? AND is_deleted = 0',
        whereArgs: [
          'sale_payment_${oldSale.syncId}',
          'client_payment',
        ],
        limit: 1,
      );

      final oldPaymentId = oldPaymentRows.isNotEmpty
          ? (oldPaymentRows.first['id'] as num).toInt()
          : null;

      final oldPaymentAmount = oldPaymentRows.isNotEmpty
          ? (oldPaymentRows.first['amount'] as num).toDouble()
          : null;

      final validationPaidAmount = sale.clientPaymentStatus == 'partial'
          ? (paidAmount ?? oldPaymentAmount)
          : paidAmount;

      final effectivePaidAmount = _validateSaleInput(
        sale,
        paidAmount: validationPaidAmount,
      );

      await _validateSaleReferences(txn, sale);

      if (oldPaymentId != null) {
        await txn.update(
          'payments',
          {
            'is_deleted': 1,
            'is_synced': 0,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ? AND is_deleted = 0',
          whereArgs: [oldPaymentId],
        );
      }
      await _restoreSaleInventory(txn, oldSale.id!);
      await _softDeleteSaleAllocations(txn, oldSale.id!);
      await _softDeleteClientDebt(txn, oldSale);

      final allocationResult =
          await _allocateInventoryFIFO(txn, sale.units, sale.supplierId);
      final now = DateTime.now().toIso8601String();
      final profitAmount = sale.totalAmount - allocationResult.totalCost;
      final updatedSale = Sale(
        id: sale.id,
        syncId: oldSale.syncId,
        saleNumber: sale.saleNumber,
        clientId: sale.clientId,
        tankId: sale.tankId,
        driverId: sale.driverId,
        supplierId: sale.supplierId,
        units: sale.units,
        salePrice: sale.salePrice,
        totalAmount: sale.totalAmount,
        costAmount: allocationResult.totalCost,
        profitAmount: profitAmount,
        saleDate: sale.saleDate,
        paymentStatus: sale.paymentStatus,
        clientPaymentStatus: sale.clientPaymentStatus,
        supplierPaymentStatus: sale.supplierPaymentStatus,
        createdByName: sale.createdByName,
        notes: sale.notes,
        createdBy: sale.createdBy,
        createdAt: sale.createdAt,
        updatedAt: now,
        isDeleted: false,
        isSynced: false,
      );

      final data = updatedSale.toMap()..remove('id');
      data['is_synced'] = 0;
      final changed = await txn.update('sales', data,
          where: 'id = ? AND is_deleted = 0', whereArgs: [sale.id]);
      if (changed != 1) throw StateError('تعذر تحديث المبيعة.');

      await _insertAllocations(
          txn, sale.id!, oldSale.syncId, allocationResult.allocations, now);
      await _createClientDebtIfNeeded(txn, updatedSale, sale.id!, now);

      if (updatedSale.clientId != null &&
          updatedSale.clientPaymentStatus == 'partial') {
        final paymentSyncId = 'sale_payment_${updatedSale.syncId}';

        final payment = Payment(
          syncId: paymentSyncId,
          paymentType: 'client_payment',
          referenceId: updatedSale.clientId!,
          paymentKey: paymentSyncId,
          amount: effectivePaidAmount,
          paymentDate: updatedSale.saleDate,
          notes: 'دفعة من مبيعة ${updatedSale.saleNumber ?? sale.id}',
          createdBy: updatedSale.createdBy,
          createdAt: now,
          updatedAt: now,
          isDeleted: false,
          isSynced: false,
        );

        await txn.insert(
          'payments',
          payment.toMap()..remove('id'),
        );
      }
    });
  }

  Future<void> deleteSale(int id) async {
    PermissionService.requirePermission(PermissionKeys.salesDelete);
    if (id <= 0) throw ArgumentError('رقم البيع غير صالح.');
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      final rows = await txn.query('sales',
          where: 'id = ? AND is_deleted = 0', whereArgs: [id], limit: 1);
      if (rows.isEmpty) throw StateError('البيع غير موجود أو تم حذفه مسبقًا.');
      final sale = Sale.fromMap(rows.first);

      await _restoreSaleInventory(txn, sale.id!);
      await _softDeleteSaleAllocations(txn, sale.id!);
      await _softDeleteClientDebt(txn, sale);

      await txn.update(
        'payments',
        {
          'is_deleted': 1,
          'is_synced': 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'sync_id = ? AND is_deleted = 0',
        whereArgs: ['sale_payment_${sale.syncId}'],
      );

      final changed = await txn.update(
          'sales',
          {
            'is_deleted': 1,
            'is_synced': 0,
            'updated_at': DateTime.now().toIso8601String()
          },
          where: 'id = ? AND is_deleted = 0',
          whereArgs: [id]);
      if (changed != 1) throw StateError('تعذر حذف المبيعة.');
    });
  }
}

class _InventoryAllocationResult {
  final List<Map<String, dynamic>> allocations;
  final double totalCost;

  const _InventoryAllocationResult(
      {required this.allocations, required this.totalCost});
}
