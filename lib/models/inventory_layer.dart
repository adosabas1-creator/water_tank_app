class InventoryLayer {
  final int? id;
  final int purchaseItemId;
  final String itemType;
  final int originalUnits;
  final int remainingUnits;
  final double unitCost;
  final DateTime layerDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final bool isSynced;
  final String syncId;

  InventoryLayer({
    this.id,
    required this.purchaseItemId,
    this.itemType = 'tank',
    required this.originalUnits,
    required this.remainingUnits,
    required this.unitCost,
    required this.layerDate,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.isSynced = false,
    required this.syncId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'purchase_item_id': purchaseItemId,
      'item_type': itemType,
      'original_units': originalUnits,
      'remaining_units': remainingUnits,
      'unit_cost': unitCost,
      'layer_date': layerDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
      'sync_id': syncId,
    };
  }

  factory InventoryLayer.fromMap(Map<String, dynamic> map) {
    return InventoryLayer(
      id: map['id'] as int?,
      purchaseItemId: map['purchase_item_id'] as int,
      itemType: map['item_type'] as String? ?? 'tank',
      originalUnits: map['original_units'] as int,
      remainingUnits: map['remaining_units'] as int,
      unitCost: (map['unit_cost'] as num).toDouble(),
      layerDate: DateTime.parse(map['layer_date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      isSynced: (map['is_synced'] as int? ?? 0) == 1,
      syncId: map['sync_id'] as String,
    );
  }
}
