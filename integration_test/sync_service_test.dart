import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:water_tank_app/core/auth/permission_service.dart';
import 'package:water_tank_app/core/constants/permissions.dart';
import 'package:water_tank_app/core/database/database_helper.dart';
import 'package:water_tank_app/models/user.dart' as app_models;
import 'package:water_tank_app/core/network/sync_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const testEmail = 'sync-test@example.com';
  const testPassword = 'test123456';
  const testUid = String.fromEnvironment('SYNC_TEST_UID');
  const emulatorHost = String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
    defaultValue: '127.0.0.1',
  );

  late Database db;
  late DatabaseHelper helper;

  setUpAll(() async {
    print('SETUP 1: Firebase.initializeApp START');
    try {
      await Firebase.initializeApp().timeout(
        const Duration(seconds: 90),
        onTimeout: () {
          throw TimeoutException(
            'Firebase.initializeApp exceeded 90 seconds',
          );
        },
      );
      print('SETUP 1: Firebase.initializeApp DONE');
    } catch (e, stackTrace) {
      print('SETUP 1 ERROR: $e');
      print(stackTrace);
      rethrow;
    }

    print('SETUP 2: useAuthEmulator START host=$emulatorHost');
    await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
    print('SETUP 2: useAuthEmulator DONE');

    print('SETUP 3: useFirestoreEmulator START host=$emulatorHost');
    FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080);
    print('SETUP 3: useFirestoreEmulator DONE');

    print('SETUP 4: signInWithEmailAndPassword START');
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: testEmail,
      password: testPassword,
    );
    print(
      'SETUP 4: signInWithEmailAndPassword DONE '
      'uid=${FirebaseAuth.instance.currentUser?.uid}',
    );

    print('SETUP 5: verify UID START');
    expect(FirebaseAuth.instance.currentUser?.uid, testUid);
    print('SETUP 5: verify UID DONE');

    print('SETUP 6: closeDatabase START');
    helper = DatabaseHelper();
    await helper.closeDatabase();
    print('SETUP 6: closeDatabase DONE');

    print('SETUP 7: openDatabase START');
    db = await helper.database;
    print('SETUP 7: openDatabase DONE');
  });

  tearDownAll(() async {
    PermissionService.setCurrentUser(null);
    try {
      await helper.closeDatabase();
    } catch (_) {}
  });

  testWidgets('SyncService uploads an unsynced client to Firestore',
      (tester) async {
    final now = DateTime.now().toIso8601String();

    final user = app_models.User(
      syncId: 'sync-test-user',
      firebaseUid: testUid,
      firebaseEmail: testEmail,
      username: 'sync_test_admin',
      passwordHash: 'test',
      passwordSalt: null,
      passwordHashVersion: 1,
      recoveryCodeHash: null,
      recoveryCodeSalt: null,
      recoveryCodeHashVersion: 1,
      fullName: 'Sync Test Admin',
      role: 'admin',
      driverId: null,
      permissions: DefaultPermissions.admin(),
      createdAt: now,
      updatedAt: now,
      mustChangePassword: false,
    );

    final existingUsers = await db.query(
      'users',
      where: 'sync_id = ?',
      whereArgs: [user.syncId],
    );

    int userId;
    if (existingUsers.isEmpty) {
      userId = await db.insert(
        'users',
        user.toMap()..remove('id'),
      );
    } else {
      userId = existingUsers.first['id'] as int;
    }

    final currentUser = app_models.User(
      id: userId,
      syncId: user.syncId,
      firebaseUid: user.firebaseUid,
      firebaseEmail: user.firebaseEmail,
      username: user.username,
      passwordHash: user.passwordHash,
      passwordSalt: user.passwordSalt,
      passwordHashVersion: user.passwordHashVersion,
      recoveryCodeHash: user.recoveryCodeHash,
      recoveryCodeSalt: user.recoveryCodeSalt,
      recoveryCodeHashVersion: user.recoveryCodeHashVersion,
      fullName: user.fullName,
      role: user.role,
      driverId: user.driverId,
      permissions: user.permissions,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
      mustChangePassword: user.mustChangePassword,
    );

    PermissionService.setCurrentUser(currentUser);

    const clientSyncId = 'sync-test-client-001';
    final remoteRef = FirebaseFirestore.instance
        .collection('businesses')
        .doc(SyncService.businessId)
        .collection('clients')
        .doc(clientSyncId);
    final previousRemote = await remoteRef.get();
    if (previousRemote.exists) {
      await remoteRef.delete();
    }

    await db.delete(
      'clients',
      where: 'sync_id = ?',
      whereArgs: [clientSyncId],
    );

    await db.insert('clients', {
      'sync_id': clientSyncId,
      'client_number': 'TEST-001',
      'name': 'Sync Test Client',
      'phone': '777000001',
      'address': 'Emulator',
      'notes': 'SyncService integration test',
      'created_at': now,
      'updated_at': now,
      'is_deleted': 0,
      'is_synced': 0,
    });

    final before = await db.query(
      'clients',
      where: 'sync_id = ?',
      whereArgs: [clientSyncId],
    );

    expect(before.single['is_synced'], 0);

    await SyncService().syncClients();

    final remote = await FirebaseFirestore.instance
        .collection('businesses')
        .doc(SyncService.businessId)
        .collection('clients')
        .doc(clientSyncId)
        .get();

    expect(remote.exists, isTrue);
    expect(remote.data()?['sync_id'], clientSyncId);
    expect(remote.data()?['name'], 'Sync Test Client');

    final after = await db.query(
      'clients',
      where: 'sync_id = ?',
      whereArgs: [clientSyncId],
    );

    expect(after.single['is_synced'], 1);
  });
}
