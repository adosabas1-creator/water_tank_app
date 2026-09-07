import '../../models/user.dart';

class PermissionService {
  static bool hasPermission(User? user, String permissionKey) {
    if (user == null) return false;
    return user.permissions[permissionKey] ?? false;
  }

  static bool hasAnyPermission(User? user, List<String> permissionKeys) {
    if (user == null) return false;
    return permissionKeys.any((key) => user.permissions[key] ?? false);
  }

  static bool hasAllPermissions(User? user, List<String> permissionKeys) {
    if (user == null) return false;
    return permissionKeys.every((key) => user.permissions[key] ?? false);
  }
}
