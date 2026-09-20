import '../../models/user.dart';

class PermissionService {
  static User? _currentUser;

  static void setCurrentUser(User? user) {
    _currentUser = user;
  }

  static User? get currentUser => _currentUser;

  static bool hasPermission(User? user, String permissionKey) {
    if (user == null) return false;
    // ✅ الأدمن له كل الصلاحيات تلقائيًا
    // لا نعتمد على خريطة permissions لأنها قد تُفرّغها المزامنة
    if (user.role == 'admin') return true;
    return user.permissions[permissionKey] ?? false;
  }

  static bool hasAnyPermission(User? user, List<String> permissionKeys) {
    if (user == null) return false;
    // الأدمن له جميع الصلاحيات تلقائيًا
    if (user.role == 'admin') return true;
    return permissionKeys.any((key) => user.permissions[key] ?? false);
  }

  static bool hasAllPermissions(User? user, List<String> permissionKeys) {
    if (user == null) return false;
    // الأدمن له جميع الصلاحيات تلقائيًا
    if (user.role == 'admin') return true;
    return permissionKeys.every((key) => user.permissions[key] ?? false);
  }

  static void requirePermission(String permissionKey) {
    if (!hasPermission(_currentUser, permissionKey)) {
      throw StateError('ليس لديك صلاحية تنفيذ هذه العملية.');
    }
  }

  static void requireManagementRole() {
    final role = _currentUser?.role;
    if (role != 'admin' && role != 'deputy_manager') {
      throw StateError('ليس لديك صلاحية تنفيذ هذه العملية.');
    }
  }

  static void requireAdmin() {
    if (_currentUser?.role != 'admin') {
      throw StateError('هذه العملية متاحة للمدير فقط.');
    }
  }
}
