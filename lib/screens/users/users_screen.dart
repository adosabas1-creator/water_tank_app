import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../../core/auth/auth_service.dart';
import '../../core/constants/permissions.dart';
import '../../services/driver_service.dart';
import '../../models/driver.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final AuthService _authService = AuthService();
  final DriverService _driverService = DriverService();

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
}
