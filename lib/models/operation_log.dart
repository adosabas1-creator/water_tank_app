class OperationLog {
  final int? id;
  final int userId;
  final String action;
  final String tableName;
  final int recordId;
  final String? details;
  final String timestamp;

  OperationLog({
    this.id,
    required this.userId,
    required this.action,
    required this.tableName,
    required this.recordId,
    this.details,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'action': action,
      'table_name': tableName,
      'record_id': recordId,
      'details': details,
      'timestamp': timestamp,
    };
  }

  factory OperationLog.fromMap(Map<String, dynamic> map) {
    return OperationLog(
      id: map['id'],
      userId: map['user_id'],
      action: map['action'],
      tableName: map['table_name'],
      recordId: map['record_id'],
      details: map['details'],
      timestamp: map['timestamp'],
    );
  }
}
