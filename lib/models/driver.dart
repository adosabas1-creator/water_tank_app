class Driver {
  final int? id;
  final String name;
  final String? phone;
  final String? licenseNumber;
  final String? notes;
  final String createdAt;
  final String updatedAt;
  final bool isDeleted;
  final bool isSynced;

  Driver({
    this.id,
    required this.name,
    this.phone,
    this.licenseNumber,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'license_number': licenseNumber,
      'notes': notes,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_deleted': isDeleted ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory Driver.fromMap(Map<String, dynamic> map) {
    return Driver(
      id: map['id'],
      name: map['name'],
      phone: map['phone'],
      licenseNumber: map['license_number'],
      notes: map['notes'],
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
      isDeleted: map['is_deleted'] == 1,
      isSynced: map['is_synced'] == 1,
    );
  }
}
