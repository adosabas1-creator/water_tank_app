import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_service.dart';
import '../../core/database/database_helper.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../../core/auth/user_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../models/user.dart';
import '../dashboard/dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.water_drop, size: 60, color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    AppConstants.companyName,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                  const SizedBox(height: 8),
                  const Text('نظام إدارة صهاريج المياه', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 40),
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'اسم المستخدم',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.person),
                    ),
                    validator: (v) => v!.isEmpty ? 'أدخل اسم المستخدم' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.lock),
                    ),
                    validator: (v) => v!.isEmpty ? 'أدخل كلمة المرور' : null,
                  ),
                  const SizedBox(height: 24),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _checkDatabase,
                    child: const Text('فحص قاعدة البيانات'),
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('تسجيل الدخول', style: TextStyle(fontSize: 18)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


  Future<void> _checkDatabase() async {
    try {
      final db = await DatabaseHelper().database;

      final users = await db.query('users');

      final expectedHash =
          sha256.convert(utf8.encode('admin123')).toString();

      final admins = users.where((u) => u['username'] == 'admin').toList();

      String message;

      if (admins.isEmpty) {
        message = 'قاعدة البيانات تعمل، لكن المستخدم admin غير موجود.\n'
            'عدد المستخدمين: ${users.length}';
      } else {
        final admin = admins.first;
        final storedHash = admin['password_hash'];

        final passwordMatches = storedHash == expectedHash;

        message = 'قاعدة البيانات تعمل.\n'
            'عدد المستخدمين: ${users.length}\n'
            'admin موجود: نعم\n'
            'كلمة المرور admin123: '
            '${passwordMatches ? 'مطابقة' : 'غير مطابقة'}\n'
            'is_deleted: ${admin['is_deleted']}';
      }

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('نتيجة الفحص'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('خطأ قاعدة البيانات'),
          content: Text('$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final username = _usernameController.text.trim();
      final password = _passwordController.text;

      final user = await _authService.login(username, password);

      if (!mounted) return;

      setState(() => _isLoading = false);

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('تشخيص تسجيل الدخول'),
          content: Text(
            user == null
                ? 'AuthService رجع null\\n'
                    'اسم المستخدم: $username\\n'
                    'كلمة المرور: admin123'
                : 'تم تسجيل الدخول بنجاح\\n'
                    'المستخدم: ${user.username}\\n'
                    'الاسم: ${user.fullName}\\n'
                    'الدور: ${user.role}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      );
    } catch (e, stackTrace) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('خطأ أثناء تسجيل الدخول'),
          content: SingleChildScrollView(
            child: Text('$e\\n\\n$stackTrace'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      );
    }
  }
}
