import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../../core/auth/auth_service.dart';
import '../../core/constants/permissions.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final AuthService _authService = AuthService();

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
                      user.fullName.isNotEmpty
                          ? user.fullName[0]
                          : '?',
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

                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'تم حفظ الصلاحيات بنجاح',
                      ),
                    ),
                  );
                }

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
                  onPressed:
                      isSaving ? null : () => Navigator.pop(context),
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
