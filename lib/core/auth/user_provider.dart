import 'package:flutter/foundation.dart';
import '../../models/user.dart';
import 'permission_service.dart';

class UserProvider extends ChangeNotifier {
  User? _currentUser;
  User? get currentUser => _currentUser;

  void setUser(User? user) {
    _currentUser = user;
    PermissionService.setCurrentUser(user);
    notifyListeners();
  }

  void logout() {
    _currentUser = null;
    PermissionService.setCurrentUser(null);
    notifyListeners();
  }
}
