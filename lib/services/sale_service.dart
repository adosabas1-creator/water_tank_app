import '../core/database/database_helper.dart';
import '../models/account_transaction.dart';
import '../models/sale.dart';

class SaleService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<Sale> addSale(Sale sale) async {
    final db = await _dbHelper.database;

    return await db.transaction((txn) async {
      final requestedUnits = sale.units;

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
        (sum, layer) => sum + ((layer['remaining_units'] as int?) ?? 0),
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
        if (remainingToConsume <= 0) {
          break;
        }

        final layerId = layer['id'] as int;
        final purchaseItemId = layer['purchase_item_id'] as int;
        final remainingUnits = layer['remaining_units'] as int;
        final unitCost = (layer['unit_cost'] as num).toDouble();

        final consumedUnits = remainingToConsume < remainingUnits
            ? remainingToConsume
            : remainingUnits;

        final costAmount = consumedUnits * unitCost;
        final newRemainingUnits = remainingUnits - consumedUnits;

        await txn.update(
          'inventory_layers',
          {
            'remaining_units': newRemainingUnits,
            'updated_at': now,
            'is_synced': 0,
          },
          where: 'id = ?',
          whereArgs: [layerId],
        );

        final purchaseItem = await txn.query(
          'purchase_items',
          columns: ['purchase_invoice_id'],
          where: 'id = ?',
          whereArgs: [purchaseItemId],
          limit: 1,
        );

        if (purchaseItem.isEmpty) {
          throw Exception(
            'تعذر العثور على صنف الشراء المرتبط بطبقة المخزون.',
          );
        }

        final purchaseInvoiceId =
            purchaseItem.first['purchase_invoice_id'] as int;

        final purchaseInvoice = await txn.query(
          'purchase_invoices',
          columns: ['supplier_id'],
          where: 'id = ?',
          whereArgs: [purchaseInvoiceId],
          limit: 1,
        );

        if (purchaseInvoice.isEmpty) {
          throw Exception(
            'تعذر العثور على فاتورة الشراء المرتبطة بطبقة المخزون.',
          );
        }

        final supplierId = purchaseInvoice.first['supplier_id'] as int;

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

      if (remainingToConsume > 0) {
        throw Exception('تعذر إكمال استهلاك المخزون بطريقة FIFO.');
      }

      final profitAmount = sale.totalAmount - totalCost;

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
        costAmount: totalCost,
        profitAmount: profitAmount,
        saleDate: sale.saleDate,
        paymentStatus: sale.paymentStatus,
        clientPaymentStatus: sale.clientPaymentStatus,
        supplierPaymentStatus: sale.supplierPaymentStatus,
        createdByName: sale.createdByName,
        notes: sale.notes,
        createdBy: sale.createdBy,
        createdAt: sale.createdAt,
        updatedAt: sale.updatedAt,
        isDeleted: sale.isDeleted,
        isSynced: sale.isSynced,
      );

      final saleId = await txn.insert(
        'sales',
        calculatedSale.toMap()..remove('id'),
      );

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
            'sync_id':
                'sale_alloc_${sale.syncId}_${allocation['inventory_layer_id']}',
          },
        );
      }

      if (sale.clientId != null && sale.clientPaymentStatus == 'unpaid') {
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
