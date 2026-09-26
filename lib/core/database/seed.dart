import 'package:flutter/foundation.dart';
import 'database_helper.dart';

Future<void> seedAdminUser() async {
  final db = await DatabaseHelper().database;

  final existingAdmin = await db.query(
    'users',
    where: 'username = ? AND is_deleted = 0',
    whereArgs: ['admin'],
    limit: 1,
  );

  if (existingAdmin.isEmpty) {
    // لا ننشئ مديرًا بكلمة مرور ثابتة داخل التطبيق.
    // على الجهاز الجديد يتم إنشاء الحساب المحلي بعد نجاح
    // تسجيل الدخول عبر Firebase، وتُخزّن كلمة المرور باستخدام PBKDF2.
    debugPrint(
      'Default admin seed skipped: no hardcoded password is created.',
    );
    return;
  }

  // المستخدم الموجود محليًا يحتفظ ببيانات اعتماده المحلية،
  // بما فيها PBKDF2 + Salt. لا نعيد تعيين كلمة المرور هنا.
  debugPrint('Existing admin preserved; no credentials were changed.');
}
