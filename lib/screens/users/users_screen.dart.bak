import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/user.dart';
import '../../core/auth/auth_service.dart';
import '../../core/constants/permissions.dart';
import '../../services/driver_service.dart';
import '../../models/driver.dart';
import '../../services/backup_service.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final AuthService _authService = AuthService();
  final DriverService _driverService = DriverService();
  final BackupService _backupService = BackupService();

  late Future<List<User>> _future;

  @override
  void initState() {
    super.initState();
    _future = _authService.getAllUsers();
  }

  void _refresh() {
    if (!mounted) return;

    setState(() {
      _future = _authService.getAllUsers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المستخدمون والصلاحيات'),
        actions: [
          IconButton(
            onPressed: _refresh,
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: _showAddUserDialog,
            tooltip: 'إضافة مستخدم',
            icon: const Icon(Icons.person_add),
          ),
          PopupMenuButton<String>(
            tooltip: 'النسخ الاحتياطي',
            onSelected: (value) {
              switch (value) {
                case 'backup':
                  _createBackup();
                  break;
                case 'restore':
                  _restoreBackup();
                  break;
                case 'email':
                  _sendBackupByEmail();
                  break;
                case 'settings':
                  _showBackupSettings();
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'backup',
                child: ListTile(
                  leading: Icon(Icons.backup),
                  title: Text('نسخ احتياطي الآن'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'email',
                child: ListTile(
                  leading: Icon(Icons.email_outlined),
                  title: Text('إرسال النسخة إلى البريد'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'restore',
                child: ListTile(
                  leading: Icon(Icons.restore),
                  title: Text('استعادة نسخة احتياطية'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings_backup_restore),
                  title: Text('إعدادات النسخ التلقائي'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: FutureBuilder<List<User>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _buildError();
          }

          final users = snapshot.data ?? [];

          if (users.isEmpty) {
            return const Center(
              child: Text('لا يوجد مستخدمون'),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              _refresh();
              await _future;
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: users.length,
              separatorBuilder: (_, __) => const Divider(
                height: 1,
              ),
              itemBuilder: (context, index) {
                final user = users[index];

                return ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      user.fullName.isNotEmpty ? user.fullName[0] : '?',
                    ),
                  ),
                  title: Text(
                    user.fullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'اسم المستخدم: ${user.username}\n'
                    'الدور: ${user.role}',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(
                    Icons.settings,
                  ),
                  onTap: () => _showPermissionsDialog(user),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
            ),
            const SizedBox(height: 12),
            const Text(
              'حدث خطأ أثناء تحميل المستخدمين',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddUserDialog() async {
    final usernameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final fullNameCtrl = TextEditingController();

    String role = 'driver';
    int? selectedDriverId;
    bool isSaving = false;
    List<Driver> drivers = [];

    try {
      drivers = await _driverService.getAllDrivers();
    } catch (_) {}

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final usedDriverIds = <int>{};

            return FutureBuilder<List<User>>(
              future: _authService.getAllUsers(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  for (final u in snapshot.data!) {
                    if (u.driverId != null) {
                      usedDriverIds.add(u.driverId!);
                    }
                  }
                }

                final availableDrivers = drivers.where((driver) {
                  return driver.id != null &&
                      (!usedDriverIds.contains(driver.id) ||
                          driver.id == selectedDriverId);
                }).toList();

                Future<void> save() async {
                  if (isSaving) return;

                  final username = usernameCtrl.text.trim();
                  final email = emailCtrl.text.trim();
                  final password = passwordCtrl.text;
                  final fullName = fullNameCtrl.text.trim();

                  if (username.isEmpty ||
                      password.isEmpty ||
                      fullName.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('يرجى إكمال جميع الحقول المطلوبة'),
                      ),
                    );
                    return;
                  }

                  if (password.length < 6) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('كلمة المرور يجب أن تكون 6 أحرف على الأقل'),
                      ),
                    );
                    return;
                  }

                  if (role == 'driver' && selectedDriverId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('يرجى اختيار السائق'),
                      ),
                    );
                    return;
                  }

                  setDialogState(() => isSaving = true);

                  try {
                    Map<String, bool> permissions;

                    if (role == 'driver') {
                      permissions = DefaultPermissions.driver();
                    } else {
                      permissions = DefaultPermissions.deputyManager();
                    }

                    await _authService.createUser(
                      username: username,
                      password: password,
                      firebaseEmail: email,
                      fullName: fullName,
                      role: role,
                      driverId: role == 'driver' ? selectedDriverId : null,
                      permissions: permissions,
                    );

                    if (!context.mounted) return;

                    Navigator.pop(context);
                    _refresh();

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم إنشاء المستخدم بنجاح'),
                      ),
                    );
                  } catch (e) {
                    if (!context.mounted) return;

                    setDialogState(() => isSaving = false);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('حدث خطأ أثناء إنشاء المستخدم:\n$e'),
                      ),
                    );
                  }
                }

                return AlertDialog(
                  title: const Text('إضافة مستخدم'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: fullNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'الاسم الكامل *',
                          ),
                        ),
                        TextField(
                          controller: usernameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'اسم المستخدم *',
                          ),
                        ),
                        TextField(
                          controller: emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'البريد الإلكتروني لـ Firebase (اختياري)',
                          ),
                        ),
                        TextField(
                          controller: passwordCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'كلمة المرور *',
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: role,
                          decoration: const InputDecoration(
                            labelText: 'الدور',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'driver',
                              child: Text('سائق'),
                            ),
                            DropdownMenuItem(
                              value: 'deputy_manager',
                              child: Text('نائب مدير'),
                            ),
                          ],
                          onChanged: isSaving
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setDialogState(() {
                                    role = value;
                                    selectedDriverId = null;
                                  });
                                },
                        ),
                        if (role == 'driver') ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            initialValue: availableDrivers.any(
                              (d) => d.id == selectedDriverId,
                            )
                                ? selectedDriverId
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'السائق المرتبط بالحساب *',
                              border: OutlineInputBorder(),
                            ),
                            items: availableDrivers.map((driver) {
                              return DropdownMenuItem<int>(
                                value: driver.id,
                                child: Text(driver.name),
                              );
                            }).toList(),
                            onChanged: isSaving
                                ? null
                                : (value) {
                                    setDialogState(() {
                                      selectedDriverId = value;
                                    });
                                  },
                          ),
                          if (availableDrivers.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                'لا يوجد سائقون متاحون للربط',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: isSaving ? null : () => Navigator.pop(context),
                      child: const Text('إلغاء'),
                    ),
                    FilledButton(
                      onPressed: isSaving ? null : save,
                      child: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('حفظ'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _setRecoveryCode(User user) async {
    final random = Random.secure();
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final code = List.generate(
      10,
      (_) => chars[random.nextInt(chars.length)],
    ).join();

    try {
      final success = await _authService.setRecoveryCode(
        userId: user.id!,
        recoveryCode: code,
      );

      if (!mounted) return;

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر إعداد رمز الاسترداد'),
          ),
        );
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('رمز الاسترداد'),
            content: SelectableText(
              'المستخدم: ${user.fullName}\\n\\n'
              'رمز الاسترداد:\\n$code\\n\\n'
              'احفظ هذا الرمز في مكان آمن وأعطه للمستخدم. '
              'لن يتم عرض الرمز مرة أخرى بعد إغلاق هذه النافذة.',
              textAlign: TextAlign.center,
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('تم الحفظ'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء إعداد رمز الاسترداد: $e'),
        ),
      );
    }
  }

  Future<void> _showPermissionsDialog(User user) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        bool isSaving = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              if (isSaving) return;

              setDialogState(() {
                isSaving = true;
              });

              try {
                await _authService.updatePermissions(
                  user.id!,
                  user.permissions,
                );

                if (!context.mounted) return;

                Navigator.pop(context);

                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'تم حفظ الصلاحيات بنجاح',
                    ),
                  ),
                );

                _refresh();
              } catch (e) {
                if (!context.mounted) return;

                setDialogState(() {
                  isSaving = false;
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'حدث خطأ أثناء حفظ الصلاحيات:\n$e',
                    ),
                  ),
                );
              }
            }

            return AlertDialog(
              title: Text(
                'صلاحيات ${user.fullName}',
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.lock_reset),
                      title: const Text('تغيير كلمة المرور'),
                      subtitle: const Text(
                        'تعيين كلمة مرور جديدة لهذا المستخدم',
                      ),
                      contentPadding: EdgeInsets.zero,
                      onTap: () {
                        Navigator.pop(context);
                        _changeUserPassword(user);
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.key),
                      title: const Text('إعداد رمز الاسترداد'),
                      subtitle: const Text(
                        'إنشاء رمز جديد لاستعادة كلمة المرور',
                      ),
                      contentPadding: EdgeInsets.zero,
                      onTap: () {
                        Navigator.pop(context);
                        _setRecoveryCode(user);
                      },
                    ),
                    const Divider(),
                    _buildCheckbox(
                      setDialogState,
                      user,
                      PermissionKeys.clientsView,
                      'مشاهدة العملاء',
                    ),
                    _buildCheckbox(
                      setDialogState,
                      user,
                      PermissionKeys.clientsAdd,
                      'إضافة عميل',
                    ),
                    _buildCheckbox(
                      setDialogState,
                      user,
                      PermissionKeys.clientsEdit,
                      'تعديل عميل',
                    ),
                    _buildCheckbox(
                      setDialogState,
                      user,
                      PermissionKeys.clientsDelete,
                      'حذف عميل',
                    ),
                    const Divider(),
                    _buildCheckbox(
                      setDialogState,
                      user,
                      PermissionKeys.salesView,
                      'مشاهدة المبيعات',
                    ),
                    _buildCheckbox(
                      setDialogState,
                      user,
                      PermissionKeys.salesAdd,
                      'إضافة مبيعات',
                    ),
                    _buildCheckbox(
                      setDialogState,
                      user,
                      PermissionKeys.salesEdit,
                      'تعديل المبيعات',
                    ),
                    _buildCheckbox(
                      setDialogState,
                      user,
                      PermissionKeys.salesDelete,
                      'حذف المبيعات',
                    ),
                    const Divider(),
                    _buildCheckbox(
                      setDialogState,
                      user,
                      PermissionKeys.suppliersView,
                      'مشاهدة الموردين',
                    ),
                    _buildCheckbox(
                      setDialogState,
                      user,
                      PermissionKeys.suppliersAdd,
                      'إضافة مورد',
                    ),
                    _buildCheckbox(
                      setDialogState,
                      user,
                      PermissionKeys.suppliersEdit,
                      'تعديل مورد',
                    ),
                    _buildCheckbox(
                      setDialogState,
                      user,
                      PermissionKeys.suppliersDelete,
                      'حذف مورد',
                    ),
                    const Divider(),
                    _buildCheckbox(
                      setDialogState,
                      user,
                      PermissionKeys.driversView,
                      'مشاهدة السائقين',
                    ),
                    _buildCheckbox(
                      setDialogState,
                      user,
                      PermissionKeys.driversAdd,
                      'إضافة سائق',
                    ),
                    _buildCheckbox(
                      setDialogState,
                      user,
                      PermissionKeys.driversEdit,
                      'تعديل السائقين',
                    ),
                    _buildCheckbox(
                      setDialogState,
                      user,
                      PermissionKeys.driversDelete,
                      'حذف السائقين',
                    ),
                    const Divider(),
                    _buildCheckbox(
                      setDialogState,
                      user,
                      PermissionKeys.clientStatementsView,
                      'كشف حساب العملاء',
                    ),
                    _buildCheckbox(
                      setDialogState,
                      user,
                      PermissionKeys.supplierStatementsView,
                      'كشف حساب الموردين',
                    ),
                    const Divider(),
                    _buildCheckbox(
                      setDialogState,
                      user,
                      PermissionKeys.profitsView,
                      'مشاهدة الأرباح',
                    ),
                    _buildCheckbox(
                      setDialogState,
                      user,
                      PermissionKeys.pricesEdit,
                      'تعديل الأسعار',
                    ),
                    const Divider(),
                    _buildCheckbox(
                      setDialogState,
                      user,
                      PermissionKeys.usersManage,
                      'إدارة المستخدمين',
                    ),
                    _buildCheckbox(
                      setDialogState,
                      user,
                      PermissionKeys.permissionsManage,
                      'تعديل الصلاحيات',
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: isSaving ? null : save,
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _changeUserPassword(User user) async {
    final passwordCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          bool isSaving = false;

          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> save() async {
                final password = passwordCtrl.text;
                final confirm = confirmCtrl.text;

                if (password.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'كلمة المرور يجب أن تكون 6 أحرف أو أرقام على الأقل',
                      ),
                    ),
                  );
                  return;
                }

                if (password != confirm) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('كلمتا المرور غير متطابقتين'),
                    ),
                  );
                  return;
                }

                setDialogState(() {
                  isSaving = true;
                });

                try {
                  final updated = await _authService.updateUserPassword(
                    userId: user.id!,
                    newPassword: password,
                  );

                  if (!context.mounted) return;
                  Navigator.pop(context, updated);
                } catch (e) {
                  if (!context.mounted) return;

                  setDialogState(() {
                    isSaving = false;
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('حدث خطأ أثناء تغيير كلمة المرور:\n$e'),
                    ),
                  );
                }
              }

              return AlertDialog(
                title: Text('تغيير كلمة مرور ${user.fullName}'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: passwordCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'كلمة المرور الجديدة',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'تأكيد كلمة المرور',
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () => Navigator.pop(context, false),
                    child: const Text('إلغاء'),
                  ),
                  FilledButton(
                    onPressed: isSaving ? null : save,
                    child: isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('حفظ'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (result == true && mounted) {
        _refresh();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تغيير كلمة المرور بنجاح'),
          ),
        );
      }
    } finally {
      passwordCtrl.dispose();
      confirmCtrl.dispose();
    }
  }

  Widget _buildCheckbox(
    StateSetter setState,
    User user,
    String key,
    String label,
  ) {
    return CheckboxListTile(
      title: Text(label),
      value: user.permissions[key] ?? false,
      onChanged: (value) {
        setState(() {
          user.permissions[key] = value ?? false;
        });
      },
    );
  }

  Future<void> _createBackup() async {
    try {
      final path = await _backupService.createManualBackup();

      if (!mounted || path == null) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إنشاء النسخة الاحتياطية بنجاح:\n$path'),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر إنشاء النسخة الاحتياطية:\n$e'),
        ),
      );
    }
  }

  Future<void> _sendBackupByEmail() async {
    try {
      final path = await _backupService.createManualBackup();

      if (!mounted || path == null) return;

      await const MethodChannel(
        'com.alborai.water_tank_app/backup',
      ).invokeMethod(
        'sendBackupByEmail',
        <String, dynamic>{
          'filePath': path,
        },
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر تجهيز النسخة للإرسال بالبريد:\n$e'),
        ),
      );
    }
  }

  Future<void> _restoreBackup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('استعادة نسخة احتياطية'),
        content: const Text(
          'سيتم استبدال قاعدة البيانات الحالية بالنسخة المختارة. '
          'هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('استعادة'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final restored = await _backupService.restoreBackup();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            restored
                ? 'تمت استعادة النسخة الاحتياطية بنجاح. أعد تشغيل التطبيق.'
                : 'تم إلغاء الاستعادة.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر استعادة النسخة الاحتياطية:\n$e'),
        ),
      );
    }
  }

  Future<void> _showBackupSettings() async {
    var enabled = await _backupService.isAutomaticBackupEnabled();
    var frequency = await _backupService.getAutomaticBackupFrequency();

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('إعدادات النسخ التلقائي'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('تفعيل النسخ التلقائي'),
                    value: enabled,
                    onChanged: (value) async {
                      await _backupService.setAutomaticBackupEnabled(value);
                      setDialogState(() {
                        enabled = value;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: frequency,
                    decoration: const InputDecoration(
                      labelText: 'التكرار',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'daily',
                        child: Text('يومي'),
                      ),
                      DropdownMenuItem(
                        value: 'weekly',
                        child: Text('أسبوعي'),
                      ),
                    ],
                    onChanged: !enabled
                        ? null
                        : (value) async {
                            if (value == null) return;

                            await _backupService
                                .setAutomaticBackupFrequency(value);

                            setDialogState(() {
                              frequency = value;
                            });
                          },
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'يتم الاحتفاظ بآخر 7 نسخ تلقائية.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('إغلاق'),
                ),
              ],
            );
          },
        );
      },
    );
  }


}
