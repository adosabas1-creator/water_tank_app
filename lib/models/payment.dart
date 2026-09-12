class Payment {
  final int? id;
  final String syncId;
  final String paymentType; // client_payment / supplier_payment
  final int referenceId; // client_id or supplier_id
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
      paymentType: map['payment_type'],
      referenceId: map['reference_id'],
      amount: map['amount'],
      paymentMethod: map['payment_method'] as String?,
      referenceNumber: map['reference_number'] as String?,
      paymentDate: map['payment_date'],
      notes: map['notes'],
      createdBy: map['created_by'],
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
      isDeleted: map['is_deleted'] == 1,
      isSynced: map['is_synced'] == 1,
    );
  }
}
