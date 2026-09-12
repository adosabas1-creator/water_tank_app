class Sale {
  final int? id;
  final String syncId;
  final String? saleNumber;
  final int? clientId;
  final int? tankId;
  final int? driverId;
  final int supplierId;
  final int units;
  final double salePrice;
  final double totalAmount;
  final double costAmount;
  final double profitAmount;
  final String saleDate;
  final String paymentStatus; // paid, partial, unpaid
  final String? notes;
  final int createdBy;
  final String createdAt;
  final String updatedAt;
  final bool isDeleted;
  final bool isSynced;

  Sale({
    this.id,
    required this.syncId,
    this.saleNumber,
    this.clientId,
    this.tankId,
    this.driverId,
    required this.supplierId,
    required this.units,
    required this.salePrice,
    required this.totalAmount,
    required this.costAmount,
    required this.profitAmount,
    required this.saleDate,
    required this.paymentStatus,
    this.notes,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sync_id': syncId,
      'sale_number': saleNumber,
      'client_id': clientId,
      'tank_id': tankId,
      'driver_id': driverId,
      'supplier_id': supplierId,
      'units': units,
      'sale_price': salePrice,
      'total_amount': totalAmount,
      'cost_amount': costAmount,
      'profit_amount': profitAmount,
      'sale_date': saleDate,
      'payment_status': paymentStatus,
      'notes': notes,
      'created_by': createdBy,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_deleted': isDeleted ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory Sale.fromMap(Map<String, dynamic> map) {
    return Sale(
      id: map['id'],
      syncId: map['sync_id'] as String,
      saleNumber: map['sale_number'],
      clientId: map['client_id'],
      tankId: map['tank_id'],
      driverId: map['driver_id'],
      supplierId: map['supplier_id'],
      units: map['units'],
      salePrice: map['sale_price'],
      totalAmount: map['total_amount'],
      costAmount: map['cost_amount'],
      profitAmount: map['profit_amount'],
      saleDate: map['sale_date'],
      paymentStatus: map['payment_status'],
      notes: map['notes'],
      createdBy: map['created_by'],
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
      isDeleted: map['is_deleted'] == 1,
      isSynced: map['is_synced'] == 1,
    );
  }
}
