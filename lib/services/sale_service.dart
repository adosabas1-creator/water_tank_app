import '../core/database/database_helper.dart';
import '../models/account_transaction.dart';
import '../models/sale.dart';

class SaleService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<Sale> addSale(Sale sale) async {
    final db = await _dbHelper.database;

    if (sale.units <= 0) {
      throw Exception('يجب أن تكون كمية البيع أكبر من صفر.');
    }
    if (sale.totalAmount < 0) {
      throw Exception('إجمالي البيع غير صالح.');
    }

    return await db.transaction((txn) async {
      final allocationResult = await _allocateInventoryFIFO(txn, sale.units);
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

      final saleId = await txn.insert(
        'sales',
        calculatedSale.toMap()..remove('id'),
      );

      await _insertAllocations(txn, saleId, sale.syncId, allocationResult.allocations, now);

      await _createClientDebtIfNeeded(txn, calculatedSale, saleId, now);

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

  Future<_InventoryAllocationResult> _allocateInventoryFIFO(
    dynamic txn,
    int requestedUnits,
  ) async {
    if (requestedUnits <= 0) {
      throw Exception('كمية البيع يجب أن تكون أكبر من صفر.');
    }

    final layers = await txn.query(
      'inventory_layers',
      where: '''
        item_type = ?
        AND is_deleted = 0
        AND remaining_units > 0
      ''',
      whereArgs: ['tank'],
      orderBy: 'layer_date ASC, id ASC',
    );

    final availableUnits = layers.fold<int>(
      0,
      (sum, layer) => sum + ((layer['remaining_units'] as num?)?.toInt() ?? 0),
    );

    if (availableUnits < requestedUnits) {
      throw Exception(
        'المخزون غير كافٍ. المتوفر: $availableUnits وحدة، '
        'والمطلوب: $requestedUnits وحدة.',
      );
    }

    var remainingToConsume = requestedUnits;
    var totalCost = 0.0;
    final allocations = <Map<String, dynamic>>[];
    final now = DateTime.now().toIso8601String();

    for (final layer in layers) {
      if (remainingToConsume <= 0) break;

      final layerId = layer['id'] as int;
      final purchaseItemId = layer['purchase_item_id'] as int;
      final remainingUnits = (layer['remaining_units'] as num).toInt();
      final unitCost = (layer['unit_cost'] as num).toDouble();
      final consumedUnits = remainingToConsume < remainingUnits
          ? remainingToConsume
          : remainingUnits;

      final purchaseItem = await txn.query(
        'purchase_items',
        columns: ['purchase_invoice_id'],
        where: 'id = ? AND is_deleted = 0',
        whereArgs: [purchaseItemId],
        limit: 1,
      );
      if (purchaseItem.isEmpty) {
        throw Exception('تعذر العثور على صنف الشراء المرتبط بطبقة المخزون.');
      }

      final purchaseInvoiceId = purchaseItem.first['purchase_invoice_id'] as int;
      final purchaseInvoice = await txn.query(
        'purchase_invoices',
        columns: ['supplier_id'],
        where: 'id = ? AND is_deleted = 0',
        whereArgs: [purchaseInvoiceId],
        limit: 1,
      );
      if (purchaseInvoice.isEmpty) {
        throw Exception('تعذر العثور على فاتورة الشراء المرتبطة بطبقة المخزون.');
      }

      final supplierId = purchaseInvoice.first['supplier_id'] as int;
      final costAmount = consumedUnits * unitCost;
      final newRemainingUnits = remainingUnits - consumedUnits;

      await txn.update(
        'inventory_layers',
        {
          'remaining_units': newRemainingUnits,
          'updated_at': now,
          'is_synced': 0,
        },
        where: 'id = ? AND is_deleted = 0',
        whereArgs: [layerId],
      );

      allocations.add({
        'inventory_layer_id': layerId,
        'purchase_item_id': purchaseItemId,
        'supplier_id': supplierId,
        'units': consumedUnits,
        'unit_cost': unitCost,
        'cost_amount': costAmount,
      });

      totalCost += costAmount;
      remainingToConsume -= consumedUnits;
    }

    if (remainingToConsume != 0) {
      throw Exception('تعذر إكمال استهلاك المخزون بطريقة FIFO.');
    }

    return _InventoryAllocationResult(
      allocations: allocations,
      totalCost: totalCost,
    );
  }

  Future<void> _insertAllocations(
    dynamic txn,
    int saleId,
    String saleSyncId,
    List<Map<String, dynamic>> allocations,
    String now,
  ) async {
    for (final allocation in allocations) {
      await txn.insert(
        'sale_inventory_allocations',
        {
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
          'sync_id': 'sale_alloc_${saleSyncId}_${allocation['inventory_layer_id']}_${saleId}',
        },
      );
    }
  }

  Future<void> _restoreSaleInventory(dynamic txn, int saleId) async {
    final allocations = await txn.query(
      'sale_inventory_allocations',
      where: 'sale_id = ? AND is_deleted = 0',
      whereArgs: [saleId],
    );

    for (final allocation in allocations) {
      final layerId = allocation['inventory_layer_id'] as int;
      final units = (allocation['units'] as num).toInt();

      final layer = await txn.query(
        'inventory_layers',
        columns: ['remaining_units'],
        where: 'id = ?',
        whereArgs: [layerId],
        limit: 1,
      );
      if (layer.isEmpty) {
        throw Exception('تعذر العثور على طبقة المخزون لإرجاع كمية البيع.');
      }

      final remainingUnits = (layer.first['remaining_units'] as num?)?.toInt() ?? 0;
      await txn.update(
        'inventory_layers',
        {
          'remaining_units': remainingUnits + units,
          'updated_at': DateTime.now().toIso8601String(),
          'is_synced': 0,
        },
        where: 'id = ?',
        whereArgs: [layerId],
      );
    }
  }

  Future<void> _softDeleteSaleAllocations(dynamic txn, int saleId) async {
    await txn.update(
      'sale_inventory_allocations',
      {
        'is_deleted': 1,
        'is_synced': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'sale_id = ? AND is_deleted = 0',
      whereArgs: [saleId],
    );
  }

  Future<void> _createClientDebtIfNeeded(
    dynamic txn,
    Sale sale,
    int saleId,
    String now,
  ) async {
    if (sale.clientId == null || sale.clientPaymentStatus != 'unpaid') return;

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
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: '''
        account_type = ?
        AND reference_id = ?
        AND transaction_type = ?
        AND sync_id = ?
        AND is_deleted = 0
      ''',
      whereArgs: [
        'client',
        sale.clientId,
        'debt',
        'sale_debt_${sale.syncId}',
      ],
    );
  }

  Future<List<Map<String, dynamic>>> getSupplierSalesShareReport() async {
    final db = await _dbHelper.database;

    return await db.rawQuery('''
      WITH allocation_data AS (
        SELECT
          sia.id AS allocation_id,
          sia.sale_id,
          sia.supplier_id,
          s.name AS supplier_name,
          sales.units AS sale_units,
          sales.sale_price,
          sia.units AS allocated_units,
          sia.unit_cost,
          SUM(sia.units) OVER (
            PARTITION BY sia.sale_id
            ORDER BY sia.id
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
          ) AS units_before
        FROM sale_inventory_allocations sia
        INNER JOIN sales ON sales.id = sia.sale_id
        INNER JOIN suppliers s ON s.id = sia.supplier_id
        WHERE sia.is_deleted = 0
          AND sales.is_deleted = 0
          AND s.is_deleted = 0
      ),
      effective_allocations AS (
        SELECT
          supplier_id,
          supplier_name,
          CASE
            WHEN units_before IS NULL THEN
              CASE WHEN allocated_units > sale_units THEN sale_units ELSE allocated_units END
            WHEN units_before >= sale_units THEN 0
            WHEN units_before + allocated_units > sale_units THEN sale_units - units_before
            ELSE allocated_units
          END AS effective_units,
          unit_cost,
          sale_price
        FROM allocation_data
      )
      SELECT
        supplier_id,
        supplier_name,
        SUM(effective_units) AS sold_units,
        SUM(effective_units * unit_cost) AS cost_amount,
        SUM(effective_units * sale_price) AS sales_amount,
        SUM((effective_units * sale_price) - (effective_units * unit_cost)) AS profit_amount
      FROM effective_allocations
      WHERE effective_units > 0
      GROUP BY supplier_id, supplier_name
      ORDER BY supplier_name ASC
    ''');
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

    if (result.isNotEmpty) return Sale.fromMap(result.first);
    return null;
  }

  Future<void> updateSale(Sale sale) async {
    if (sale.id == null) throw Exception('رقم البيع غير موجود.');
    if (sale.units <= 0) throw Exception('يجب أن تكون كمية البيع أكبر من صفر.');
    if (sale.totalAmount < 0) throw Exception('إجمالي البيع غير صالح.');

    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      final oldRows = await txn.query(
        'sales',
        where: 'id = ? AND is_deleted = 0',
        whereArgs: [sale.id],
        limit: 1,
      );
      if (oldRows.isEmpty) throw Exception('البيع غير موجود أو تم حذفه.');

      final oldSale = Sale.fromMap(oldRows.first);
      await _restoreSaleInventory(txn, oldSale.id!);
      await _softDeleteSaleAllocations(txn, oldSale.id!);
      await _softDeleteClientDebt(txn, oldSale);

      final allocationResult = await _allocateInventoryFIFO(txn, sale.units);
      final now = DateTime.now().toIso8601String();
      final profitAmount = sale.totalAmount - allocationResult.totalCost;

      final updatedSale = Sale(
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

      final data = updatedSale.toMap()..remove('id');
      data['is_synced'] = 0;
      await txn.update('sales', data, where: 'id = ?', whereArgs: [sale.id]);

      await _insertAllocations(txn, sale.id!, sale.syncId, allocationResult.allocations, now);
      await _createClientDebtIfNeeded(txn, updatedSale, sale.id!, now);
    });
  }

  Future<void> deleteSale(int id) async {
    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      final rows = await txn.query(
        'sales',
        where: 'id = ? AND is_deleted = 0',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return;

      final sale = Sale.fromMap(rows.first);
      await _restoreSaleInventory(txn, sale.id!);
      await _softDeleteSaleAllocations(txn, sale.id!);
      await _softDeleteClientDebt(txn, sale);

      await txn.update(
        'sales',
        {
          'is_deleted': 1,
          'is_synced': 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }
}

class _InventoryAllocationResult {
  final List<Map<String, dynamic>> allocations;
  final double totalCost;

  const _InventoryAllocationResult({
    required this.allocations,
    required this.totalCost,
  });
}
