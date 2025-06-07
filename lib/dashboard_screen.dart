import 'package:flutter/material.dart';
import 'package:hive_flutter/profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/jobs_main_screen.dart';
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
      const JobsMainScreen(),
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

    if (isBusinessOwner) {
      // For business owners: count unprocessed message notifications
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: currentUser.uid)
            .where('type', isEqualTo: 'message')
            .snapshots(),
        builder: (context, snapshot) {
          int unreadCount = 0;
          if (snapshot.hasData) {
            // Count notifications that haven't been processed (no status or null status)
            unreadCount = snapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final status = data['status'] as String?;
              return status == null || (!['accepted', 'declined', 'rejected'].contains(status));
            }).length;
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
    } else {
      // For regular users: count unread chats and pending applications
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participants', arrayContains: currentUser.uid)
            .snapshots(),
        builder: (context, chatSnapshot) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('senderId', isEqualTo: currentUser.uid)
                .where('type', isEqualTo: 'message')
                .snapshots(),
            builder: (context, notificationSnapshot) {
              int totalUnread = 0;

              // Count unread messages in chats
              if (chatSnapshot.hasData) {
                for (var doc in chatSnapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final lastSenderId = data['lastSenderId'] as String?;
                  final applicantUnreadCount = data['applicantUnreadCount'] as int? ?? 0;

                  // If the last message wasn't from current user and there are unread messages
                  if (lastSenderId != currentUser.uid && applicantUnreadCount > 0) {
                    totalUnread += applicantUnreadCount;
                  }
                }
              }

              // Count pending notifications (applications that haven't been processed)
              if (notificationSnapshot.hasData) {
                final pendingCount = notificationSnapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = data['status'] as String?;
                  return status == null || (!['accepted', 'declined', 'rejected'].contains(status));
                }).length;
                totalUnread += pendingCount;
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
          .snapshots(),
      builder: (context, snapshot) {
        int unreadCount = 0;
        if (snapshot.hasData) {
          if (isBusinessOwner) {
            // For business owners: count CV applications and unread notifications
            unreadCount = snapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final type = data['type'] as String?;
              final isRead = data['isRead'] as bool? ?? false;

              // Count CV applications or unread notifications
              return (type == 'cv' && !isRead) ||
                  (type == 'message' && !isRead);
            }).length;
          } else {
            // For regular users: count application status updates
            unreadCount = snapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final isRead = data['isRead'] as bool? ?? false;
              return !isRead;
            }).length;
          }
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
        leading: _buildChatButton(),
        actions: [
          _buildNotificationButton(),
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