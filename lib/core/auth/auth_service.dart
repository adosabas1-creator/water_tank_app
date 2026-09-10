import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'dart:convert';
import '../database/database_helper.dart';
import '../../models/user.dart';
import '../constants/permissions.dart';

class AuthService {
  final firebase_auth.FirebaseAuth _firebaseAuth =
      firebase_auth.FirebaseAuth.instance;

  Future<String?> signInToFirebase(
    String email,
    String password,
  ) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return credential.user?.uid;
  }

  Future<String?> createFirebaseUser(
    String email,
    String password,
  ) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = credential.user?.uid;
    await _firebaseAuth.signOut();
    return uid;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _firebaseAuth.sendPasswordResetEmail(
      email: email.trim(),
    );
  }

  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<User?> login(String username, String password) async {
    final db = await _dbHelper.database;
    final passwordHash = _hashPassword(password);
    final result = await db.query(
      'users',
      where: 'username = ? AND password_hash = ?',
      whereArgs: [username, passwordHash],
    );
    if (result.isNotEmpty) {
      final user = User.fromMap(result.first);

      if (user.firebaseEmail != null && user.firebaseEmail!.isNotEmpty) {
        try {
          final credential = await _firebaseAuth.signInWithEmailAndPassword(
            email: user.firebaseEmail!.trim(),
            password: password,
          );

          if (credential.user?.uid != null &&
              user.firebaseUid != credential.user!.uid) {
            await db.update(
              'users',
              {
                'firebase_uid': credential.user!.uid,
                'updated_at': DateTime.now().toIso8601String(),
                'is_synced': 0,
              },
              where: 'id = ?',
              whereArgs: [user.id],
            );
          }
        } catch (_) {
          // فشل Firebase لا يمنع تسجيل الدخول المحلي.
        }
      }

      return user;
    }
    return null;
  }

  Future<int> createUser({
    required String username,
    required String password,
    String? firebaseEmail,
    required String fullName,
    required String role,
    int? driverId,
    Map<String, bool>? permissions,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    final cleanEmail = firebaseEmail?.trim();

    String? firebaseUid;
    if (cleanEmail != null && cleanEmail.isNotEmpty) {
      firebaseUid = await createFirebaseUser(cleanEmail, password);
    }

    final user = User(
      syncId: const Uuid().v4(),
      firebaseUid: firebaseUid,
      firebaseEmail: cleanEmail?.isEmpty == true ? null : cleanEmail,
      username: username,
      passwordHash: _hashPassword(password),
      fullName: fullName,
      role: role,
      driverId: driverId,
      permissions: permissions ?? _defaultPermissionsForRole(role),
      createdAt: now,
      updatedAt: now,
    );

    return await db.insert('users', user.toMap());
  }

  Future<void> updateDriver(int userId, int? driverId) async {
    final db = await _dbHelper.database;

    await db.update(
      'users',
      {
        'driver_id': driverId,
        'updated_at': DateTime.now().toIso8601String(),
        'is_synced': 0,
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> updatePermissions(
      int userId, Map<String, bool> newPermissions) async {
    final db = await _dbHelper.database;
    await db.update(
      'users',
      {
        'permissions': User.permissionsToJson(newPermissions),
        'updated_at': DateTime.now().toIso8601String(),
        'is_synced': 0,
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<bool> updateUserPassword({
    required int userId,
    required String newPassword,
  }) async {
    if (newPassword.length < 6) {
      throw ArgumentError(
        'كلمة المرور يجب أن تكون 6 أحرف أو أرقام على الأقل',
      );
    }

    final db = await _dbHelper.database;
    final count = await db.update(
      'users',
      {
        'password_hash': _hashPassword(newPassword),
        'must_change_password': 0,
        'updated_at': DateTime.now().toIso8601String(),
        'is_synced': 0,
      },
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [userId],
    );

    return count > 0;
  }

  Future<List<User>> getAllUsers() async {
    final db = await _dbHelper.database;
    final result = await db.query('users', where: 'is_deleted = 0');
    return result.map((e) => User.fromMap(e)).toList();
  }

  Future<bool> setRecoveryCode({
    required int userId,
    required String recoveryCode,
  }) async {
    final code = recoveryCode.trim();

    if (code.length < 6) {
      throw ArgumentError(
          'رمز الاسترداد يجب أن يكون 6 أحرف أو أرقام على الأقل');
    }

    final db = await _dbHelper.database;

    final count = await db.update(
      'users',
      {
        'recovery_code_hash': _hashPassword(code),
        'updated_at': DateTime.now().toIso8601String(),
        'is_synced': 0,
      },
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [userId],
    );

    return count > 0;
  }

  Future<bool> verifyRecoveryCode({
    required String username,
    required String recoveryCode,
  }) async {
    final db = await _dbHelper.database;

    final result = await db.query(
      'users',
      columns: ['id'],
      where: 'username = ? AND recovery_code_hash = ? AND is_deleted = 0',
      whereArgs: [
        username.trim(),
        _hashPassword(recoveryCode.trim()),
      ],
      limit: 1,
    );

    return result.isNotEmpty;
  }

  Future<bool> resetPasswordWithRecoveryCode({
    required String username,
    required String recoveryCode,
    required String newPassword,
  }) async {
    if (newPassword.length < 6) {
      throw ArgumentError('كلمة المرور يجب أن تكون 6 أحرف أو أرقام على الأقل');
    }

    final db = await _dbHelper.database;

    final result = await db.query(
      'users',
      columns: ['id'],
      where: 'username = ? AND recovery_code_hash = ? AND is_deleted = 0',
      whereArgs: [
        username.trim(),
        _hashPassword(recoveryCode.trim()),
      ],
      limit: 1,
    );

    if (result.isEmpty) {
      return false;
    }

    await db.update(
      'users',
      {
        'password_hash': _hashPassword(newPassword),
        'updated_at': DateTime.now().toIso8601String(),
        'is_synced': 0,
      },
      where: 'id = ?',
      whereArgs: [result.first['id']],
    );

    return true;
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Map<String, bool> _defaultPermissionsForRole(String role) {
    switch (role) {
      case 'admin':
        return DefaultPermissions.admin();

      case 'deputy_manager':
        return DefaultPermissions.deputyManager();

      case 'driver':
        return DefaultPermissions.driver();

      default:
        return DefaultPermissions.driver();
    }
  }
}
