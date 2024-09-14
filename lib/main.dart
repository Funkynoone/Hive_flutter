import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'auth_wrapper.dart'; // Ensure this is correctly imported

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    await dotenv.load(fileName: ".env");
  }

  await Firebase.initializeApp(
    options: kIsWeb
        ? FirebaseOptions(
      apiKey: "AIzaSyB6q0xYkFMXomhYwp5SI4iAZDRsLXVnTrE",
      authDomain: "vesta-5e1d2.firebaseapp.com",
      projectId: "vesta-5e1d2",
      storageBucket: "vesta-5e1d2.appspot.com",
      messagingSenderId: "260182988802",
      appId: "1:260182988802:android:4612fd57e0ba30f0dcef1b",
    )
        : DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hive Flutter',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const AuthWrapper(), // Ensure AuthWrapper is correctly implemented
    );
  }
}
