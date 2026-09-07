#!/usr/bin/env bash

# 1. شاشة إدارة المستخدمين والصلاحيات
cat > lib/screens/users/users_screen.dart << 'DART'
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
DART

# 2. شاشة سجل العمليات
cat > lib/screens/logs/logs_screen.dart << 'DART'
import 'package:flutter/material.dart';
import '../../models/operation_log.dart';
import '../../services/operation_log_service.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});
  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final OperationLogService _service = OperationLogService();
  late Future<List<OperationLog>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getAllLogs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سجل العمليات')),
      body: FutureBuilder<List<OperationLog>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final logs = snapshot.data!;
          if (logs.isEmpty) return const Center(child: Text('لا توجد عمليات مسجلة'));
          return ListView.builder(
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              return ListTile(
                leading: Icon(
                  log.action == 'create' ? Icons.add_circle : log.action == 'update' ? Icons.edit : Icons.delete,
                  color: log.action == 'create' ? Colors.green : log.action == 'update' ? Colors.blue : Colors.red,
                ),
                title: Text('${log.tableName} #${log.recordId}'),
                subtitle: Text(log.details ?? ''),
                trailing: Text(log.timestamp.substring(0, 16)),
              );
            },
          );
        },
      ),
    );
  }
}
DART

# 3. تحديث main.dart (إضافة المسارات والمزامنة التلقائية)
cat > lib/main.dart << 'DART'
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'core/constants/app_constants.dart';
import 'core/database/seed.dart';
import 'core/network/connectivity_service.dart';
import 'core/network/sync_service.dart';
import 'core/auth/user_provider.dart';
import 'screens/login/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/clients/clients_screen.dart';
import 'screens/suppliers/suppliers_screen.dart';
import 'screens/drivers/drivers_screen.dart';
import 'screens/tanks/tanks_screen.dart';
import 'screens/filling/filling_screen.dart';
import 'screens/sales/sales_screen.dart';
import 'screens/payments/payments_screen.dart';
import 'screens/expenses/expenses_screen.dart';
import 'screens/salaries/salaries_screen.dart';
import 'screens/reports/reports_screen.dart';
import 'screens/statements/statements_screen.dart';
import 'screens/users/users_screen.dart';
import 'screens/logs/logs_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await seedAdminUser();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ConnectivityService _connectivityService = ConnectivityService();
  final SyncService _syncService = SyncService();
  StreamSubscription<bool>? _connectivitySub;
  Timer? _backupTimer;

  @override
  void initState() {
    super.initState();
    _connectivitySub = _connectivityService.onConnectivityChanged.listen((isOnline) {
      if (isOnline) {
        _syncService.syncAll();
      }
    });
    _backupTimer = Timer.periodic(const Duration(hours: 24), (_) {
      _syncService.dailyBackup();
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _backupTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ConnectivityService>.value(value: _connectivityService),
        Provider<SyncService>.value(value: _syncService),
        ChangeNotifierProvider<UserProvider>(create: (_) => UserProvider()),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: const LoginScreen(),
        routes: {
          '/dashboard': (context) => const DashboardScreen(),
          '/clients': (context) => const ClientsScreen(),
          '/suppliers': (context) => const SuppliersScreen(),
          '/drivers': (context) => const DriversScreen(),
          '/tanks': (context) => const TanksScreen(),
          '/filling': (context) => const FillingScreen(),
          '/sales': (context) => const SalesScreen(),
          '/payments': (context) => const PaymentsScreen(),
          '/expenses': (context) => const ExpensesScreen(),
          '/salaries': (context) => const SalariesScreen(),
          '/reports': (context) => const ReportsScreen(),
          '/statements': (context) => const StatementsScreen(),
          '/users': (context) => const UsersScreen(),
          '/logs': (context) => const LogsScreen(),
        },
      ),
    );
  }
}
DART

# 4. تحديث pubspec.yaml (إزالة الخطوط لتجنب الأخطاء)
cat > pubspec.yaml << 'YAML'
name: water_tank_app
description: تطبيق شركة البرعي للمياه
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  provider: ^6.0.5
  sqflite: ^2.3.0
  path_provider: ^2.1.1
  firebase_core: ^2.24.2
  cloud_firestore: ^4.13.6
  firebase_auth: ^4.15.3
  connectivity_plus: ^5.0.2
  url_launcher: ^6.2.1
  crypto: ^3.0.3
  intl: ^0.18.1
  shared_preferences: ^2.2.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0

flutter:
  uses-material-design: true
YAML

echo "✅ تم إكمال التطبيق بنجاح!"
