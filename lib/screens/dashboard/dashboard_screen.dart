import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/user_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/permissions.dart';
import '../../core/auth/permission_service.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.companyName),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<UserProvider>().logout();
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        children: [
          if (PermissionService.hasPermission(user, PermissionKeys.clientsView))
            _buildCard(context, 'العملاء', Icons.people, '/clients'),
          if (PermissionService.hasPermission(user, PermissionKeys.suppliersView))
            _buildCard(context, 'الموردون', Icons.local_shipping, '/suppliers'),
          if (PermissionService.hasPermission(user, PermissionKeys.salesView))
            _buildCard(context, 'المبيعات', Icons.shopping_cart, '/sales'),
          _buildCard(context, 'عمليات التعبئة', Icons.local_gas_station, '/filling'),
          _buildCard(context, 'الصهاريج', Icons.local_fire_department, '/tanks'),
          _buildCard(context, 'السائقون', Icons.drive_eta, '/drivers'),
          _buildCard(context, 'المدفوعات', Icons.payments, '/payments'),
          _buildCard(context, 'المصروفات', Icons.money_off, '/expenses'),
          _buildCard(context, 'الرواتب', Icons.attach_money, '/salaries'),
          _buildCard(context, 'التقارير', Icons.report, '/reports'),
          if (PermissionService.hasAnyPermission(user, [
            PermissionKeys.clientStatementsView,
            PermissionKeys.supplierStatementsView,
          ]))
            _buildCard(context, 'كشوف الحسابات', Icons.receipt_long, '/statements'),
          if (PermissionService.hasPermission(user, PermissionKeys.usersManage))
            _buildCard(context, 'المستخدمون', Icons.admin_panel_settings, '/users'),
          _buildCard(context, 'سجل العمليات', Icons.history, '/logs'),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, String title, IconData icon, String route) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed(route),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Colors.blue),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
