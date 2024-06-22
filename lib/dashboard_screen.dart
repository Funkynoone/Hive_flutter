import 'package:flutter/material.dart';
import 'package:hive_flutter/profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/jobs_screen.dart';
import 'package:hive_flutter/add_job_screen.dart';
import 'package:badges/badges.dart' as Badges; // Import the Badges package

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  bool isBusinessOwner = false; // This will be set based on the logged-in user's role
  int _newApplicationsCount = 0; // Counter for new applications

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    fetchUserRole(); // Function to determine if the user is a business owner
    _fetchApplicationsCount(); // Fetch applications count
  }

  void fetchUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final docSnapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      setState(() {
        isBusinessOwner = docSnapshot['isBusinessOwner'] ?? false;
        _initializeScreens();
      });
    }
  }

  void _initializeScreens() {
    List<Widget> screens = [
      const Center(child: Text('Explore Screen')), // Placeholder for ExploreScreen
      const JobsScreen(),
      const Center(child: Text('Saved Screen')), // Placeholder for SavedScreen
      ProfileScreen(onLogout: () async {
        await FirebaseAuth.instance.signOut();
        Navigator.pushReplacementNamed(context, '/login');
      }),
    ];

    if (isBusinessOwner) {
      screens.insert(2, const AddJobScreen());
    }

    setState(() {
      _screens = screens;
    });
  }

  void _fetchApplicationsCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      QuerySnapshot jobSnapshot = await FirebaseFirestore.instance
          .collection('JobListings')
          .where('ownerId', isEqualTo: user.uid)
          .get();

      int newApplicationsCount = 0;
      for (var jobDoc in jobSnapshot.docs) {
        QuerySnapshot applicationSnapshot = await FirebaseFirestore.instance
            .collection('JobListings')
            .doc(jobDoc.id)
            .collection('Applications')
            .where('status', isEqualTo: 'pending')
            .get();
        newApplicationsCount += applicationSnapshot.docs.length;
      }

      setState(() {
        _newApplicationsCount = newApplicationsCount;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    List<BottomNavigationBarItem> navBarItems = [
      const BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Explore'),
      const BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Jobs'),
      if (isBusinessOwner) const BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), label: 'Add Post'),
      const BottomNavigationBarItem(icon: Icon(Icons.save_alt), label: 'Saved'),
      const BottomNavigationBarItem(icon: Icon(Icons.account_circle), label: 'Profile'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('App'),
        actions: [
          if (isBusinessOwner)
            Badges.Badge(
              badgeContent: Text(
                '$_newApplicationsCount',
                style: TextStyle(color: Colors.white),
              ),
              showBadge: _newApplicationsCount > 0,
              position: Badges.BadgePosition.topEnd(top: 0, end: 3),
              child: IconButton(
                icon: Icon(Icons.notifications),
                onPressed: () {
                  // Navigate to notifications or refresh the count
                  _fetchApplicationsCount(); // For example, refresh the count
                },
              ),
            ),
        ],
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
