class Payment {
  final int? id;
  final String syncId;
  final String paymentType; // client_payment / supplier_payment
  final int referenceId; // client_id or supplier_id
  final int? purchaseInvoiceId; // supplier payment can optionally target a purchase invoice
  final String paymentKey; // business idempotency key
  final double amount;
  final String? paymentMethod;
  final String? referenceNumber;
  final String paymentDate;
  final String? notes;
  final int createdBy;
  final String createdAt;
  final String updatedAt;
  final bool isDeleted;
  final bool isSynced;

  Payment({
    this.id,
    required this.syncId,
    required this.paymentType,
    required this.referenceId,
    this.purchaseInvoiceId,
    required this.paymentKey,
    required this.amount,
    this.paymentMethod,
    this.referenceNumber,
    required this.paymentDate,
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
      'payment_type': paymentType,
      'reference_id': referenceId,
      'purchase_invoice_id': purchaseInvoiceId,
      'payment_key': paymentKey,
      'amount': amount,
      'payment_method': paymentMethod,
      'reference_number': referenceNumber,
      'payment_date': paymentDate,
      'notes': notes,
      'created_by': createdBy,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_deleted': isDeleted ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory Payment.fromMap(Map<String, dynamic> map) {
    return Payment(
      id: map['id'],
      syncId: map['sync_id'] as String,
      paymentType: map['payment_type'] as String,
      referenceId: (map['reference_id'] as num).toInt(),
      purchaseInvoiceId: (map['purchase_invoice_id'] as num?)?.toInt(),
      paymentKey: (map['payment_key'] as String?) ?? 'legacy_payment_${map['id']}',
      amount: (map['amount'] as num).toDouble(),
      paymentMethod: map['payment_method'] as String?,
      referenceNumber: map['reference_number'] as String?,
      paymentDate: map['payment_date'] as String,
      notes: map['notes'] as String?,
      createdBy: (map['created_by'] as num).toInt(),
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
      isDeleted: (map['is_deleted'] as num? ?? 0).toInt() == 1,
      isSynced: (map['is_synced'] as num? ?? 0).toInt() == 1,
    );
  }
}
