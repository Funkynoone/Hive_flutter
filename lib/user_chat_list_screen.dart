import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/chat_screen.dart'; // Assuming 'hive_flutter' is your project name and chat_screen.dart is in lib

class UserChatListScreen extends StatefulWidget {
  const UserChatListScreen({super.key});

  @override
  _UserChatListScreenState createState() => _UserChatListScreenState();
}

class _UserChatListScreenState extends State<UserChatListScreen> with SingleTickerProviderStateMixin {
  final currentUser = FirebaseAuth.instance.currentUser;
  late TabController _tabController;

  int _pendingCount = 0;
  int _acceptedCount = 0;
  int _declinedCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    print("[UserChatListScreen] initState: currentUser UID: ${currentUser?.uid}");
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  Widget _buildMessageCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
    final status = data['status'] as String?;

    final bool isRejected = status == 'rejected';
    final bool isPending = status == 'pending';

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
    } else if (isPending) {
      cardColor = Colors.orange[50]!;
      avatarBackgroundColor = Colors.orange[600]!;
      statusText = 'PENDING';
      statusTagColor = Colors.orangeAccent;
      subTextColor = Colors.grey[600]!;
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
            (data['data']?['businessName'] ?? 'B')[0].toUpperCase(),
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
                    data['data']?['jobTitle'] ?? 'Job Application',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
                if (isRejected || isPending)
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
              data['data']?['businessName'] ?? 'Unknown Business',
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
              data['message'] ?? '',
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

    return Card(
      elevation: 2,
      color: Colors.lightBlue[50],
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundColor: Colors.lightBlue,
          child: Text(avatarChar, style: const TextStyle(color: Colors.white)),
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
            Text(data['lastMessage'] ?? 'No messages yet', maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(_getTimeAgo(lastMessageTimestamp), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
        trailing: data['unreadCount'] != null && data['unreadCount'] > 0 && data['lastSenderId'] != currentUser?.uid
            ? Container(
          padding: const EdgeInsets.all(6),
          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
          child: Text(
            data['unreadCount'].toString(),
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        )
            : null,
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

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      print("[UserChatListScreen] build: currentUser is null. Showing login message.");
      return Scaffold(
        appBar: AppBar(title: const Text('My Messages')),
        body: const Center(child: Text('Please log in to see messages.')),
      );
    }
    print("[UserChatListScreen] build: Building UI for user ${currentUser!.uid}");

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Messages'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: [
            Tab(text: 'Pending ($_pendingCount)'),
            Tab(text: 'Accepted ($_acceptedCount)'),
            Tab(text: 'Declined ($_declinedCount)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Pending Messages
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('user_messages')
                .where('userId', isEqualTo: currentUser!.uid)
                .where('status', isEqualTo: 'pending')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              final logPrefix = "[${DateTime.now()}] PENDING TAB (${currentUser!.uid}) -";
              print("$logPrefix ConnectionState: ${snapshot.connectionState}, HasData: ${snapshot.hasData}, HasError: ${snapshot.hasError}");

              if (snapshot.hasError) {
                print("$logPrefix Error: ${snapshot.error}");
                print("$logPrefix StackTrace: ${snapshot.stackTrace}");
                return Center(child: Text('Error loading pending: ${snapshot.error}. Check logs.'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                print("$logPrefix Still waiting for data...");
                return const Center(child: CircularProgressIndicator());
              }

              int newCount = 0;
              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                newCount = snapshot.data!.docs.length;
                print("$logPrefix Data received: $newCount items.");
              } else {
                print("$logPrefix No data or empty docs. ConnectionState: ${snapshot.connectionState}");
              }

              if (_pendingCount != newCount) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _pendingCount = newCount);
                });
              }

              if (newCount == 0) {
                return const Center(child: Text('No pending messages'));
              }

              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) => _buildMessageCard(snapshot.data!.docs[index]),
              );
            },
          ),

          // Accepted Messages
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('chats')
                .where('participants', arrayContains: currentUser!.uid)
                .orderBy('lastMessageTime', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              final logPrefix = "[${DateTime.now()}] ACCEPTED TAB (${currentUser!.uid}) -";
              print("$logPrefix ConnectionState: ${snapshot.connectionState}, HasData: ${snapshot.hasData}, HasError: ${snapshot.hasError}");

              if (snapshot.hasError) {
                print("$logPrefix Error: ${snapshot.error}");
                print("$logPrefix StackTrace: ${snapshot.stackTrace}");
                return Center(child: Text('Error loading accepted: ${snapshot.error}. Check logs.'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                print("$logPrefix Still waiting for data...");
                return const Center(child: CircularProgressIndicator());
              }

              int newCount = 0;
              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                newCount = snapshot.data!.docs.length;
                print("$logPrefix Data received: $newCount items.");
              } else {
                print("$logPrefix No data or empty docs. ConnectionState: ${snapshot.connectionState}");
              }

              if (_acceptedCount != newCount) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _acceptedCount = newCount);
                });
              }

              if (newCount == 0) {
                return const Center(child: Text('No accepted applications'));
              }

              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) => _buildAcceptedChatCard(snapshot.data!.docs[index]),
              );
            },
          ),

          // Declined Messages
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('user_messages')
                .where('userId', isEqualTo: currentUser!.uid)
                .where('status', isEqualTo: 'rejected')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              final logPrefix = "[${DateTime.now()}] DECLINED TAB (${currentUser!.uid}) -";
              print("$logPrefix ConnectionState: ${snapshot.connectionState}, HasData: ${snapshot.hasData}, HasError: ${snapshot.hasError}");

              if (snapshot.hasError) {
                print("$logPrefix Error: ${snapshot.error}");
                print("$logPrefix StackTrace: ${snapshot.stackTrace}");
                return Center(child: Text('Error loading declined: ${snapshot.error}. Check logs.'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                print("$logPrefix Still waiting for data...");
                return const Center(child: CircularProgressIndicator());
              }

              int newCount = 0;
              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                newCount = snapshot.data!.docs.length;
                print("$logPrefix Data received: $newCount items.");
              } else {
                print("$logPrefix No data or empty docs. ConnectionState: ${snapshot.connectionState}");
              }

              if (_declinedCount != newCount) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _declinedCount = newCount);
                });
              }

              if (newCount == 0) {
                return const Center(child: Text('No declined applications'));
              }

              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) => _buildMessageCard(snapshot.data!.docs[index]),
              );
            },
          ),
        ],
      ),
    );
  }
}
