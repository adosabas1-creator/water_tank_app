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
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<String?> signInToFirebase(String email, String password) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return credential.user?.uid;
  }

  Future<String?> createFirebaseUser(String email, String password) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = credential.user?.uid;
    await _firebaseAuth.signOut();
    return uid;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      throw ArgumentError('أدخل بريدًا إلكترونيًا صحيحًا');
    }
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: cleanEmail);
    } on firebase_auth.FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw StateError('هذا البريد غير مسجل في Firebase');
        case 'invalid-email':
          throw StateError('صيغة البريد الإلكتروني غير صحيحة');
        case 'operation-not-allowed':
          throw StateError('استعادة كلمة المرور عبر البريد غير مفعلة في Firebase');
        case 'network-request-failed':
          throw StateError('تعذر الاتصال بخدمة Firebase. تحقق من الإنترنت');
        case 'too-many-requests':
          throw StateError('تمت محاولات كثيرة. حاول مرة أخرى لاحقًا');
        default:
          throw StateError('تعذر إرسال رابط الاستعادة. رمز Firebase: ${e.code}');
      }
    }
  }

  Future<User?> login(String username, String password) async {
    final cleanUsername = username.trim();
    if (cleanUsername.isEmpty || password.isEmpty) return null;

    final db = await _dbHelper.database;
    final passwordHash = _hashPassword(password);
    final result = await db.query(
      'users',
      where: 'username = ? AND password_hash = ? AND is_deleted = 0',
      whereArgs: [cleanUsername, passwordHash],
      limit: 1,
    );

    if (result.isEmpty) return null;

    final user = User.fromMap(result.first);

    // Firebase is an optional secondary identity check. Local/offline login
    // remains supported by design, but a successful Firebase login refreshes
    // the stored UID when necessary.
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
            where: 'id = ? AND is_deleted = 0',
            whereArgs: [user.id],
          );
        }
      } catch (_) {
        // Offline/local-first authentication is intentional for this app.
      }
    }

    return user;
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
    final cleanUsername = username.trim();
    final cleanFullName = fullName.trim();
    final cleanEmail = firebaseEmail?.trim();

    if (cleanUsername.isEmpty) throw ArgumentError('اسم المستخدم مطلوب');
    if (cleanFullName.isEmpty) throw ArgumentError('الاسم الكامل مطلوب');
    if (password.length < 6) {
      throw ArgumentError('كلمة المرور يجب أن تكون 6 أحرف أو أرقام على الأقل');
    }
    if (role != 'admin' && role != 'deputy_manager' && role != 'member') {
      throw ArgumentError('الدور غير صالح');
    }

    final db = await _dbHelper.database;
    final duplicate = await db.query(
      'users',
      columns: ['id'],
      where: 'username = ? AND is_deleted = 0',
      whereArgs: [cleanUsername],
      limit: 1,
    );
    if (duplicate.isNotEmpty) {
      throw ArgumentError('اسم المستخدم مستخدم بالفعل');
    }

    String? firebaseUid;
    if (cleanEmail != null && cleanEmail.isNotEmpty) {
      firebaseUid = await createFirebaseUser(cleanEmail, password);
    }

    final now = DateTime.now().toIso8601String();
    final user = User(
      syncId: const Uuid().v4(),
      firebaseUid: firebaseUid,
      firebaseEmail: cleanEmail?.isEmpty == true ? null : cleanEmail,
      username: cleanUsername,
      passwordHash: _hashPassword(password),
      fullName: cleanFullName,
      role: role,
      driverId: driverId,
      permissions: permissions ?? _defaultPermissionsForRole(role),
      createdAt: now,
      updatedAt: now,
    );

    return db.insert('users', user.toMap());
  }

  Future<bool> updateUser({
    required int userId,
    required String username,
    required String fullName,
    required String role,
  }) async {
    final cleanUsername = username.trim();
    final cleanFullName = fullName.trim();
    if (cleanUsername.isEmpty) throw ArgumentError('اسم المستخدم مطلوب');
    if (cleanFullName.isEmpty) throw ArgumentError('الاسم الكامل مطلوب');
    if (role != 'admin' && role != 'deputy_manager' && role != 'member') {
      throw ArgumentError('الدور غير صالح');
    }

    final db = await _dbHelper.database;
    final duplicate = await db.query(
      'users',
      columns: ['id'],
      where: 'username = ? AND id != ? AND is_deleted = 0',
      whereArgs: [cleanUsername, userId],
      limit: 1,
    );
    if (duplicate.isNotEmpty) throw ArgumentError('اسم المستخدم مستخدم بالفعل');

    final count = await db.update(
      'users',
      {
        'username': cleanUsername,
        'full_name': cleanFullName,
        'role': role,
        'updated_at': DateTime.now().toIso8601String(),
        'is_synced': 0,
      },
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [userId],
    );
    return count > 0;
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
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [userId],
    );
  }

  Future<void> updatePermissions(int userId, Map<String, bool> newPermissions) async {
    final db = await _dbHelper.database;
    await db.update(
      'users',
      {
        'permissions': User.permissionsToJson(newPermissions),
        'updated_at': DateTime.now().toIso8601String(),
        'is_synced': 0,
      },
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [userId],
    );
  }

  Future<bool> updateUserPassword({
    required int userId,
    required String newPassword,
  }) async {
    if (newPassword.length < 6) {
      throw ArgumentError('كلمة المرور يجب أن تكون 6 أحرف أو أرقام على الأقل');
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

  Future<int> removeDefaultUsers() async {
    final db = await _dbHelper.database;
    return db.update(
      'users',
      {
        'is_deleted': 1,
        'is_synced': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: "username IN (${List.filled(10, '?').join(',')})",
      whereArgs: List.generate(10, (index) => 'مستخدم ${index + 1}'),
    );
  }

  Future<bool> setRecoveryCode({
    required int userId,
    required String recoveryCode,
  }) async {
    final code = recoveryCode.trim();
    if (code.length < 6) {
      throw ArgumentError('رمز الاسترداد يجب أن يكون 6 أحرف أو أرقام على الأقل');
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
      whereArgs: [username.trim(), _hashPassword(recoveryCode.trim())],
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
      whereArgs: [username.trim(), _hashPassword(recoveryCode.trim())],
      limit: 1,
    );
    if (result.isEmpty) return false;

    await db.update(
      'users',
      {
        'password_hash': _hashPassword(newPassword),
        'updated_at': DateTime.now().toIso8601String(),
        'is_synced': 0,
      },
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [result.first['id']],
    );
    return true;
  }

  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  Map<String, bool> _defaultPermissionsForRole(String role) {
    switch (role) {
      case 'admin':
        return DefaultPermissions.admin();
      case 'deputy_manager':
        return DefaultPermissions.deputyManager();
      case 'member':
        return DefaultPermissions.member();
      default:
        return DefaultPermissions.member();
    }
  }
}
