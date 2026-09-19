import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_service.dart';
import '../../core/auth/user_provider.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;

    final user = context.read<UserProvider>().currentUser;
    if (user?.id == null) return;

    setState(() => _isLoading = true);

    try {
      // ✅ نمرّر كلمة المرور الحالية لدعم reauthenticate مع Firebase
      final success = await _authService.updateUserPassword(
        userId: user!.id!,
        newPassword: _newPasswordController.text,
        currentPassword: _currentPasswordController.text,
      );

      if (!mounted) return;

      if (success) {
        // إعادة تسجيل الدخول بكلمة المرور الجديدة
        final updatedUser = await _authService.login(
          user.username,
          _newPasswordController.text,
        );

        if (!mounted) return;

        if (updatedUser != null) {
          await context.read<UserProvider>().setUser(updatedUser);
        }

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تغيير كلمة المرور بنجاح')),
        );

        Navigator.of(context).pop();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تغيير كلمة المرور')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('تغيير كلمة المرور'),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const Icon(
                    Icons.lock_reset,
                    size: 80,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'يجب تغيير كلمة المرور قبل متابعة استخدام التطبيق',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 24),

                  // ✅ حقل كلمة المرور الحالية (جديد)
                  TextFormField(
                    controller: _currentPasswordController,
                    obscureText: _obscureCurrentPassword,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور الحالية',
                      helperText: 'مطلوبة للتحقق من هويتك',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureCurrentPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureCurrentPassword = !_obscureCurrentPassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'كلمة المرور الحالية مطلوبة';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // حقل كلمة المرور الجديدة
                  TextFormField(
                    controller: _newPasswordController,
                    obscureText: _obscureNewPassword,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور الجديدة',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNewPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureNewPassword = !_obscureNewPassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.length < 6) {
                        return 'كلمة المرور يجب أن تكون 6 أحرف أو أرقام على الأقل';
                      }
                      if (value == _currentPasswordController.text) {
                        return 'كلمة المرور الجديدة يجب أن تختلف عن الحالية';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // حقل تأكيد كلمة المرور
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'تأكيد كلمة المرور',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value != _newPasswordController.text) {
                        return 'كلمتا المرور غير متطابقتين';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _changePassword,
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text('حفظ كلمة المرور الجديدة'),
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
}
