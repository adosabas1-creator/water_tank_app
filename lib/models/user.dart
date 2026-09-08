import 'dart:convert';

class User {
  final int? id;
  final String username;
  final String passwordHash;
  final String fullName;
  final String role;
  final int? driverId;
  Map<String, bool> permissions;
  final String createdAt;
  final String updatedAt;

  User({
    this.id,
    required this.username,
    required this.passwordHash,
    required this.fullName,
    required this.role,
    this.driverId,
    required this.permissions,
    required this.createdAt,
    required this.updatedAt,
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
      'username': username,
      'password_hash': passwordHash,
      'full_name': fullName,
      'role': role,
      'driver_id': driverId,
      'permissions': permissionsToJson(permissions),
      'created_at': createdAt,
      'updated_at': updatedAt,
      'is_deleted': 0,
      'is_synced': 0,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      username: map['username'],
      passwordHash: map['password_hash'],
      fullName: map['full_name'],
      role: map['role'],
      driverId: map['driver_id'],
      permissions: permissionsFromJson(map['permissions']),
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
    );
  }
}
