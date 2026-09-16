class AccountTransaction {
  final int? id;
  final String accountType; // client أو supplier
  final int referenceId;
  final int? purchaseInvoiceId;
  final double amount;
  final String transactionType; // opening_balance أو debt أو adjustment
  final String transactionDate;
  final String? notes;
  final int createdBy;
  final String createdAt;
  final String updatedAt;
  final bool isDeleted;
  final bool isSynced;
  final String syncId;

  const AccountTransaction({
    this.id,
    required this.accountType,
    required this.referenceId,
    this.purchaseInvoiceId,
    required this.amount,
    required this.transactionType,
    required this.transactionDate,
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
      'account_type': accountType,
      'reference_id': referenceId,
      'purchase_invoice_id': purchaseInvoiceId,
      'amount': amount,
      'transaction_type': transactionType,
      'transaction_date': transactionDate,
      'notes': notes,
      'created_by': createdBy,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_deleted': isDeleted ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
      'sync_id': syncId,
    };
  }

  factory AccountTransaction.fromMap(Map<String, dynamic> map) {
    return AccountTransaction(
      id: map['id'] as int?,
      accountType: map['account_type'] as String,
      referenceId: (map['reference_id'] as num).toInt(),
      purchaseInvoiceId: (map['purchase_invoice_id'] as num?)?.toInt(),
      amount: (map['amount'] as num).toDouble(),
      transactionType: map['transaction_type'] as String,
      transactionDate: map['transaction_date'] as String,
      notes: map['notes'] as String?,
      createdBy: (map['created_by'] as num).toInt(),
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
      isDeleted: (map['is_deleted'] as num? ?? 0).toInt() == 1,
      isSynced: (map['is_synced'] as num? ?? 0).toInt() == 1,
      syncId: map['sync_id'] as String,
    );
  }

  AccountTransaction copyWith({
    int? id,
    String? accountType,
    int? referenceId,
    int? purchaseInvoiceId,
    double? amount,
    String? transactionType,
    String? transactionDate,
    String? notes,
    int? createdBy,
    String? createdAt,
    String? updatedAt,
    bool? isDeleted,
    bool? isSynced,
    String? syncId,
  }) {
    return AccountTransaction(
      id: id ?? this.id,
      accountType: accountType ?? this.accountType,
      referenceId: referenceId ?? this.referenceId,
      purchaseInvoiceId: purchaseInvoiceId ?? this.purchaseInvoiceId,
      amount: amount ?? this.amount,
      transactionType: transactionType ?? this.transactionType,
      transactionDate: transactionDate ?? this.transactionDate,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      isSynced: isSynced ?? this.isSynced,
      syncId: syncId ?? this.syncId,
    );
  }
}
