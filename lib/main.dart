import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'core/auth/user_provider.dart';
import 'screens/login/login_screen.dart';
import 'core/database/seed.dart';
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
import 'services/backup_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _initializeFirebase();
  await _initializeDatabase();
  await _runAutomaticBackup();

  runApp(
    ChangeNotifierProvider<UserProvider>(
      create: (_) => UserProvider(),
      child: const MyApp(),
    ),
  );
}

Future<void> _runAutomaticBackup() async {
  try {
    final backupService = BackupService();
    await backupService.runAutomaticBackupIfDue();
    debugPrint('Automatic backup check completed');
  } catch (e, stackTrace) {
    debugPrint('Automatic backup failed: $e');
    debugPrint('$stackTrace');
  }
}

Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp();
    debugPrint('Firebase initialized successfully');
  } catch (e, stackTrace) {
    debugPrint('Firebase initialization failed: $e');
    debugPrint('$stackTrace');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'نظام إدارة صهاريج المياه',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const LoginScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
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
    );
  }
}


Future<void> _initializeDatabase() async {
  try {
    await seedAdminUser();
    debugPrint('Local database initialized successfully');
  } catch (e, stackTrace) {
    debugPrint('Local database initialization failed: $e');
    debugPrint('$stackTrace');
  }
}
