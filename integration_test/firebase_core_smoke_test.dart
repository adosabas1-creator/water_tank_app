import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Firebase Core initializes with explicit emulator options',
      (tester) async {
    final app = await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'fake-api-key',
        appId: '1:123456789012:android:abcdef1234567890',
        messagingSenderId: '123456789012',
        projectId: 'alborai-water-tank',
        storageBucket: 'alborai-water-tank.firebasestorage.app',
      ),
    ).timeout(
      const Duration(seconds: 45),
      onTimeout: () => throw TimeoutException(
        'Firebase.initializeApp did not complete within 45 seconds',
      ),
    );

    expect(app.name, defaultFirebaseAppName);
    expect(app.options.projectId, 'alborai-water-tank');
    // Do not contact Auth/Firestore here: this test isolates Firebase Core
    // initialization from emulator networking and SyncService dependencies.
    print('FIREBASE_CORE_SMOKE_PASS: ${app.name}');
  });
}
