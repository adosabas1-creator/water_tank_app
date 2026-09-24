import 'package:flutter/foundation.dart';
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

  User? _currentUser;
  User? get currentUser => _currentUser;

  bool _isRestoring = false;
  bool get isRestoring => _isRestoring;

  /// يعين المستخدم في الذاكرة ويحفظ جلسته في SharedPreferences.
  /// إذا كان userId != null يُحفظ، وإلا يُحذف (تسجيل خروج).
  Future<void> setUser(User? user) async {
    _currentUser = user;
    PermissionService.setCurrentUser(user);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      if (user?.id != null) {
        await prefs.setInt(_sessionKey, user!.id!);
      } else {
        await prefs.remove(_sessionKey);
      }
    } catch (_) {
      // تجاهل الأخطاء — الجلسة ستفقد عند الإغلاق لكن التطبيق يعمل
    }
  }

  /// يحاول استعادة الجلسة السابقة من SharedPreferences + SQLite.
  /// يُستدعى مرة واحدة عند بدء التطبيق.
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

  Future<void> restoreSession() async {
    _isRestoring = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt(_sessionKey);

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
          await prefs.remove(_sessionKey);
        }
      }
    } catch (e) {
      debugPrint('restoreSession failed: $e');
    } finally {
      _isRestoring = false;
      notifyListeners();
    }
  }

  /// تسجيل خروج كامل — يمسح الجلسة من الذاكرة ومن SharedPreferences.
  Future<void> logout() async {
    _currentUser = null;
    PermissionService.setCurrentUser(null);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionKey);
    } catch (_) {}
  }
}
