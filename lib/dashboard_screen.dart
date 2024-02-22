import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/jobs_screen.dart';
import 'package:hive_flutter/add_job_screen.dart';

// Define your other screens here
class ExploreScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Explore Screen'));
  }
}

class SavedScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Saved Screen'));
  }
}

class ProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Profile Screen'));
  }
}

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0; // Starts with ExploreScreen as the initial screen
  final List<Widget> _screens = [
    ExploreScreen(), // This is your 'Dashboard' or 'Explore' screen
    JobsScreen(),
    AddJobScreen(),
    SavedScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Explore'), // Adjust based on the selected screen if needed
      ),
      body: Center(
        child: _screens.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // This ensures all items are fixed to the bottom
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
