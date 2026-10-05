import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'core/auth/user_provider.dart';
import 'core/auth/inactivity_watcher.dart';
import 'screens/login/login_screen.dart';
import 'core/database/seed.dart';
import 'core/database/financial_migration.dart';
import 'core/database/database_helper.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/clients/clients_screen.dart';
import 'screens/suppliers/suppliers_screen.dart';
import 'screens/sales/sales_screen.dart';
import 'screens/payments/payments_screen.dart';
import 'screens/expenses/expenses_screen.dart';
import 'screens/salaries/salaries_screen.dart';
import 'screens/reports/reports_screen.dart';
import 'screens/statements/statements_screen.dart';
import 'screens/purchases/purchases_screen.dart';
import 'screens/users/users_screen.dart';
import 'screens/logs/logs_screen.dart';
import 'services/backup_service.dart';
import 'core/network/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _initializeFirebase();
  await _initializeDatabase();

  // استعادة الجلسة قبل تشغيل الخدمات التي تعتمد على المستخدم والصلاحيات.
  final userProvider = UserProvider();
  await userProvider.restoreSession();

  // بدء المزامنة بعد جاهزية Firebase وقاعدة البيانات والجلسة.
  SyncService().startAutoSync();

  // تشغيل واجهة التطبيق دون انتظار النسخ الاحتياطي أو المزامنة الأولية.
  runApp(
    ChangeNotifierProvider<UserProvider>.value(
      value: userProvider,
      child: const MyApp(),
    ),
  );

  // النسخ التلقائي والمزامنة الأولية يعملان في الخلفية.
  unawaited(_runAutomaticBackup());
  unawaited(SyncService().syncAll());
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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<UserProvider>().currentUser;
    final home = currentUser != null
        ? const DashboardScreen()
        : const LoginScreen();

    return InactivityWatcher(
      navigatorKey: _navigatorKey,
      timeout: const Duration(minutes: 15),
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'شركة البرعي للمياه',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: home,
        routes: {
          '/login': (context) => const LoginScreen(),
          '/dashboard': (context) => const DashboardScreen(),
          '/clients': (context) => const ClientsScreen(),
          '/suppliers': (context) => const SuppliersScreen(),
          '/sales': (context) => const SalesScreen(),
          '/purchases': (context) => const PurchasesScreen(),
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

Future<void> _initializeDatabase() async {
  try {
    await seedAdminUser();
    final db = await DatabaseHelper().database;
    await FinancialMigration.migrate(db);
    debugPrint('Local database initialized successfully');
  } catch (e, stackTrace) {
    debugPrint('Local database initialization failed: $e');
    debugPrint('$stackTrace');
  }
}
