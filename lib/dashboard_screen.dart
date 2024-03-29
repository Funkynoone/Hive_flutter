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
  int _selectedIndex = 0;
  bool isBusinessOwner = false; // This will be set based on the logged-in user's role

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    fetchUserRole(); // Function to determine if the user is a business owner
  }

  void fetchUserRole() async {
    // Assuming you're storing the user's role in Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final docSnapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      setState(() {
        isBusinessOwner = docSnapshot['isBusinessOwner'] ?? false;
        // Initialize _screens here after fetching user role
        _initializeScreens();
      });
    }
  }

  void _initializeScreens() {
    _screens = [
      Center(child: Text('Explore Screen')), // Placeholder for ExploreScreen
      JobsScreen(),
      if (isBusinessOwner) AddJobScreen(),
      Center(child: Text('Saved Screen')), // Placeholder for SavedScreen
      ProfileScreen(onLogout: () async {
        await FirebaseAuth.instance.signOut();
        Navigator.pushReplacementNamed(context, '/login');
      }),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Define BottomNavigationBarItems based on the user's role
    List<BottomNavigationBarItem> navBarItems = [
      BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Explore'),
      BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Jobs'),
      if (isBusinessOwner) BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: 'Add Post'),
      BottomNavigationBarItem(icon: Icon(Icons.save_alt), label: 'Saved'),
      BottomNavigationBarItem(icon: Icon(Icons.account_circle), label: 'Profile'),
    ];

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
        items: navBarItems,
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.amber[800],
        onTap: _onItemTapped,
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
}
