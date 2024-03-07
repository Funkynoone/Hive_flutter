import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dashboard_screen.dart'; // Your dashboard screen
import 'login_screen.dart'; // Your login screen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Your App Title',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      // Use named routes to manage navigation
      initialRoute: FirebaseAuth.instance.currentUser == null ? '/login' : '/dashboard',
      routes: {
        '/dashboard': (context) => DashboardScreen(),
        '/login': (context) => LoginScreen(), // Ensure you have a LoginScreen widget
        // Define other routes as needed
      },
    );
  }
}
