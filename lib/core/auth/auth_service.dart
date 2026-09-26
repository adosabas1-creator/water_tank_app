import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart' as crypto2;
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:async';
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

  // ✅ البريد المركزي لـ aliases (كل الرسائل تصل إليه)
  static const String _masterEmailPrefix = 'adosabas1';
  static const String _masterEmailDomain = 'gmail.com';

  /// يولّد بريدًا بديلًا (alias) لـ Gmail المركزي
  /// مثال: "ahmed" → adosabas1+ahmed@gmail.com
  /// كل الرسائل على هذه العناوين تصل إلى adosabas1@gmail.com
  String _generateAliasEmail(String username) {
    // تنظيف اسم المستخدم ليصلح كـ alias (a-z, 0-9, _)
    final safe = username
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .toLowerCase();

    final finalName =
        safe.isEmpty ? 'user_${DateTime.now().millisecondsSinceEpoch}' : safe;

    return '$_masterEmailPrefix+$finalName@$_masterEmailDomain';
  }
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

    // ✅ استخدام username كمعرّف للمستند (بدل uid)
    // السبب: عند تسجيل الدخول من جهاز جديد، السائق يعرف username فقط
    // وليس uid. استخدام username كمعرّف يسمح بـ `.doc(username).get()`
    // بدل `.where('username', ...).get()` التي تحتاج صلاحية list.
    await _firestore
        .collection('businesses')
        .doc(_businessId)
        .collection('login_directory')
        .doc(username)
        .set({
      'username': username,
      'firebase_email': email,
      'firebase_uid': uid,
      'is_deleted': isDeleted,
      'updated_at': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }

  /// يحذف مستند دليل تسجيل الدخول القديم عند تغيير اسم المستخدم
  Future<void> _deleteLoginDirectoryByUsername(String username) async {
    if (username.trim().isEmpty) return;
    try {
      await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('login_directory')
          .doc(username.trim())
          .delete();
    } catch (_) {
      // نتجاهل الأخطاء - قد لا يكون المستند موجودًا
    }
  }

  Future<void> _publishUserDirectory(
    User user, {
    bool isDeleted = false,
  }) async {
    final data = <String, dynamic>{
      'sync_id': user.syncId,
      'firebase_uid': user.firebaseUid,
      'firebase_email': user.firebaseEmail,
      'username': user.username,
      'full_name': user.fullName,
      'role': user.role,
      'permissions': user.permissions,
      'created_at': user.createdAt,
      'updated_at': user.updatedAt,
      'must_change_password': user.mustChangePassword,
      'is_deleted': isDeleted,
    };

    final uid = user.firebaseUid;

    if (uid == null || uid.isEmpty) {
      throw StateError(
        'لا يمكن نشر المستخدم: Firebase UID غير موجود',
      );
    }

    final db = await _dbHelper.database;

    String? driverSyncId;

    if (user.driverId != null) {
      final driverRows = await db.query(
        'drivers',
        columns: ['sync_id'],
        where: 'id = ?',
        whereArgs: [user.driverId],
        limit: 1,
      );

      if (driverRows.isNotEmpty) {
        driverSyncId = driverRows.first['sync_id']?.toString();
      }
    }

    data['driver_sync_id'] = driverSyncId;

    if (_firebaseAuth.currentUser == null) {
      throw StateError(
        'المدير غير مسجل دخول في Firebase. '
        'أعد تسجيل الدخول بالإنترنت ثم حاول مرة أخرى.',
      );
    }

    final userDoc = _firestore
        .collection('businesses')
        .doc(_businessId)
        .collection('user_directory')
        .doc(uid);

    // ===== الكتابة إلى Firestore =====
    await userDoc.set(
      data,
      SetOptions(merge: true),
    );

    debugPrint(
      'PERMISSION VERIFY: write completed '
      'uid=$uid '
      'username=${user.username} '
      'permissions=${user.permissions}',
    );

    // ===== قراءة المستند مباشرة بعد الحفظ =====
    final verifySnapshot = await userDoc.get();

    if (!verifySnapshot.exists) {
      throw StateError(
        'فشل التحقق: مستند المستخدم غير موجود في Firestore بعد الحفظ. '
        'uid=$uid',
      );
    }

    final verifyData = verifySnapshot.data();

    if (verifyData == null) {
      throw StateError(
        'فشل التحقق: مستند المستخدم موجود لكن بياناته فارغة. '
        'uid=$uid',
      );
    }

    final remotePermissionsRaw = verifyData['permissions'];

    if (remotePermissionsRaw is! Map) {
      throw StateError(
        'فشل التحقق: حقل permissions في Firestore ليس Map. '
        'uid=$uid '
        'type=${remotePermissionsRaw.runtimeType}',
      );
    }

    final remotePermissions = <String, bool>{};

    remotePermissionsRaw.forEach((key, value) {
      remotePermissions[key.toString()] = value == true;
    });

    // ===== مقارنة كل الصلاحيات =====
    final expectedKeys = <String>{
      ...user.permissions.keys,
      ...remotePermissions.keys,
    };

    final mismatches = <String>[];

    for (final key in expectedKeys) {
      final expected = user.permissions[key] ?? false;
      final actual = remotePermissions[key] ?? false;

      if (expected != actual) {
        mismatches.add(
          '$key: expected=$expected actual=$actual',
        );
      }
    }

    if (mismatches.isNotEmpty) {
      debugPrint(
        'PERMISSION VERIFY FAILED: '
        'uid=$uid '
        'username=${user.username} '
        'mismatches=$mismatches '
        'remotePermissions=$remotePermissions',
      );

      throw StateError(
        'فشل التحقق من صلاحيات المستخدم بعد الحفظ:\n'
        '${mismatches.join('\n')}',
      );
    }

    debugPrint(
      'PERMISSION VERIFY SUCCESS: '
      'uid=$uid '
      'username=${user.username} '
      'permissions=$remotePermissions',
    );
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
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
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
          throw StateError(
              'استعادة كلمة المرور عبر البريد غير مفعلة في Firebase');
        case 'network-request-failed':
          throw StateError('تعذر الاتصال بخدمة Firebase. تحقق من الإنترنت');
        case 'too-many-requests':
          throw StateError('تمت محاولات كثيرة. حاول مرة أخرى لاحقًا');
        default:
          throw StateError(
              'تعذر إرسال رابط الاستعادة. رمز Firebase: ${e.code}');
      }
    }
  }

  Future<int?> _localDriverIdFromSyncId(
      Database db, dynamic driverSyncId) async {
    final syncId = driverSyncId?.toString().trim();
    if (syncId == null || syncId.isEmpty) return null;

    final rows = await db.query(
      'drivers',
      columns: ['id'],
      where: 'sync_id = ?',
      whereArgs: [syncId],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return (rows.first['id'] as num).toInt();
  }

  Future<User?> login(String username, String password) async {
    final cleanUsername = username.trim();
    if (cleanUsername.isEmpty || password.isEmpty) return null;

    final db = await _dbHelper.database;

    // 1. Local login: works completely offline.
    // ندعم الإصدار القديم SHA-256 والإصدار الجديد PBKDF2.
    final localRows = await db.query(
      'users',
      where: 'username = ? AND is_deleted = 0',
      whereArgs: [cleanUsername],
      limit: 1,
    );

    if (localRows.isNotEmpty) {
      final localUser = User.fromMap(localRows.first);

      var passwordValid = false;
      var upgradedPasswordHash = localUser.passwordHash;
      var upgradedPasswordSalt = localUser.passwordSalt;
      var upgradedPasswordHashVersion = localUser.passwordHashVersion;

      if (localUser.passwordHashVersion >= _passwordHashVersion &&
          localUser.passwordSalt != null &&
          localUser.passwordSalt!.trim().isNotEmpty) {
        try {
          final salt = _hexToBytes(localUser.passwordSalt!);
          final calculatedHash = await _hashPasswordV2(password, salt);

          passwordValid = _constantTimeEquals(
            calculatedHash,
            localUser.passwordHash,
          );
        } catch (_) {
          passwordValid = false;
        }
      } else {
        // المستخدم القديم: SHA-256.
        final legacyHash = _hashPassword(password);
        passwordValid = _constantTimeEquals(
          legacyHash,
          localUser.passwordHash,
        );

        // بعد نجاح التحقق القديم، نرقّي كلمة المرور إلى PBKDF2.
        if (passwordValid) {
          final newSalt = await _newPasswordSalt();
          upgradedPasswordHash = await _hashPasswordV2(
            password,
            newSalt,
          );
          upgradedPasswordSalt = _bytesToHex(newSalt);
          upgradedPasswordHashVersion = _passwordHashVersion;

          await db.update(
            'users',
            {
              'password_hash': upgradedPasswordHash,
              'password_salt': upgradedPasswordSalt,
              'password_hash_version': upgradedPasswordHashVersion,
              'updated_at': DateTime.now().toIso8601String(),
              'is_synced': 0,
            },
            where: 'id = ? AND is_deleted = 0',
            whereArgs: [localUser.id],
          );
        }
      }

      if (!passwordValid) return null;

      var authenticatedLocalUser = localUser;

      // إذا تمت ترقية كلمة المرور، حدّث الكائن المحلي أيضًا.
      if (upgradedPasswordHash != localUser.passwordHash ||
          upgradedPasswordSalt != localUser.passwordSalt ||
          upgradedPasswordHashVersion != localUser.passwordHashVersion) {
        authenticatedLocalUser = User(
          id: localUser.id,
          syncId: localUser.syncId,
          firebaseUid: localUser.firebaseUid,
          firebaseEmail: localUser.firebaseEmail,
          username: localUser.username,
          passwordHash: upgradedPasswordHash,
          passwordSalt: upgradedPasswordSalt,
          passwordHashVersion: upgradedPasswordHashVersion,
          recoveryCodeHash: localUser.recoveryCodeHash,
          recoveryCodeSalt: localUser.recoveryCodeSalt,
          recoveryCodeHashVersion: localUser.recoveryCodeHashVersion,
          fullName: localUser.fullName,
          role: localUser.role,
          driverId: localUser.driverId,
          permissions: localUser.permissions,
          createdAt: localUser.createdAt,
          updatedAt: localUser.updatedAt,
          mustChangePassword: localUser.mustChangePassword,
        );
      }

      // Keep offline login working, but refresh permissions when Firebase is available.
      try {
        final email = authenticatedLocalUser.firebaseEmail?.trim() ?? '';

        if (email.isNotEmpty) {
          final credential =
              await _firebaseAuth.signInWithEmailAndPassword(
            email: email,
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

                final remoteRole =
                    remote['role']?.toString() ?? authenticatedLocalUser.role;

                final effectivePermissions = permissions.isEmpty
                    ? _defaultPermissionsForRole(remoteRole)
                    : permissions;

                debugPrint(
                  'AUTH DEBUG: refreshed local user '
                  'username=$cleanUsername '
                  'role=$remoteRole '
                  'rawPermissions=$rawPermissions '
                  'effectivePermissions=$effectivePermissions',
                );

                final refreshedUser = User(
                  id: authenticatedLocalUser.id,
                  syncId: remote['sync_id']?.toString().isNotEmpty == true
                      ? remote['sync_id'].toString()
                      : authenticatedLocalUser.syncId,
                  firebaseUid: firebaseUid,
                  firebaseEmail:
                      remote['firebase_email']?.toString() ??
                      email,
                  username:
                      remote['username']?.toString() ??
                      authenticatedLocalUser.username,
                  passwordHash: upgradedPasswordHash,
                  passwordSalt: upgradedPasswordSalt,
                  passwordHashVersion: upgradedPasswordHashVersion,
                  recoveryCodeHash:
                      authenticatedLocalUser.recoveryCodeHash,
                  recoveryCodeSalt:
                      authenticatedLocalUser.recoveryCodeSalt,
                  recoveryCodeHashVersion:
                      authenticatedLocalUser.recoveryCodeHashVersion,
                  fullName:
                      remote['full_name']?.toString() ??
                      authenticatedLocalUser.fullName,
                  role: remoteRole,
                  driverId: authenticatedLocalUser.driverId,
                  permissions: effectivePermissions,
                  createdAt:
                      remote['created_at']?.toString() ??
                      authenticatedLocalUser.createdAt,
                  updatedAt:
                      remote['updated_at']?.toString() ??
                      authenticatedLocalUser.updatedAt,
                  mustChangePassword:
                      remote['must_change_password'] == true,
                );

                final data = refreshedUser.toMap()..remove('id');

                await db.update(
                  'users',
                  data,
                  where: 'id = ?',
                  whereArgs: [authenticatedLocalUser.id],
                );

                return refreshedUser;
              }
            }
          }
        }
      } on firebase_auth.FirebaseAuthException catch (e) {
        debugPrint(
          'AUTH DEBUG: local user Firebase refresh skipped: ${e.code}',
        );
      } catch (e) {
        debugPrint(
          'AUTH DEBUG: local user Firebase refresh skipped: $e',
        );
      }

      return authenticatedLocalUser;
    }

    // 2. New device: bootstrap login from the public login directory.
    // The device does not have a local account yet, so it cannot read
    // the protected user_directory until Firebase authentication succeeds.
    try {
      // قراءة بمستند واحد (get) بدل الاستعلام (list).
      final directoryDoc = await _firestore
          .collection('businesses')
          .doc(_businessId)
          .collection('login_directory')
          .doc(cleanUsername)
          .get();

      if (!directoryDoc.exists) return null;

      final directory = directoryDoc.data();
      if (directory == null) return null;
      if (directory['is_deleted'] == true) return null;

      final email =
          directory['firebase_email']?.toString().trim() ?? '';

      if (email.isEmpty) return null;

      // Authenticate first. After this succeeds, protected Firestore
      // collections such as user_directory become readable.
      final credential =
          await _firebaseAuth.signInWithEmailAndPassword(
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

      final remoteRole = remote['role']?.toString() ?? 'member';

      final effectivePermissions = permissions.isEmpty
          ? _defaultPermissionsForRole(remoteRole)
          : permissions;

      debugPrint(
        'AUTH DEBUG: username=$cleanUsername '
        'role=$remoteRole '
        'rawPermissions=$rawPermissions '
        'parsedPermissions=$permissions '
        'effectivePermissions=$effectivePermissions',
      );

      // حساب جديد على هذا الجهاز: نخزن كلمة المرور محليًا بـ PBKDF2.
      final passwordSalt = await _newPasswordSalt();
      final passwordHash = await _hashPasswordV2(
        password,
        passwordSalt,
      );

      final now = DateTime.now().toIso8601String();

      final user = User(
        syncId: remote['sync_id']?.toString().isNotEmpty == true
            ? remote['sync_id'].toString()
            : const Uuid().v4(),
        firebaseUid: firebaseUid,
        firebaseEmail: email,
        username:
            remote['username']?.toString() ?? cleanUsername,
        passwordHash: passwordHash,
        passwordSalt: _bytesToHex(passwordSalt),
        passwordHashVersion: _passwordHashVersion,
        recoveryCodeHash: null,
        recoveryCodeSalt: null,
        recoveryCodeHashVersion: 1,
        fullName:
            remote['full_name']?.toString() ?? cleanUsername,
        role: remoteRole,

        // Convert the stable Firebase driver sync_id to this device's local driver ID.
        driverId: await _localDriverIdFromSyncId(
          db,
          remote['driver_sync_id'],
        ),

        permissions: effectivePermissions,
        createdAt: remote['created_at']?.toString() ?? now,
        updatedAt: remote['updated_at']?.toString() ?? now,
        mustChangePassword:
            remote['must_change_password'] == true,
      );

      final localId = await db.insert(
        'users',
        user.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // لا نُشغّل syncAll هنا لأن PermissionService.currentUser
      // لم يُضبط بعد. login_screen سيستدعي setUser ثم syncAll بالترتيب الصحيح.
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
    final providedEmail = firebaseEmail?.trim();

    if (cleanUsername.isEmpty) throw ArgumentError('اسم المستخدم مطلوب');
    if (cleanFullName.isEmpty) throw ArgumentError('الاسم الكامل مطلوب');
    if (password.length < 6) {
      throw ArgumentError('كلمة المرور يجب أن تكون 6 أحرف أو أرقام على الأقل');
    }
    if (role != 'admin' && role != 'deputy_manager' && role != 'member') {
      throw ArgumentError('الدور غير صالح');
    }

    // ✅ إذا لم يُدخل بريد، نولّد alias على Gmail المركزي
    final cleanEmail = (providedEmail == null || providedEmail.isEmpty)
        ? _generateAliasEmail(cleanUsername)
        : providedEmail;

    final emailRegex = RegExp(
      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
    );

    if (!emailRegex.hasMatch(cleanEmail)) {
      throw ArgumentError('بريد Firebase غير صالح');
    }

    final db = await _dbHelper.database;

    // نبحث عن الاسم حتى لو كان المستخدم القديم محذوفًا.
    // السبب: users.username عليه قيد UNIQUE في SQLite،
    // لذلك لا يمكن INSERT لاسم سبق استخدامه حتى لو كان is_deleted=1.
    final duplicate = await db.query(
      'users',
      columns: ['id', 'is_deleted'],
      where: 'username = ?',
      whereArgs: [cleanUsername],
      limit: 1,
    );

    if (duplicate.isNotEmpty &&
        (duplicate.first['is_deleted'] as num?)?.toInt() == 0) {
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

    // المستخدم الجديد يُخزّن محليًا باستخدام PBKDF2 مع Salt مستقل.
    final passwordSalt = await _newPasswordSalt();
    final passwordHash = await _hashPasswordV2(password, passwordSalt);

    final now = DateTime.now().toIso8601String();
    final user = User(
      syncId: const Uuid().v4(),
      firebaseUid: firebaseUid,
      firebaseEmail: cleanEmail,
      username: cleanUsername,
      passwordHash: passwordHash,
      passwordSalt: _bytesToHex(passwordSalt),
      passwordHashVersion: _passwordHashVersion,
      fullName: cleanFullName,
      role: role,
      driverId: driverId,
      permissions: permissions ?? _defaultPermissionsForRole(role),
      createdAt: now,
      updatedAt: now,
    );

    int localId;

    // إذا كان هناك سجل قديم محذوف بنفس اسم المستخدم،
    // نعيد استخدامه بدل INSERT حتى لا نصطدم بقيد UNIQUE.
    if (duplicate.isNotEmpty) {
      localId = (duplicate.first['id'] as num).toInt();

      final userData = user.toMap()..remove('id');

      await db.update(
        'users',
        {
          ...userData,
          'is_deleted': 0,
          'is_synced': 0,
        },
        where: 'id = ?',
        whereArgs: [localId],
      );
    } else {
      localId = await db.insert(
        'users',
        user.toMap(),
      );
    }

    try {
      await _publishUserDirectory(user);
      await _publishLoginDirectory(user);
    } catch (e) {
      // لا نحذف السجل المحلي هنا؛ الاحتفاظ به أفضل من فقدان
      // المستخدم إذا حدث خطأ مؤقت في الشبكة.
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

    // ✅ حفظ username القديم قبل التحديث
    final oldRows = await db.query(
      'users',
      columns: ['username'],
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [userId],
      limit: 1,
    );
    final oldUsername = oldRows.isNotEmpty
        ? oldRows.first['username']?.toString()
        : null;

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

    final updatedUser = User.fromMap(rows.first);

    // ✅ إذا تغيّر username: احذف المستند القديم من login_directory
    if (oldUsername != null &&
        oldUsername.trim().isNotEmpty &&
        oldUsername.trim() != cleanUsername) {
      await _deleteLoginDirectoryByUsername(oldUsername);
    }

    await _publishUserDirectory(updatedUser);
    await _publishLoginDirectory(updatedUser);
    return true;
  }

  Future<bool> deleteUser(int userId) async {
    PermissionService.requirePermission(PermissionKeys.usersManage);

    final currentUserId = PermissionService.currentUser?.id;
    if (currentUserId == userId) {
      throw StateError('لا يمكنك حذف المستخدم الحالي');
    }

    final db = await _dbHelper.database;

    final rows = await db.query(
      'users',
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [userId],
      limit: 1,
    );

    if (rows.isEmpty) return false;

    final user = User.fromMap(rows.first);

    final count = await db.update(
      'users',
      {
        'is_deleted': 1,
        'is_synced': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [userId],
    );

    if (count == 0) return false;

    final deletedRows = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (deletedRows.isNotEmpty) {
      final deletedUser = User.fromMap(deletedRows.first);

      // المستخدمون القدامى قد لا يملكون Firebase UID.
      // في هذه الحالة يكفي حذفهم منطقيًا من قاعدة البيانات المحلية.
      if (deletedUser.firebaseUid != null &&
          deletedUser.firebaseUid!.trim().isNotEmpty) {
        // نشر حالة الحذف إلى user_directory حتى يُمنع المستخدم
        // من تسجيل الدخول على الأجهزة الأخرى.
        await _publishUserDirectory(deletedUser, isDeleted: true);
      }

      // إزالة اسم المستخدم من دليل تسجيل الدخول.
      if (user.username.trim().isNotEmpty) {
        await _deleteLoginDirectoryByUsername(user.username);
      }
    }

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

  Future<void> updatePermissions(
      int userId, Map<String, bool> newPermissions) async {
    PermissionService.requirePermission(PermissionKeys.permissionsManage);

    debugPrint(
      'PERMISSION DIAG: updatePermissions START '
      'userId=$userId permissions=${newPermissions.length}',
    );
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

    final diagnosticUser = User.fromMap(rows.first);
    debugPrint(
      'PERMISSION DIAG: target user '
      'id=${diagnosticUser.id} '
      'username=${diagnosticUser.username} '
      'firebaseUid=${diagnosticUser.firebaseUid} '
      'permissions=${diagnosticUser.permissions.length}',
    );

    await _publishUserDirectory(diagnosticUser);

    debugPrint(
      'PERMISSION DIAG: _publishUserDirectory completed '
      'firebaseUid=${diagnosticUser.firebaseUid}',
    );
  }

  /// يغيّر كلمة مرور المستخدم في SQLite + Firebase Auth.
  ///
  /// [currentPassword]: كلمة المرور الحالية - مطلوبة فقط إذا كان
  /// المستخدم يغيّر كلمته بنفسه (لإعادة المصادقة).
  ///
  /// ملاحظة مهمة (Spark-only، بدون Cloud Functions):
  /// - إذا كان المستخدم يغيّر كلمته بنفسه → updatePassword مباشرة
  /// - إذا كان المدير يغيّر كلمة سائق آخر → يُرسل رابط إعادة تعيين
  ///   (لأن Firebase يمنع تغيير كلمة مرور مستخدم آخر من الـ client)
  Future<bool> updateUserPassword({
    required int userId,
    required String newPassword,
    String? currentPassword,
  }) async {
    if (newPassword.length < 6) {
      throw ArgumentError('كلمة المرور يجب أن تكون 6 أحرف أو أرقام على الأقل');
    }

    final db = await _dbHelper.database;

    final targetRows = await db.query(
      'users',
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [userId],
      limit: 1,
    );
    if (targetRows.isEmpty) return false;

    final targetUser = User.fromMap(targetRows.first);
    final targetEmail = targetUser.firebaseEmail?.trim() ?? '';
    final currentFirebaseUser = _firebaseAuth.currentUser;

    if (targetEmail.isEmpty) {
      throw StateError('حساب المستخدم غير مرتبط بـ Firebase');
    }

    // تغيير كلمة المرور مسموح للحساب الحالي فقط من تطبيق العميل.
    // يجب نجاح Firebase أولًا، وبعدها فقط نحدّث SQLite.
    if (currentFirebaseUser == null ||
        currentFirebaseUser.email?.trim().toLowerCase() !=
            targetEmail.toLowerCase()) {
      PermissionService.requirePermission(PermissionKeys.usersManage);
      throw StateError(
        'لا يمكن للمدير تعيين كلمة مرور مستخدم آخر مباشرة من التطبيق. '
        'استخدم رابط استعادة كلمة المرور؛ لم يتم تغيير كلمة المرور المحلية.',
      );
    }

    try {
      if (currentPassword != null && currentPassword.isNotEmpty) {
        final cred = firebase_auth.EmailAuthProvider.credential(
          email: targetEmail,
          password: currentPassword,
        );
        await currentFirebaseUser.reauthenticateWithCredential(cred);
      }

      await currentFirebaseUser.updatePassword(newPassword);
    } on firebase_auth.FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          throw StateError('كلمة المرور الحالية غير صحيحة');
        case 'requires-recent-login':
          throw StateError(
            'انتهت صلاحية جلسة Firebase. سجّل الدخول مرة أخرى ثم حاول.',
          );
        case 'network-request-failed':
          throw StateError(
            'تعذر الاتصال بـ Firebase. لم يتم تغيير كلمة المرور المحلية.',
          );
        case 'weak-password':
          throw StateError('كلمة المرور الجديدة ضعيفة');
        default:
          throw StateError(
            'تعذر تغيير كلمة المرور في Firebase. رمز الخطأ: ${e.code}',
          );
      }
    } catch (e) {
      throw StateError(
        'تعذر تغيير كلمة المرور في Firebase. لم يتم تغيير كلمة المرور المحلية.',
      );
    }

    final passwordSalt = await _newPasswordSalt();
    final passwordHash = await _hashPasswordV2(newPassword, passwordSalt);

    final count = await db.update(
      'users',
      {
        'password_hash': passwordHash,
        'password_salt': _bytesToHex(passwordSalt),
        'password_hash_version': _passwordHashVersion,
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
      throw ArgumentError(
          'رمز الاسترداد يجب أن يكون 6 أحرف أو أرقام على الأقل');
    }
    final db = await _dbHelper.database;
    final recoveryCodeSalt = await _newPasswordSalt();
    final recoveryCodeHash = await _hashPasswordV2(code, recoveryCodeSalt);
    final count = await db.update(
      'users',
      {
        'recovery_code_hash': recoveryCodeHash,
        'recovery_code_salt': _bytesToHex(recoveryCodeSalt),
        'recovery_code_hash_version': _passwordHashVersion,
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
    final cleanUsername = username.trim();
    final cleanRecoveryCode = recoveryCode.trim();

    final rows = await db.query(
      'users',
      columns: [
        'id',
        'recovery_code_hash',
        'recovery_code_salt',
        'recovery_code_hash_version',
      ],
      where: 'username = ? AND is_deleted = 0',
      whereArgs: [cleanUsername],
      limit: 1,
    );

    if (rows.isEmpty) return false;

    final user = rows.first;
    final storedHash = user['recovery_code_hash']?.toString() ?? '';
    if (storedHash.isEmpty) return false;

    final hashVersion =
        (user['recovery_code_hash_version'] as num?)?.toInt() ?? 1;
    final saltText = user['recovery_code_salt']?.toString().trim() ?? '';

    if (hashVersion >= 2 && saltText.isNotEmpty) {
      try {
        final salt = _hexToBytes(saltText);
        final calculatedHash = await _hashPasswordV2(
          cleanRecoveryCode,
          salt,
        );
        return _constantTimeEquals(calculatedHash, storedHash);
      } catch (_) {
        return false;
      }
    }

    // دعم أكواد الاسترداد القديمة SHA-256 وترقيتها بعد نجاح التحقق.
    final legacyHash = _hashPassword(cleanRecoveryCode);
    if (!_constantTimeEquals(legacyHash, storedHash)) {
      return false;
    }

    final newSalt = await _newPasswordSalt();
    final newHash = await _hashPasswordV2(
      cleanRecoveryCode,
      newSalt,
    );

    await db.update(
      'users',
      {
        'recovery_code_hash': newHash,
        'recovery_code_salt': _bytesToHex(newSalt),
        'recovery_code_hash_version': _passwordHashVersion,
        'updated_at': DateTime.now().toIso8601String(),
        'is_synced': 0,
      },
      where: 'id = ? AND is_deleted = 0',
      whereArgs: [user['id']],
    );

    return true;
  }

  Future<bool> sendPasswordResetByRecoveryCode({
    required String username,
    required String recoveryCode,
  }) async {
    final db = await _dbHelper.database;
    final cleanUsername = username.trim();
    final cleanRecoveryCode = recoveryCode.trim();

    final result = await db.query(
      'users',
      columns: [
        'id',
        'firebase_email',
        'recovery_code_hash',
        'recovery_code_salt',
        'recovery_code_hash_version',
      ],
      where: 'username = ? AND is_deleted = 0',
      whereArgs: [cleanUsername],
      limit: 1,
    );

    if (result.isEmpty) return false;

    final user = result.first;
    final storedHash = user['recovery_code_hash']?.toString() ?? '';
    if (storedHash.isEmpty) return false;

    final hashVersion =
        (user['recovery_code_hash_version'] as num?)?.toInt() ?? 1;
    final saltText = user['recovery_code_salt']?.toString().trim() ?? '';

    bool verified = false;

    if (hashVersion >= 2 && saltText.isNotEmpty) {
      try {
        final salt = _hexToBytes(saltText);
        final calculatedHash = await _hashPasswordV2(
          cleanRecoveryCode,
          salt,
        );
        verified = _constantTimeEquals(calculatedHash, storedHash);
      } catch (_) {
        return false;
      }
    } else {
      final legacyHash = _hashPassword(cleanRecoveryCode);
      verified = _constantTimeEquals(legacyHash, storedHash);
    }

    if (!verified) return false;

    final email = user['firebase_email']?.toString().trim() ?? '';
    if (email.isEmpty || !email.contains('@')) {
      throw StateError(
        'لا يوجد بريد إلكتروني مرتبط بهذا الحساب لاستعادة كلمة المرور',
      );
    }

    // ترقية رمز الاسترداد القديم إلى PBKDF2 قبل إرسال رابط الاستعادة.
    if (hashVersion < 2 || saltText.isEmpty) {
      final newSalt = await _newPasswordSalt();
      final newHash = await _hashPasswordV2(
        cleanRecoveryCode,
        newSalt,
      );

      await db.update(
        'users',
        {
          'recovery_code_hash': newHash,
          'recovery_code_salt': _bytesToHex(newSalt),
          'recovery_code_hash_version': _passwordHashVersion,
          'updated_at': DateTime.now().toIso8601String(),
          'is_synced': 0,
        },
        where: 'id = ? AND is_deleted = 0',
        whereArgs: [user['id']],
      );
    }

    await sendPasswordResetEmail(email);
    return true;
  }

  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  // الإصدار 2: PBKDF2-HMAC-SHA256 مع Salt عشوائي مستقل لكل مستخدم.
  static const int _passwordHashVersion = 2;
  static const int _passwordSaltLength = 16;
  static const int _pbkdf2Iterations = 100000;
  static const int _pbkdf2Bits = 256;

  final crypto2.Pbkdf2 _passwordKdf = crypto2.Pbkdf2(
    macAlgorithm: crypto2.Hmac.sha256(),
    iterations: _pbkdf2Iterations,
    bits: _pbkdf2Bits,
  );

  List<int> _generatePasswordSalt() {
    final random = Random.secure();
    return List<int>.generate(
      _passwordSaltLength,
      (_) => random.nextInt(256),
    );
  }

  Future<String> _hashPasswordV2(
    String password,
    List<int> salt,
  ) async {
    final secretKey = await _passwordKdf.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );

    final bytes = await secretKey.extractBytes();
    return bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  List<int> _hexToBytes(String hex) {
    final clean = hex.trim();

    if (clean.isEmpty || clean.length.isOdd) {
      throw FormatException('Invalid hexadecimal salt');
    }

    final bytes = <int>[];

    for (var i = 0; i < clean.length; i += 2) {
      bytes.add(int.parse(clean.substring(i, i + 2), radix: 16));
    }

    return bytes;
  }

  String _bytesToHex(List<int> bytes) {
    return bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;

    var difference = 0;

    for (var i = 0; i < a.length; i++) {
      difference |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }

    return difference == 0;
  }

  Future<List<int>> _newPasswordSalt() async {
    return _generatePasswordSalt();
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
