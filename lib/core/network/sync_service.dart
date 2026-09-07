import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../database/database_helper.dart';
import 'connectivity_service.dart';

class SyncService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ConnectivityService _connectivity = ConnectivityService();

  Future<void> syncTable(String tableName) async {
    if (!await _connectivity.isOnline()) return;
    final db = await _dbHelper.database;
    final localData = await db.query(tableName, where: 'is_synced = ?', whereArgs: [0]);
    for (var row in localData) {
      try {
        await _firestore
            .collection('users')
            .doc(_auth.currentUser?.uid)
            .collection(tableName)
            .doc(row['id'].toString())
            .set(row, SetOptions(merge: true));
        await db.update(tableName, {'is_synced': 1}, where: 'id = ?', whereArgs: [row['id']]);
      } catch (e) {
        print('Sync error for $tableName id ${row['id']}: $e');
      }
    }
  }

  Future<void> syncAll() async {
    final tables = ['clients', 'suppliers', 'tanks', 'drivers', 'sales', 'filling_operations', 'payments', 'expenses', 'salaries'];
    for (var table in tables) {
      await syncTable(table);
    }
  }

  Future<void> dailyBackup() async {
    if (!await _connectivity.isOnline()) return;
    final db = await _dbHelper.database;
    final tables = ['clients', 'suppliers', 'tanks', 'drivers', 'sales', 'filling_operations', 'payments', 'expenses', 'salaries'];
    final backupData = <String, dynamic>{};
    for (var table in tables) {
      backupData[table] = await db.query(table);
    }
    await _firestore
        .collection('backups')
        .doc(_auth.currentUser?.uid)
        .collection('daily')
        .doc(DateTime.now().toIso8601String())
        .set(backupData);
  }
}
