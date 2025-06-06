import 'package:flutter/material.dart';
import 'package:hive_flutter/profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/jobs_main_screen.dart'; // Changed from jobs_screen.dart
import 'package:hive_flutter/add_job_screen.dart';
import 'package:hive_flutter/saved_jobs_screen.dart';
import 'package:hive_flutter/application_manager_screen.dart';
import 'package:hive_flutter/user_applications_screen.dart';
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
      const JobsMainScreen(), // Changed from JobsScreen()
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
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return IconButton(
      icon: const Icon(Icons.chat_bubble_outline),
      onPressed: () {},
    );

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUser.uid)
          .snapshots(),
      builder: (context, chatSnapshot) {
        int unreadChats = 0;

        // Count unread chats
        if (chatSnapshot.hasData) {
          for (var doc in chatSnapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final unreadCount = data['unreadCount'] as int? ?? 0;
            final lastSenderId = data['lastSenderId'] as String?;
            final messages = data['messages'] as List<dynamic>? ?? [];

            // Count only unread messages from other users
            if (lastSenderId != currentUser.uid && unreadCount > 0) {
              for (var message in messages) {
                if (message is Map<String, dynamic> && 
                    message['senderId'] != currentUser.uid && 
                    !message['isRead']) {
                  unreadChats++;
                }
              }
            }
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('notifications')
              .where('userId', isEqualTo: currentUser.uid)
              .where('status', isEqualTo: 'unread')
              .where('type', isEqualTo: 'message')
              .snapshots(),
          builder: (context, notificationSnapshot) {
            int unreadMessages = notificationSnapshot.hasData 
                ? notificationSnapshot.data!.docs.length 
                : 0;

            final totalUnread = unreadChats + unreadMessages;

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
                if (totalUnread > 0)
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
                        '$totalUnread',
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
      },
    );
  }

  Widget _buildNotificationButton() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return IconButton(
      icon: const Icon(Icons.notifications_none),
      onPressed: () {},
    );

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'unread')
          .snapshots(),
      builder: (context, snapshot) {
        int unreadCount = 0;
        if (snapshot.hasData) {
          unreadCount = snapshot.data!.docs.where((doc) {
            final type = (doc.data() as Map<String, dynamic>)['type'] as String?;
            final status = (doc.data() as Map<String, dynamic>)['status'] as String?;
            return (type == 'cv' || type == 'message') && status == 'unread';
          }).length;
        }

        return Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => isBusinessOwner
                        ? ApplicationManagerScreen(
                      ownerId: currentUser.uid,
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