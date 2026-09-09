import 'dart:convert';

class User {
  final int? id;
  final String syncId;
  final String? firebaseUid;
  final String? firebaseEmail;
  final String username;
  final String passwordHash;
  final String? recoveryCodeHash;
  final String fullName;
  final String role;
  final int? driverId;
  Map<String, bool> permissions;
  final String createdAt;
  final String updatedAt;
  final bool mustChangePassword;

  User({
    this.id,
    required this.syncId,
    this.firebaseUid,
    this.firebaseEmail,
    required this.username,
    required this.passwordHash,
    this.recoveryCodeHash,
    required this.fullName,
    required this.role,
    this.driverId,
    required this.permissions,
    required this.createdAt,
    required this.updatedAt,
    this.mustChangePassword = false,
  });

  static Map<String, bool> permissionsFromJson(String json) {
    final Map<String, dynamic> decoded = jsonDecode(json);
    return decoded.map((key, value) => MapEntry(key, value as bool));
  }

  static String permissionsToJson(Map<String, bool> permissions) {
    return jsonEncode(permissions);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sync_id': syncId,
      'firebase_uid': firebaseUid,
      'firebase_email': firebaseEmail,
      'username': username,
      'password_hash': passwordHash,
      'recovery_code_hash': recoveryCodeHash,
      'full_name': fullName,
      'role': role,
      'driver_id': driverId,
      'permissions': permissionsToJson(permissions),
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_deleted': 0,
      'is_synced': 0,
      'must_change_password': mustChangePassword ? 1 : 0,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      syncId: map['sync_id'],
      firebaseUid: map['firebase_uid'],
      firebaseEmail: map['firebase_email'],
      username: map['username'],
      passwordHash: map['password_hash'],
      recoveryCodeHash: map['recovery_code_hash'],
      fullName: map['full_name'],
      role: map['role'],
      driverId: map['driver_id'],
      permissions: permissionsFromJson(map['permissions']),
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
      mustChangePassword: (map['must_change_password'] ?? 0) == 1,
    );
  }
}
