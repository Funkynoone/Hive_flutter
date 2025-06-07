import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/chat_screen.dart';

class UserChatListScreen extends StatefulWidget {
  const UserChatListScreen({super.key});

  @override
  _UserChatListScreenState createState() => _UserChatListScreenState();
}

class _UserChatListScreenState extends State<UserChatListScreen> with SingleTickerProviderStateMixin {
  final currentUser = FirebaseAuth.instance.currentUser;
  late TabController _tabController;

  // Use ValueNotifier for reactive counter updates
  final ValueNotifier<int> _pendingCount = ValueNotifier<int>(0);
  final ValueNotifier<int> _acceptedCount = ValueNotifier<int>(0);
  final ValueNotifier<int> _declinedCount = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    print("[UserChatListScreen] initState: currentUser UID: ${currentUser?.uid}");

    // Initialize counters by triggering the streams
    _initializeCounters();
  }

  void _initializeCounters() {
    // Get initial counts for all tabs
    if (currentUser != null) {
      // Pending count - notifications that haven't been processed
      FirebaseFirestore.instance
          .collection('notifications')
          .where('senderId', isEqualTo: currentUser!.uid)
          .where('type', isEqualTo: 'message')
          .get()
          .then((snapshot) {
        final pendingCount = snapshot.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'] as String?;
          // Count only unprocessed notifications
          return status == null || (!['accepted', 'rejected', 'declined'].contains(status));
        }).length;
        _pendingCount.value = pendingCount;
      });

      // Accepted count
      FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUser!.uid)
          .get()
          .then((snapshot) {
        _acceptedCount.value = snapshot.docs.length;
      });

      // Declined count
      FirebaseFirestore.instance
          .collection('userApplicationFeedback')
          .where('userId', isEqualTo: currentUser!.uid)
          .where('status', isEqualTo: 'declined')
          .get()
          .then((snapshot) {
        _declinedCount.value = snapshot.docs.length;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pendingCount.dispose();
    _acceptedCount.dispose();
    _declinedCount.dispose();
    super.dispose();
  }

  String _getTimeAgo(DateTime? dateTime) {
    if (dateTime == null) return '';
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 7) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildMessageCard(DocumentSnapshot doc, {bool isNaturePending = false, bool isFeedback = false}) {
    final data = doc.data() as Map<String, dynamic>;
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

    final status = data['status'] as String?;
    final bool isRejected = status == 'rejected' || status == 'declined';
    final bool isActuallyPending = isNaturePending || status == 'pending';

    Color cardColor = Colors.grey[200]!;
    Color textColor = Colors.black87;
    Color subTextColor = Colors.grey[700]!;
    Color avatarBackgroundColor = Colors.grey[500]!;
    String statusText = '';
    Color statusTagColor = Colors.grey;

    if (isRejected) {
      cardColor = Colors.red[50]!;
      textColor = Colors.black87;
      subTextColor = Colors.grey[600]!;
      avatarBackgroundColor = Colors.red[300]!;
      statusText = 'DECLINED';
      statusTagColor = Colors.redAccent;
    } else if (isActuallyPending) {
      cardColor = Colors.orange[50]!;
      avatarBackgroundColor = Colors.orange[600]!;
      statusText = 'PENDING';
      statusTagColor = Colors.orangeAccent;
      subTextColor = Colors.grey[600]!;
    }

    Map<String, dynamic> innerData;
    String messageText = data['message'] as String? ?? '';

    if (isFeedback) {
      innerData = data;
      messageText = 'Your application was declined.';
    } else {
      innerData = data['data'] as Map<String, dynamic>? ?? {};
    }

    return Card(
      elevation: 2,
      color: cardColor,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundColor: avatarBackgroundColor,
          child: Text(
            (innerData['businessName'] ?? 'B')[0].toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    innerData['jobTitle'] ?? 'Job Application',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
                if (isRejected || isActuallyPending)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusTagColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            Text(
              innerData['businessName'] ?? 'Unknown Business',
              style: TextStyle(
                fontSize: 12,
                color: subTextColor,
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              messageText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: subTextColor),
            ),
            const SizedBox(height: 4),
            Text(
              _getTimeAgo(timestamp),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        onTap: null,
      ),
    );
  }

  Widget _buildAcceptedChatCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final lastMessageTimestamp = (data['lastMessageTime'] as Timestamp?)?.toDate();
    final businessName = data['businessName'] as String? ?? 'Unknown Business';
    final jobTitle = data['jobTitle'] as String? ?? 'Job Chat';
    final avatarChar = businessName.isNotEmpty ? businessName[0].toUpperCase() : 'B';
    final applicantUnreadCount = data['applicantUnreadCount'] as int? ?? 0;
    final lastSenderId = data['lastSenderId'] as String?;
    final hasUnreadMessages = lastSenderId != currentUser?.uid && applicantUnreadCount > 0;

    return Card(
      elevation: 2,
      color: hasUnreadMessages ? Colors.lightBlue[100] : Colors.lightBlue[50],
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: Colors.lightBlue,
              child: Text(avatarChar, style: const TextStyle(color: Colors.white)),
            ),
            if (hasUnreadMessages)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    applicantUnreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(jobTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(businessName, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              data['lastMessage'] ?? 'No messages yet',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: hasUnreadMessages ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 4),
            Text(_getTimeAgo(lastMessageTimestamp), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                chatRoomId: doc.id,
                jobTitle: data['jobTitle'] ?? 'Job Chat',
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPendingTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('senderId', isEqualTo: currentUser!.uid)
          .where('type', isEqualTo: 'message')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          if (snapshot.error.toString().toLowerCase().contains('index')) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange),
                    const SizedBox(height: 16),
                    const Text('Database Index Required'),
                    const SizedBox(height: 8),
                    Text(
                      'Please create an index for:\nnotifications -> senderId + type + timestamp (descending)',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            );
          }
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Filter for unprocessed notifications only
        final pendingNotifications = snapshot.hasData ? snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'] as String?;
          // Show only notifications that haven't been processed
          return status == null || (!['accepted', 'rejected', 'declined'].contains(status));
        }).toList() : [];

        // Update count
        final newCount = pendingNotifications.length;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _pendingCount.value = newCount;
        });

        if (pendingNotifications.isEmpty) {
          return const Center(child: Text('No pending applications'));
        }

        return ListView.builder(
          itemCount: pendingNotifications.length,
          itemBuilder: (context, index) => _buildMessageCard(
              pendingNotifications[index],
              isNaturePending: true
          ),
        );
      },
    );
  }

  Widget _buildAcceptedTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUser!.uid)
          .orderBy('lastMessageTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Update count
        if (snapshot.hasData) {
          final newCount = snapshot.data!.docs.length;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _acceptedCount.value = newCount;
          });
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No accepted applications'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) => _buildAcceptedChatCard(snapshot.data!.docs[index]),
        );
      },
    );
  }

  Widget _buildDeclinedTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('userApplicationFeedback')
          .where('userId', isEqualTo: currentUser!.uid)
          .where('status', isEqualTo: 'declined')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          if (snapshot.error.toString().toLowerCase().contains('index')) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange),
                    const SizedBox(height: 16),
                    const Text('Database Index Required'),
                    const SizedBox(height: 8),
                    Text(
                      'Please create an index for:\nuserApplicationFeedback -> userId + status + timestamp (descending)',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            );
          }
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Update count
        if (snapshot.hasData) {
          final newCount = snapshot.data!.docs.length;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _declinedCount.value = newCount;
          });
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No declined applications'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) => _buildMessageCard(
              snapshot.data!.docs[index],
              isFeedback: true
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Messages')),
        body: const Center(child: Text('Please log in to see messages.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Messages'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: ValueListenableBuilder<int>(
            valueListenable: _pendingCount,
            builder: (context, pendingValue, _) {
              return ValueListenableBuilder<int>(
                valueListenable: _acceptedCount,
                builder: (context, acceptedValue, _) {
                  return ValueListenableBuilder<int>(
                    valueListenable: _declinedCount,
                    builder: (context, declinedValue, _) {
                      return TabBar(
                        controller: _tabController,
                        indicatorColor: Colors.white,
                        indicatorWeight: 3,
                        tabs: [
                          Tab(text: 'Pending ($pendingValue)'),
                          Tab(text: 'Accepted ($acceptedValue)'),
                          Tab(text: 'Declined ($declinedValue)'),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingTab(),
          _buildAcceptedTab(),
          _buildDeclinedTab(),
        ],
      ),
    );
  }
}