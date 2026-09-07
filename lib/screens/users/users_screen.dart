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
    setState(() => _future = _authService.getAllUsers());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المستخدمون والصلاحيات')),
      body: FutureBuilder<List<User>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final users = snapshot.data!;
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                title: Text(user.fullName),
                subtitle: Text(user.role),
                trailing: IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () => _showPermissionsDialog(user),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showPermissionsDialog(User user) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('صلاحيات ${user.fullName}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildCheckbox(setState, user, PermissionKeys.clientsView, 'مشاهدة العملاء'),
                  _buildCheckbox(setState, user, PermissionKeys.clientsAdd, 'إضافة عميل'),
                  _buildCheckbox(setState, user, PermissionKeys.clientsEdit, 'تعديل عميل'),
                  _buildCheckbox(setState, user, PermissionKeys.clientsDelete, 'حذف عميل'),
                  Divider(),
                  _buildCheckbox(setState, user, PermissionKeys.salesView, 'مشاهدة المبيعات'),
                  _buildCheckbox(setState, user, PermissionKeys.salesAdd, 'إضافة مبيعات'),
                  _buildCheckbox(setState, user, PermissionKeys.salesEdit, 'تعديل المبيعات'),
                  _buildCheckbox(setState, user, PermissionKeys.salesDelete, 'حذف المبيعات'),
                  Divider(),
                  _buildCheckbox(setState, user, PermissionKeys.suppliersView, 'مشاهدة الموردين'),
                  _buildCheckbox(setState, user, PermissionKeys.suppliersAdd, 'إضافة مورد'),
                  _buildCheckbox(setState, user, PermissionKeys.suppliersEdit, 'تعديل مورد'),
                  _buildCheckbox(setState, user, PermissionKeys.suppliersDelete, 'حذف مورد'),
                  Divider(),
                  _buildCheckbox(setState, user, PermissionKeys.clientStatementsView, 'كشف حساب العملاء'),
                  _buildCheckbox(setState, user, PermissionKeys.supplierStatementsView, 'كشف حساب الموردين'),
                  Divider(),
                  _buildCheckbox(setState, user, PermissionKeys.profitsView, 'مشاهدة الأرباح'),
                  _buildCheckbox(setState, user, PermissionKeys.pricesEdit, 'تعديل الأسعار'),
                  Divider(),
                  _buildCheckbox(setState, user, PermissionKeys.usersManage, 'إدارة المستخدمين'),
                  _buildCheckbox(setState, user, PermissionKeys.permissionsManage, 'تعديل الصلاحيات'),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              ElevatedButton(
                onPressed: () async {
                  await _authService.updatePermissions(user.id!, user.permissions);
                  if (context.mounted) Navigator.pop(context);
                  _refresh();
                },
                child: const Text('حفظ'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCheckbox(StateSetter setState, User user, String key, String label) {
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
