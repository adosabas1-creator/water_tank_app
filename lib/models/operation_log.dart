class OperationLog {
  final int? id;
  final String? syncId;
  final int userId;
  final String? userSyncId;
  final String action;
  final String tableName;
  final int recordId;
  final String? recordSyncId;
  final String? details;
  final String timestamp;
  final String? createdAt;
  final String? updatedAt;
  final int isDeleted;
  final int isSynced;

  OperationLog({
    this.id,
    this.syncId,
    required this.userId,
    this.userSyncId,
    required this.action,
    required this.tableName,
    required this.recordId,
    this.recordSyncId,
    this.details,
    required this.timestamp,
    this.createdAt,
    this.updatedAt,
    this.isDeleted = 0,
    this.isSynced = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sync_id': syncId,
      'user_id': userId,
      'user_sync_id': userSyncId,
      'action': action,
      'table_name': tableName,
      'record_id': recordId,
      'record_sync_id': recordSyncId,
      'details': details,
      'timestamp': timestamp,
      'created_at': createdAt ?? timestamp,
      'updated_at': updatedAt ?? timestamp,
      'is_deleted': isDeleted,
      'is_synced': isSynced,
    };
  }

  factory OperationLog.fromMap(Map<String, dynamic> map) {
    return OperationLog(
      id: (map['id'] as num?)?.toInt(),
      syncId: map['sync_id']?.toString(),
      userId: (map['user_id'] as num).toInt(),
      userSyncId: map['user_sync_id']?.toString(),
      action: map['action']?.toString() ?? '',
      tableName: map['table_name']?.toString() ?? '',
      recordId: (map['record_id'] as num).toInt(),
      recordSyncId: map['record_sync_id']?.toString(),
      details: map['details']?.toString(),
      timestamp: map['timestamp']?.toString() ?? '',
      createdAt: map['created_at']?.toString(),
      updatedAt: map['updated_at']?.toString(),
      isDeleted: (map['is_deleted'] as num?)?.toInt() ?? 0,
      isSynced: (map['is_synced'] as num?)?.toInt() ?? 0,
    );
  }
}
