import 'package:flutter/material.dart';
import 'package:hive_flutter/profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/jobs_screen.dart';
import 'package:hive_flutter/add_job_screen.dart';
import 'package:hive_flutter/saved_jobs_screen.dart';
import 'package:hive_flutter/application_manager_screen.dart';
import 'package:hive_flutter/user_applications_screen.dart';
import 'package:hive_flutter/models/notification_model.dart';
import 'package:hive_flutter/services/notification_service.dart';
import 'package:hive_flutter/chat_list_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  bool isBusinessOwner = false;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    fetchUserRole();
  }

  void fetchUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      setState(() {
        isBusinessOwner = docSnapshot['isBusinessOwner'] ?? false;
        _initializeScreens();
      });
    }
  }

  void _initializeScreens() {
    List<Widget> screens = [
      const Center(child: Text('Explore Screen')),
      const JobsScreen(),
      const SavedJobsScreen(),
      ProfileScreen(
        onLogout: () async {
          try {
            await FirebaseAuth.instance.signOut();
            if (mounted) {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/login',
                    (route) => false,
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error logging out: $e')),
              );
            }
          }
        },
      ),
    ];

    if (isBusinessOwner) {
      screens.insert(2, const AddJobScreen());
    }

    setState(() {
      _screens = screens;
    });
  }

  Widget _buildChatButton() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: FirebaseAuth.instance.currentUser?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        int unreadChats = 0;
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final unreadCount = data['unreadCount'] as int? ?? 0;
            final lastSenderId = data['lastSenderId'] as String?;

            if (lastSenderId != FirebaseAuth.instance.currentUser?.uid && unreadCount > 0) {
              unreadChats++;
            }
          }
        }

        return Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ChatListScreen(),
                  ),
                );
              },
            ),
            if (unreadChats > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  child: Text(
                    '$unreadChats',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildNotificationButton() {
    return StreamBuilder<List<NotificationModel>>(
      stream: NotificationService().getNotifications(
        FirebaseAuth.instance.currentUser!.uid,
      ),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data
            ?.where((notification) => !notification.read)
            .length ?? 0;

        return Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.mail_outline),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => isBusinessOwner
                        ? ApplicationManagerScreen(
                      ownerId: FirebaseAuth.instance.currentUser!.uid,
                    )
                        : const UserApplicationsScreen(),
                  ),
                );
              },
            ),
            if (unreadCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  child: Text(
                    '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
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
        leading: _buildChatButton(), // Chat icon on top left
        actions: [
          _buildNotificationButton(), // Notification icon on top right
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
}