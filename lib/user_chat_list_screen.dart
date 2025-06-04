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

  // Modified to accept isNaturePending and to handle different data structures
  Widget _buildMessageCard(DocumentSnapshot doc, {bool isNaturePending = false, bool isFeedback = false}) {
    final data = doc.data() as Map<String, dynamic>;
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

    // 'status' field is expected from userApplicationFeedback or original user_messages
    // For notifications (isNaturePending), status is inferred as 'pending'.
    final status = data['status'] as String?;

    final bool isRejected = status == 'rejected' || status == 'declined'; // Treat 'declined' same as 'rejected' for UI
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
      statusText = 'DECLINED'; // Show "DECLINED" for both 'rejected' and 'declined' status
      statusTagColor = Colors.redAccent;
    } else if (isActuallyPending) {
      cardColor = Colors.orange[50]!;
      avatarBackgroundColor = Colors.orange[600]!;
      statusText = 'PENDING';
      statusTagColor = Colors.orangeAccent;
      subTextColor = Colors.grey[600]!;
    }

    // Adjust how innerData is extracted based on the source
    Map<String, dynamic> innerData;
    String messageText = data['message'] as String? ?? ''; // Default message source

    if (isFeedback) { // Data from userApplicationFeedback
      innerData = data; // jobTitle, businessName are top-level
      // userApplicationFeedback might not have a 'message' field, adjust as needed or show a generic text
      messageText = 'Your application was declined.'; // Or pull from a specific field if you add one
    } else { // Data from notifications or original user_messages structure
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
          // Pending Messages - Fetches from 'notifications'
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('senderId', isEqualTo: currentUser!.uid)
                .where('type', isEqualTo: 'message')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              final logPrefix = "[PENDING-NOTIFICATIONS ${DateTime.now().toIso8601String()}] (${currentUser!.uid}) -";

              // ... (existing error handling and loading state) ...
              if (snapshot.hasError) {
                print("$logPrefix ERROR: ${snapshot.error}");
                if (snapshot.error.toString().toLowerCase().contains('index')) {
                  return Center( /* ... Index error UI ... */ );
                }
                return Center( /* ... Generic error UI ... */ );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              // ... (existing count update and empty state logic) ...

              int newCount = 0;
              if (snapshot.hasData) {
                newCount = snapshot.data!.docs.length;
                // ... (logging) ...
              }
              if (_pendingCount != newCount) { /* ... update count ... */ }
              if (newCount == 0) {
                return const Center(child: Text('No pending applications'));
              }

              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) => _buildMessageCard(snapshot.data!.docs[index], isNaturePending: true),
              );
            },
          ),

          // Accepted Messages - Fetches from 'chats'
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('chats')
                .where('participants', arrayContains: currentUser!.uid)
                .orderBy('lastMessageTime', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              // ... (existing logic for accepted tab is fine) ...
              final logPrefix = "[ACCEPTED ${DateTime.now().toIso8601String()}] (${currentUser!.uid}) -";
              if (snapshot.hasError) { /* ... error handling ... */ return Center(child: Text('Error loading accepted: ${snapshot.error}. Check logs.'));}
              if (snapshot.connectionState == ConnectionState.waiting) { return const Center(child: CircularProgressIndicator()); }
              int newCount = 0;
              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) { newCount = snapshot.data!.docs.length; }
              if (_acceptedCount != newCount) { /* ... update count ... */ }
              if (newCount == 0) { return const Center(child: Text('No accepted applications')); }
              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) => _buildAcceptedChatCard(snapshot.data!.docs[index]),
              );
            },
          ),

          // Declined Messages - NOW fetches from 'userApplicationFeedback'
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('userApplicationFeedback') // <--- CHANGE: Querying new collection
                .where('userId', isEqualTo: currentUser!.uid) // Feedback for the current user
                .where('status', isEqualTo: 'declined') // Where status is 'declined'
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              final logPrefix = "[DECLINED-FEEDBACK ${DateTime.now().toIso8601String()}] (${currentUser!.uid}) -";

              print("$logPrefix Stream state: ${snapshot.connectionState}");
              print("$logPrefix Has data: ${snapshot.hasData}");
              print("$logPrefix Has error: ${snapshot.hasError}");

              if (snapshot.hasError) {
                print("$logPrefix ERROR: ${snapshot.error}");
                print("$logPrefix Stack: ${snapshot.stackTrace}");
                if (snapshot.error.toString().toLowerCase().contains('index')) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange),
                          const SizedBox(height: 16),
                          const Text('Database Index Required', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(
                            'A Firestore index is required. Please create the following index in your Firebase console for the "userApplicationFeedback" collection:',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Fields: userId (Ascending), status (Ascending), timestamp (Descending)', // Adjusted for the new query
                            textAlign: TextAlign.center,
                            style: TextStyle(fontFamily: 'monospace', color: Colors.grey[700]),
                          ),
                          const SizedBox(height: 8),
                          Text('Error details: ${snapshot.error}', style: TextStyle(fontSize: 12, color: Colors.red[300])),
                        ],
                      ),
                    ),
                  );
                }
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: ${snapshot.error}'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {});
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                print("$logPrefix Waiting for data...");
                return const Center(child: CircularProgressIndicator());
              }

              int newCount = 0;
              if (snapshot.hasData) {
                newCount = snapshot.data!.docs.length;
                print("$logPrefix Data received: $newCount documents from 'userApplicationFeedback'");

                for (var doc in snapshot.data!.docs) {
                  final docData = doc.data() as Map<String, dynamic>;
                  print("$logPrefix Doc ${doc.id}: (Declined Feedback) status=${docData['status']}, job=${docData['jobTitle']}");
                }
              }

              if (_declinedCount != newCount) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _declinedCount = newCount);
                });
              }

              if (newCount == 0) {
                print("$logPrefix No declined applications (from feedback)");
                return const Center(child: Text('No declined applications'));
              }

              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                // Pass isFeedback: true to use the correct data structure for title/businessName
                itemBuilder: (context, index) => _buildMessageCard(snapshot.data!.docs[index], isFeedback: true),
              );
            },
          ),
        ],
      ),
    );
  }
}