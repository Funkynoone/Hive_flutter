import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Ensure you have this file configured for Firebase initialization
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
      home: MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // Pages to navigate to, replace with your actual screens
  final List<Widget> _pages = [
    DashboardScreen(), // Placeholder, replace with actual screens
    // Add other screens here
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          // User is signed in, show the main screen
          return Scaffold(
            body: _pages[_selectedIndex], // Show the selected page
            bottomNavigationBar: BottomNavigationBar(
              items: <BottomNavigationBarItem>[
                BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
                // Define other items here
              ],
              currentIndex: _selectedIndex,
              onTap: (index) => setState(() => _selectedIndex = index),
            ),
          );
        } else {
          // No user is signed in, show the login screen
          return LoginScreen();
        }
      },
    );
  }
}
