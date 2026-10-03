import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user.dart';
import '../database/database_helper.dart';
import 'permission_service.dart';

class UserProvider extends ChangeNotifier {
  static UserProvider? _instance;

  UserProvider() {
    _instance = this;
  }

  static const String _sessionKey = 'current_user_id';

  /// تخزين آمن للجلسة (Keystore / Keychain).
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  User? _currentUser;
  User? get currentUser => _currentUser;

  bool _isRestoring = false;
  bool get isRestoring => _isRestoring;

  /// يقرأ معرّف الجلسة من التخزين الآمن، مع ترحيل من SharedPreferences إن وُجد.
  Future<int?> _readSessionUserId() async {
    try {
      final secureValue = await _secureStorage.read(key: _sessionKey);
      if (secureValue != null && secureValue.isNotEmpty) {
        return int.tryParse(secureValue);
      }
    } catch (e) {
      debugPrint('secure read session failed, trying SharedPreferences: $e');
    }

    // ترحيل من SharedPreferences (جلسات قديمة) ثم حذفها.
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacyId = prefs.getInt(_sessionKey);
      if (legacyId != null) {
        await _writeSessionUserId(legacyId);
        await prefs.remove(_sessionKey);
        return legacyId;
      }
    } catch (e) {
      debugPrint('legacy SharedPreferences session read failed: $e');
    }

    return null;
  }

  /// يكتب معرّف الجلسة في التخزين الآمن، مع fallback إلى SharedPreferences.
  Future<void> _writeSessionUserId(int? userId) async {
    try {
      if (userId != null) {
        await _secureStorage.write(key: _sessionKey, value: userId.toString());
      } else {
        await _secureStorage.delete(key: _sessionKey);
      }
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_sessionKey);
      } catch (_) {}
      return;
    } catch (e) {
      debugPrint('secure write session failed, falling back to SharedPreferences: $e');
    }

    // fallback حتى لا تنكسر الجلسة أوفلاين
    try {
      final prefs = await SharedPreferences.getInstance();
      if (userId != null) {
        await prefs.setInt(_sessionKey, userId);
      } else {
        await prefs.remove(_sessionKey);
      }
    } catch (_) {}
  }

  Future<void> setUser(User? user) async {
    _currentUser = user;
    PermissionService.setCurrentUser(user);
    notifyListeners();
    await _writeSessionUserId(user?.id);
  }

  static Future<void> refreshCurrentUserFromDatabase() async {
    final provider = _instance;
    if (provider == null) return;

    final currentUserId = provider._currentUser?.id;
    if (currentUserId == null) return;

    try {
      final db = await DatabaseHelper().database;
      final rows = await db.query(
        'users',
        where: 'id = ? AND is_deleted = 0',
        whereArgs: [currentUserId],
        limit: 1,
      );

      if (rows.isEmpty) return;

      final refreshedUser = User.fromMap(rows.first);
      provider._currentUser = refreshedUser;
      PermissionService.setCurrentUser(refreshedUser);
      provider.notifyListeners();

      debugPrint(
        'UserProvider refreshed current user permissions from local DB: '
        'userId=$currentUserId',
      );
    } catch (e) {
      debugPrint('refreshCurrentUserFromDatabase failed: $e');
    }
  }

  /// يستعيد الجلسة من التخزين الآمن + SQLite (يعمل أوفلاين).
  Future<void> restoreSession() async {
    _isRestoring = true;
    notifyListeners();

    try {
      final userId = await _readSessionUserId();

      if (userId != null) {
        final db = await DatabaseHelper().database;
        final rows = await db.query(
          'users',
          where: 'id = ? AND is_deleted = 0',
          whereArgs: [userId],
          limit: 1,
        );

        if (rows.isNotEmpty) {
          _currentUser = User.fromMap(rows.first);
          PermissionService.setCurrentUser(_currentUser);
        } else {
          await _writeSessionUserId(null);
        }
      }
    } catch (e) {
      debugPrint('restoreSession failed: $e');
    } finally {
      _isRestoring = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    PermissionService.setCurrentUser(null);
    notifyListeners();
    await _writeSessionUserId(null);
  }
}
