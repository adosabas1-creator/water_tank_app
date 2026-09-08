import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'core/auth/user_provider.dart';
import 'screens/login/login_screen.dart';
import 'core/database/seed.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider<UserProvider>(
      create: (_) => UserProvider(),
      child: const MyApp(),
    ),
  );

  _initializeFirebase();
  _initializeDatabase();
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
