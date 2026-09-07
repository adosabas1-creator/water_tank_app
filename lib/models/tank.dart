class Tank {
  final int? id;
  final String tankNumber;
  final int capacityUnits;
  final int? driverId;
  final String? notes;
  final String createdAt;
  final String updatedAt;
  final bool isDeleted;
  final bool isSynced;

  Tank({
    this.id,
    required this.tankNumber,
    required this.capacityUnits,
    this.driverId,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tank_number': tankNumber,
      'capacity_units': capacityUnits,
      'driver_id': driverId,
      'notes': notes,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_deleted': isDeleted ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory Tank.fromMap(Map<String, dynamic> map) {
    return Tank(
      id: map['id'],
      tankNumber: map['tank_number'],
      capacityUnits: map['capacity_units'],
      driverId: map['driver_id'],
      notes: map['notes'],
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
      isDeleted: map['is_deleted'] == 1,
      isSynced: map['is_synced'] == 1,
    );
  }
}
