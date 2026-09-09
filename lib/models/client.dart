class Client {
  final int? id;
  final String syncId;
  final String? clientNumber;
  final String name;
  final String? phone;
  final String? address;
  final String? notes;
  final String createdAt;
  final String updatedAt;
  final bool isDeleted;
  final bool isSynced;

  Client({
    this.id,
    required this.syncId,
    this.clientNumber,
    required this.name,
    this.phone,
    this.address,
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
      'client_number': clientNumber,
      'name': name,
      'phone': phone,
      'address': address,
      'notes': notes,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_deleted': isDeleted ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: map['id'],
      syncId: map['sync_id'] as String,
      clientNumber: map['client_number'],
      name: map['name'],
      phone: map['phone'],
      address: map['address'],
      notes: map['notes'],
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
      isDeleted: map['is_deleted'] == 1,
      isSynced: map['is_synced'] == 1,
    );
  }
}
