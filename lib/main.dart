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
