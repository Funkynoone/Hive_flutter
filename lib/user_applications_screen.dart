import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/chat_screen.dart';

class UserApplicationsScreen extends StatefulWidget {
  const UserApplicationsScreen({super.key});

  @override
  _UserApplicationsScreenState createState() => _UserApplicationsScreenState();
}

class _UserApplicationsScreenState extends State<UserApplicationsScreen> with SingleTickerProviderStateMixin {
  final currentUser = FirebaseAuth.instance.currentUser;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Mark all notifications as read when opening the screen
    _markNotificationsAsRead();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _markNotificationsAsRead() async {
    try {
      if (currentUser != null) {
        final notifications = await FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: currentUser!.uid)
            .where('isRead', isEqualTo: false)
            .get();

        if (notifications.docs.isNotEmpty) {
          final batch = FirebaseFirestore.instance.batch();
          for (var doc in notifications.docs) {
            batch.update(doc.reference, {'isRead': true});
          }
          await batch.commit();
        }
      }
    } catch (e) {
      print("Error marking notifications as read: $e");
    }
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

  Widget _buildStatusNotificationCard(DocumentSnapshot notification) {
    final data = notification.data() as Map<String, dynamic>;
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
    final status = data['data']?['status'] as String?;
    final isRead = data['isRead'] as bool? ?? false;

    Color cardColor = Colors.white;
    Color borderColor = Colors.grey.shade300;
    IconData iconData = Icons.info;
    Color iconColor = Colors.blue;

    if (status == 'accepted') {
      cardColor = Colors.green.shade50;
      borderColor = Colors.green.shade200;
      iconData = Icons.check_circle;
      iconColor = Colors.green;
    } else if (status == 'declined') {
      cardColor = Colors.red.shade50;
      borderColor = Colors.red.shade200;
      iconData = Icons.cancel;
      iconColor = Colors.red;
    }

    if (!isRead) {
      cardColor = cardColor == Colors.white ? Colors.blue.shade50 : cardColor;
      borderColor = borderColor == Colors.grey.shade300 ? Colors.blue.shade200 : borderColor;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: cardColor,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.1),
          child: Icon(iconData, color: iconColor),
        ),
        title: Text(
          data['title'] ?? 'Application Update',
          style: TextStyle(
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data['message'] ?? 'No message content',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              _getTimeAgo(timestamp),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        trailing: status == 'accepted'
            ? const Icon(Icons.arrow_forward_ios, size: 16)
            : null,
        onTap: status == 'accepted'
            ? () {
          // Navigate to chat if accepted
          final chatRoomId = data['data']?['chatRoomId'] as String?;
          final jobTitle = data['data']?['jobTitle'] as String?;
          if (chatRoomId != null && jobTitle != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(
                  chatRoomId: chatRoomId,
                  jobTitle: jobTitle,
                ),
              ),
            );
          }
        }
            : null,
      ),
    );
  }

  Widget _buildApplicationCard(DocumentSnapshot application, Map<String, dynamic> jobData) {
    final data = application.data() as Map<String, dynamic>;
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
    final type = data['type'] as String? ?? 'message';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: type == 'cv' ? Colors.green : Colors.blue,
          child: Icon(
            type == 'cv' ? Icons.description : Icons.message,
            color: Colors.white,
          ),
        ),
        title: Text(
          jobData['title'] ?? 'Unknown Job',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Business: ${jobData['restaurant'] ?? 'Unknown'}'),
            const SizedBox(height: 4),
            if (type == 'message' && data['message'] != null)
              Text(
                'Message: ${data['message']}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[600]),
              ),
            if (type == 'cv')
              Text(
                'CV submitted',
                style: TextStyle(color: Colors.grey[600]),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _getTimeAgo(timestamp),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: const Text(
                'Pending',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusNotificationsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: currentUser!.uid)
          .where('type', isEqualTo: 'application_status')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No status updates yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'You\'ll see updates when employers respond to your applications',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            return _buildStatusNotificationCard(snapshot.data!.docs[index]);
          },
        );
      },
    );
  }

  // Alternative approach for _buildMyApplicationsTab in user_applications_screen.dart
// Replace the existing _buildMyApplicationsTab method with this:

  Widget _buildMyApplicationsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('user_messages')
          .where('userId', isEqualTo: currentUser?.uid)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, userMessageSnapshot) {
        if (userMessageSnapshot.hasError) {
          return Center(child: Text('Error: ${userMessageSnapshot.error}'));
        }

        if (userMessageSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!userMessageSnapshot.hasData || userMessageSnapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.work_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No applications yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Start applying for jobs to see them here',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: userMessageSnapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final userMessage = userMessageSnapshot.data!.docs[index];
            final data = userMessage.data() as Map<String, dynamic>;
            final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: data['data']?['applicationType'] == 'cv' ? Colors.green : Colors.blue,
                  child: Icon(
                    data['data']?['applicationType'] == 'cv' ? Icons.description : Icons.message,
                    color: Colors.white,
                  ),
                ),
                title: Text(
                  data['data']?['jobTitle'] ?? 'Unknown Job',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Business: ${data['data']?['businessName'] ?? 'Unknown'}'),
                    const SizedBox(height: 4),
                    Text(
                      data['message'] ?? 'Application submitted',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _getTimeAgo(timestamp),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getStatusColor(data['status']).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _getStatusColor(data['status']).withOpacity(0.3)),
                      ),
                      child: Text(
                        _getStatusText(data['status']),
                        style: TextStyle(
                          fontSize: 12,
                          color: _getStatusColor(data['status']),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
      case 'declined':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'accepted':
        return 'Accepted';
      case 'rejected':
      case 'declined':
        return 'Declined';
      case 'pending':
      default:
        return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Applications'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Status Updates'),
            Tab(text: 'My Applications'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStatusNotificationsTab(),
          _buildMyApplicationsTab(),
        ],
      ),
    );
  }
}