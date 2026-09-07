class FillingOperation {
  final int? id;
  final String? operationNumber;
  final int tankId;
  final int supplierId;
  final int units;
  final double purchasePrice;
  final String operationDate;
  final int? employeeId;
  final String? notes;
  final int createdBy;
  final String createdAt;
  final String updatedAt;
  final bool isDeleted;
  final bool isSynced;

  FillingOperation({
    this.id,
    this.operationNumber,
    required this.tankId,
    required this.supplierId,
    required this.units,
    required this.purchasePrice,
    required this.operationDate,
    this.employeeId,
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
      'operation_number': operationNumber,
      'tank_id': tankId,
      'supplier_id': supplierId,
      'units': units,
      'purchase_price': purchasePrice,
      'operation_date': operationDate,
      'employee_id': employeeId,
      'notes': notes,
      'created_by': createdBy,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_deleted': isDeleted ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory FillingOperation.fromMap(Map<String, dynamic> map) {
    return FillingOperation(
      id: map['id'],
      operationNumber: map['operation_number'],
      tankId: map['tank_id'],
      supplierId: map['supplier_id'],
      units: map['units'],
      purchasePrice: map['purchase_price'],
      operationDate: map['operation_date'],
      employeeId: map['employee_id'],
      notes: map['notes'],
      createdBy: map['created_by'],
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
      isDeleted: map['is_deleted'] == 1,
      isSynced: map['is_synced'] == 1,
    );
  }
}
