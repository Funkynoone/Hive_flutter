import 'package:flutter/material.dart';
import 'package:hive_flutter/profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/jobs_screen.dart';
import 'package:hive_flutter/add_job_screen.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0; // Adjust if needed based on your actual screens

  late final List<Widget> _screens;

  _DashboardScreenState() {
    _screens = [
      // Assuming you replace these with actual screens you have
      Center(child: Text('Explore Screen')), // Placeholder for ExploreScreen
      JobsScreen(),
      AddJobScreen(),
      Center(child: Text('Saved Screen')), // Placeholder for SavedScreen
      ProfileScreen(onLogout: () async {
        // Sign out from Firebase Auth
        await FirebaseAuth.instance.signOut();

        // Navigate to the login page
        Navigator.pushReplacementNamed(context, '/login');
      }),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('App'), // Adjust based on the selected screen if needed
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Explore'),
          BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Jobs'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: 'Add Post'),
          BottomNavigationBarItem(icon: Icon(Icons.save_alt), label: 'Saved'),
          BottomNavigationBarItem(icon: Icon(Icons.account_circle), label: 'Profile'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber[800],
        onTap: _onItemTapped,
      ),
    );
  }
}
