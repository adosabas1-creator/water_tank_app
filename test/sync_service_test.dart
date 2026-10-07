import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'test-api-key',
        appId: '1:40842409498:android:64640f7b962865508083a3',
        messagingSenderId: '40842409498',
        projectId: 'alborai-water-tank',
      ),
    );

    await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
  });

  test('Firebase Emulator: Auth + Firestore يعملان', () async {
    final credential = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(
      email: 'sync-test@example.com',
      password: 'test123456',
    );

    expect(credential.user, isNotNull);

    await FirebaseFirestore.instance
        .collection('emulator_test')
        .doc('sync_test')
        .set({
      'message': 'ok',
      'uid': credential.user!.uid,
    });

    final snapshot = await FirebaseFirestore.instance
        .collection('emulator_test')
        .doc('sync_test')
        .get();

    expect(snapshot.exists, isTrue);
    expect(snapshot.data()?['message'], 'ok');
  });
}
