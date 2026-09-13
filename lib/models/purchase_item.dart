class PurchaseItem {
  final int? id;
  final int purchaseInvoiceId;
  final String itemType;
  final int units;
  final double purchasePrice;
  final double totalAmount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final bool isSynced;
  final String syncId;

  PurchaseItem({
    this.id,
    required this.purchaseInvoiceId,
    this.itemType = 'tank',
    required this.units,
    required this.purchasePrice,
    required this.totalAmount,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.isSynced = false,
    required this.syncId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'purchase_invoice_id': purchaseInvoiceId,
      'item_type': itemType,
      'units': units,
      'purchase_price': purchasePrice,
      'total_amount': totalAmount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
      'sync_id': syncId,
    };
  }

  factory PurchaseItem.fromMap(Map<String, dynamic> map) {
    return PurchaseItem(
      id: map['id'] as int?,
      purchaseInvoiceId: map['purchase_invoice_id'] as int,
      itemType: map['item_type'] as String? ?? 'tank',
      units: map['units'] as int,
      purchasePrice: (map['purchase_price'] as num).toDouble(),
      totalAmount: (map['total_amount'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      isSynced: (map['is_synced'] as int? ?? 0) == 1,
      syncId: map['sync_id'] as String,
    );
  }
}
