import '../core/auth/user_provider.dart';
import '../core/database/database_helper.dart';

class ResetService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<void> resetAllTransactionalData(UserProvider userProvider) async {
    final user = userProvider.currentUser;

    if (user == null || user.role != 'admin') {
      throw StateError('ليس لديك صلاحية لتصفير الحسابات والبيانات.');
    }

    await _dbHelper.resetTransactionalData();
  }
}
