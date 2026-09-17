import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import '../database/database_helper.dart';
import '../../models/user.dart';
import '../constants/permissions.dart';
import 'permission_service.dart';

class AuthService {
  final firebase_auth.FirebaseAuth _firebaseAuth =
      firebase_auth.FirebaseAuth.instance;
  final DatabaseHelper _dbHelper = DatabaseHelper();
final FirebaseFirestore _firestore = FirebaseFirestore.instance;
static const String _businessId = 'alborai_water_tank';
  Future<firebase_auth.FirebaseAuth> _secondaryAuth() async {
    const appName = 'water_tank_secondary_auth';

    FirebaseApp app;
    try {
      app = Firebase.app(appName);
    } catch (_) {
      app = await Firebase.initializeApp(
        name: appName,
        options: Firebase.app().options,
      );
    }

    return firebase_auth.FirebaseAuth.instanceFor(app: app);
  }



  Future<void> _publishLoginDirectory(
      User user, {
        bool isDeleted = false,
      }) async {
    final username = user.username.trim();
    final email = user.firebaseEmail?.trim() ?? '';
    final uid = user.firebaseUid?.trim() ?? '';

    if (username.isEmpty || email.isEmpty || uid.isEmpty) {
      throw StateError('بيانات دليل تسجيل الدخول غير مكتملة');
    }

    await _firestore
        .collection('businesses')
        .doc(_businessId)
        .collection('login_directory')
        .doc(uid)
        .set({
      'username': username,
      'firebase_email': email,
      'firebase_uid': uid,
      'is_deleted': isDeleted,
      'updated_at': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  Future<void> _publishUserDirectory(User user, {bool isDeleted = false}) async {
    final data = <String, dynamic>{
      'sync_id': user.syncId,
      'firebase_uid': user.firebaseUid,
      'firebase_email': user.firebaseEmail,
      'username': user.username,
      'full_name': user.fullName,
      'role': user.role,
      'driver_id': user.driverId,
      'permissions': user.permissions,
      'created_at': user.createdAt,
      'updated_at': user.updatedAt,
      'must_change_password': user.mustChangePassword,
      'is_deleted': isDeleted,
    };

    final uid = user.firebaseUid;
    if (uid == null || uid.isEmpty) {
      throw StateError('لا يمكن نشر المستخدم: Firebase UID غير موجود');
    }

    if (_firebaseAuth.currentUser == null) {
      throw StateError(
        'المدير غير مسجل دخول في Firebase. أعد تسجيل الدخول بالإنترنت ثم حاول مرة أخرى.',
      );
    }

    await _firestore
        .collection('businesses')
        .doc(_businessId)
        .collection('user_directory')
        .doc(uid)
        .set(data, SetOptions(merge: true));
  }

  Future<String?> signInToFirebase(String email, String password) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return credential.user?.uid;
  }

  Future<String> createFirebaseUser(String email, String password) async {
    final secondaryAuth = await _secondaryAuth();

    try {
      final credential =
          await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = credential.user?.uid;

      if (uid == null || uid.isEmpty) {
        throw StateError(
          "تعذر الحصول على معرف Firebase للمستخدم",
        );
      }

      return uid;
    } finally {
      await secondaryAuth.signOut();
    }
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

    // 1. Local login: keeps the app usable offline.
    final result = await db.query(
      'users',
      where: 'username = ? AND password_hash = ? AND is_deleted = 0',
      whereArgs: [cleanUsername, passwordHash],
      limit: 1,
    );

    if (result.isNotEmpty) {
      final user = User.fromMap(result.first);

      if (user.firebaseEmail != null && user.firebaseEmail!.isNotEmpty) {
        try {
          final credential = await _firebaseAuth.signInWithEmailAndPassword(
            email: user.firebaseEmail!.trim(),
            password: password,
          );

          final firebaseUid = credential.user?.uid;
          if (firebaseUid != null && firebaseUid.isNotEmpty) {
            final userDoc = await _firestore
                .collection('businesses')
                .doc(_businessId)
                .collection('user_directory')
                .doc(firebaseUid)
                .get();

            if (userDoc.exists) {
              final remote = userDoc.data();

              if (remote != null && remote['is_deleted'] != true) {
                final permissions = <String, bool>{};
                final rawPermissions = remote['permissions'];

                if (rawPermissions is Map) {
                  rawPermissions.forEach((key, value) {
                    permissions[key.toString()] = value == true;
                  });
                }

                await db.update(
                  'users',
                  {
                    'firebase_uid': firebaseUid,
                    'firebase_email': remote['firebase_email']?.toString() ??
                        user.firebaseEmail,
                    'username':
                        remote['username']?.toString() ?? user.username,
                    'full_name':
                        remote['full_name']?.toString() ?? user.fullName,
                    'role': remote['role']?.toString() ?? user.role,
                    'permissions': User.permissionsToJson(permissions),
                    'must_change_password':
                        remote['must_change_password'] == true ? 1 : 0,
                    'updated_at': DateTime.now().toIso8601String(),
                    'is_synced': 0,
                  },
                  where: 'id = ? AND is_deleted = 0',
                  whereArgs: [user.id],
                );
              }
            }
          }
        } on firebase_auth.FirebaseAuthException catch (e) {
          // Allow local login only when Firebase is unreachable.
          if (e.code == 'network-request-failed') {
            // Offline mode: continue with the local account.
          } else {
            switch (e.code) {
              case 'invalid-credential':
              case 'wrong-password':
              case 'user-not-found':
                throw StateError('بيانات تسجيل الدخول إلى Firebase غير صحيحة');
              case 'user-disabled':
                throw StateError('هذا الحساب معطل في Firebase');
              case 'too-many-requests':
                throw StateError('تمت محاولات كثيرة. حاول مرة أخرى لاحقًا');
              default:
                throw StateError(
                  'تعذر تسجيل الدخول إلى Firebase. رمز الخطأ: ${e.code}',
                );
            }
          }
        }
      }

      return user;
    }

    // 2. New device: bootstrap login from the public login directory.
    // The device does not have a local account yet, so it cannot read
    // the protected user_directory until Firebase authentication succeeds.
    try {
      final directorySnapshot = await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('login_directory')
          .where('username', isEqualTo: cleanUsername)
          .limit(1)
          .get();

      if (directorySnapshot.docs.isEmpty) return null;

      final directory = directorySnapshot.docs.first.data();

      if (directory['is_deleted'] == true) return null;

      final email = directory['firebase_email']?.toString().trim() ?? '';
      if (email.isEmpty) return null;

      // Authenticate first. After this succeeds, protected Firestore
      // collections such as user_directory become readable.
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final firebaseUid = credential.user?.uid;
      if (firebaseUid == null || firebaseUid.isEmpty) return null;

      // Now read the protected user profile containing role and permissions.
      final userDoc = await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('user_directory')
          .doc(firebaseUid)
          .get();

      if (!userDoc.exists) return null;

      final remote = userDoc.data();
      if (remote == null || remote['is_deleted'] == true) return null;

      final permissions = <String, bool>{};
      final rawPermissions = remote['permissions'];

      if (rawPermissions is Map) {
        rawPermissions.forEach((key, value) {
          permissions[key.toString()] = value == true;
        });
      }

      final now = DateTime.now().toIso8601String();

      final user = User(
        syncId: remote['sync_id']?.toString().isNotEmpty == true
            ? remote['sync_id'].toString()
            : const Uuid().v4(),
        firebaseUid: firebaseUid,
        firebaseEmail: email,
        username: remote['username']?.toString() ?? cleanUsername,
        passwordHash: passwordHash,
        recoveryCodeHash: null,
        fullName: remote['full_name']?.toString() ?? cleanUsername,
        role: remote['role']?.toString() ?? 'member',

        // Do not reuse the old device's local driver ID.
        // Local IDs are different on different phones.
        driverId: null,

        permissions: permissions,
        createdAt: remote['created_at']?.toString() ?? now,
        updatedAt: remote['updated_at']?.toString() ?? now,
        mustChangePassword: remote['must_change_password'] == true,
      );

      final localId = await db.insert(
        'users',
        user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      return User.fromMap({
        ...user.toMap(),
        'id': localId,
      });
    } on firebase_auth.FirebaseAuthException {
      return null;
    } catch (_) {
      return null;
    }
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
    PermissionService.requirePermission(PermissionKeys.usersManage);
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

    if (cleanEmail == null || cleanEmail.isEmpty) {
      throw ArgumentError('بريد Firebase مطلوب');
    }

    final emailRegex = RegExp(
      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
    );

    if (!emailRegex.hasMatch(cleanEmail)) {
      throw ArgumentError('بريد Firebase غير صالح');
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

    final duplicateEmail = await db.query(
      'users',
      columns: ['id'],
      where: 'LOWER(firebase_email) = LOWER(?) AND is_deleted = 0',
      whereArgs: [cleanEmail],
      limit: 1,
    );

    if (duplicateEmail.isNotEmpty) {
      throw ArgumentError('بريد Firebase مستخدم بالفعل');
    }

    final firebaseUid = await createFirebaseUser(cleanEmail, password);

    final now = DateTime.now().toIso8601String();
    final user = User(
      syncId: const Uuid().v4(),
      firebaseUid: firebaseUid,
      firebaseEmail: cleanEmail,
      username: cleanUsername,
      passwordHash: _hashPassword(password),
      fullName: cleanFullName,
      role: role,
      driverId: driverId,
      permissions: permissions ?? _defaultPermissionsForRole(role),
      createdAt: now,
      updatedAt: now,
    );

    final localId = await db.insert('users', user.toMap());

    try {
      await _publishUserDirectory(user);
      await _publishLoginDirectory(user);
    } catch (e) {
      await db.delete(
        'users',
        where: 'id = ?',
        whereArgs: [localId],
      );
      rethrow;
    }

    return localId;
  }

  Future<bool> updateUser({
    required int userId,
    required String username,
    required String fullName,
    required String role,
  }) async {
    PermissionService.requirePermission(PermissionKeys.usersManage);
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

    if (count == 0) return false;

    final rows = await db.query(
      'users',
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [userId],
      limit: 1,
    );

    if (rows.isEmpty) return false;

    await _publishUserDirectory(User.fromMap(rows.first));
    return true;
  }

  Future<void> updateDriver(int userId, int? driverId) async {
    PermissionService.requirePermission(PermissionKeys.usersManage);
    final db = await _dbHelper.database;

    final count = await db.update(
      'users',
      {
        'driver_id': driverId,
        'updated_at': DateTime.now().toIso8601String(),
        'is_synced': 0,
      },
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [userId],
    );

    if (count == 0) return;

    final rows = await db.query(
      'users',
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [userId],
      limit: 1,
    );

    if (rows.isEmpty) return;

    await _publishUserDirectory(User.fromMap(rows.first));
  }

  Future<void> updatePermissions(int userId, Map<String, bool> newPermissions) async {
    PermissionService.requirePermission(PermissionKeys.permissionsManage);
    final db = await _dbHelper.database;
    final count = await db.update(
      'users',
      {
        'permissions': User.permissionsToJson(newPermissions),
        'updated_at': DateTime.now().toIso8601String(),
        'is_synced': 0,
      },
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [userId],
    );

    if (count == 0) return;

    final rows = await db.query(
      'users',
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [userId],
      limit: 1,
    );

    if (rows.isEmpty) return;

    await _publishUserDirectory(User.fromMap(rows.first));
  }

  Future<bool> updateUserPassword({
    required int userId,
    required String newPassword,
  }) async {
    PermissionService.requireAdmin();

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
    PermissionService.requirePermission(PermissionKeys.usersManage);
    final db = await _dbHelper.database;

    final usernames = List.generate(10, (index) => 'مستخدم ${index + 1}');
    final placeholders = List.filled(usernames.length, '?').join(',');

    final rows = await db.query(
      'users',
      where: "username IN ($placeholders) AND is_deleted = 0",
      whereArgs: usernames,
    );

    if (rows.isEmpty) return 0;

    final now = DateTime.now().toIso8601String();

    final count = await db.update(
      'users',
      {
        'is_deleted': 1,
        'is_synced': 0,
        'updated_at': now,
      },
      where: "username IN ($placeholders) AND is_deleted = 0",
      whereArgs: usernames,
    );

    for (final row in rows) {
      final user = User.fromMap({
        ...row,
        'is_deleted': 1,
        'updated_at': now,
        'is_synced': 0,
      });

      if (user.firebaseUid != null && user.firebaseUid!.isNotEmpty) {
        await _publishUserDirectory(user, isDeleted: true);
      }
    }

    return count;
  }

  Future<bool> setRecoveryCode({
    required int userId,
    required String recoveryCode,
  }) async {
    PermissionService.requirePermission(PermissionKeys.usersManage);
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