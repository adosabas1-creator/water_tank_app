class Supplier {
  final int? id;
  final String syncId;
  final String? supplierNumber;
  final String name;
  final String? phone;
  final String? location;
  final String status; // active / inactive
  final String? notes;
  final String createdAt;
  final String updatedAt;
  final bool isDeleted;
  final bool isSynced;

  Supplier({
    this.id,
    required this.syncId,
    this.supplierNumber,
    required this.name,
    this.phone,
    this.location,
    this.status = 'active',
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sync_id': syncId,
      'supplier_number': supplierNumber,
      'name': name,
      'phone': phone,
      'location': location,
      'status': status,
      'notes': notes,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_deleted': isDeleted ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      id: map['id'],
      syncId: map['sync_id'] as String,
      supplierNumber: map['supplier_number'],
      name: map['name'],
      phone: map['phone'],
      location: map['location'],
      status: map['status'] ?? 'active',
      notes: map['notes'],
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
      isDeleted: map['is_deleted'] == 1,
      isSynced: map['is_synced'] == 1,
    );
  }
}
