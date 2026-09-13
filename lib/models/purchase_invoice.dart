class PurchaseInvoice {
  final int? id;
  final String invoiceNumber;
  final int supplierId;
  final DateTime purchaseDate;
  final double totalAmount;
  final String paymentStatus;
  final String? notes;
  final int createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final bool isSynced;
  final String syncId;

  PurchaseInvoice({
    this.id,
    required this.invoiceNumber,
    required this.supplierId,
    required this.purchaseDate,
    required this.totalAmount,
    required this.paymentStatus,
    this.notes,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.isSynced = false,
    required this.syncId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'supplier_id': supplierId,
      'purchase_date': purchaseDate.toIso8601String(),
      'total_amount': totalAmount,
      'payment_status': paymentStatus,
      'notes': notes,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_deleted': isDeleted ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
      'sync_id': syncId,
    };
  }

  factory PurchaseInvoice.fromMap(Map<String, dynamic> map) {
    return PurchaseInvoice(
      id: map['id'] as int?,
      invoiceNumber: map['invoice_number'] as String,
      supplierId: map['supplier_id'] as int,
      purchaseDate: DateTime.parse(map['purchase_date'] as String),
      totalAmount: (map['total_amount'] as num).toDouble(),
      paymentStatus: map['payment_status'] as String,
      notes: map['notes'] as String?,
      createdBy: map['created_by'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      isSynced: (map['is_synced'] as int? ?? 0) == 1,
      syncId: map['sync_id'] as String,
    );
  }
}
