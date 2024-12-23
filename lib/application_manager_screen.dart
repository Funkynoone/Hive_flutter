import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'chat_screen.dart';

class ApplicationManagerScreen extends StatefulWidget {
  final String ownerId;

  const ApplicationManagerScreen({super.key, required this.ownerId});

  @override
  _ApplicationManagerScreenState createState() => _ApplicationManagerScreenState();
}

class _ApplicationManagerScreenState extends State<ApplicationManagerScreen> {
  Future<void> _deleteNotification(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification deleted')),
        );
      }
    } catch (e) {
      print("Error deleting notification: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting notification: $e')),
        );
      }
    }
  }

  Future<void> _deleteAllNotifications() async {
    try {
      final notifications = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: widget.ownerId)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in notifications.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications deleted')),
        );
      }
    } catch (e) {
      print("Error deleting all notifications: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting notifications: $e')),
        );
      }
    }
  }

  Future<void> _acceptApplication(Map<String, dynamic> data, String notificationId) async {
    try {
      // Store chatRoomId in a function-scope variable
      final String chatRoomId = '${widget.ownerId}_${data['senderId']}_${data['data']['jobId']}';
      final String jobTitle = data['data']['jobTitle'] ?? 'Job Chat';

      // Create chat room
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatRoomId)
          .set({
        'participants': [widget.ownerId, data['senderId']],
        'jobId': data['data']['jobId'],
        'jobTitle': jobTitle,
        'businessName': data['data']['businessName'],
        'lastMessage': data['message'],
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSenderId': data['senderId'],
        'unreadCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });

      // Add the initial message
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatRoomId)
          .collection('messages')
          .add({
        'text': data['message'],
        'senderId': data['senderId'],
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': true,
        'senderName': data['data']['applicantName']
      });

      // Update notification for owner
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({
        'status': 'accepted',
        'read': true,
        'chatRoomId': chatRoomId
      });

      // Create notification for user
      await FirebaseFirestore.instance
          .collection('notifications')
          .add({
        'userId': data['senderId'],
        'senderId': widget.ownerId,
        'title': 'Application Update',
        'message': data['message'],
        'type': 'application_status',
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'accepted',
        'data': {
          'jobId': data['data']['jobId'],
          'jobTitle': jobTitle,
          'businessName': data['data']['businessName'],
          'chatRoomId': chatRoomId
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Application accepted')),
        );

        // Navigate to chat using stored variables
        _openChat(chatRoomId, jobTitle);
      }
    } catch (e) {
      print("Error accepting application: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error accepting application: $e')),
        );
      }
    }
  }

// Add this method in the class
  void _openChat(String chatRoomId, String jobTitle) {
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

  Future<void> _rejectApplication(String notificationId, Map<String, dynamic> data) async {
    try {
      // Update original notification
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({
        'status': 'rejected',
        'read': true,
      });

      // Create notification for user about rejection
      await FirebaseFirestore.instance
          .collection('notifications')
          .add({
        'userId': data['senderId'],  // Send to the applicant
        'senderId': widget.ownerId,  // From the owner
        'title': 'Application Update',
        'message': data['message'],  // Original message
        'type': 'application_status',
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'rejected',
        'data': {
          'jobId': data['data']['jobId'],
          'jobTitle': data['data']['jobTitle'],
          'businessName': data['data']['businessName'],
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Application rejected')),
        );
      }
    } catch (e) {
      print("Error rejecting application: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rejecting application: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Applications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _deleteAllNotifications,
            tooltip: 'Delete All',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: widget.ownerId)
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
            return const Center(child: Text('No applications yet'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final notification = snapshot.data!.docs[index];
              final data = notification.data() as Map<String, dynamic>;

              if (data['message'] == null || data['message'].toString().isEmpty) {
                return const SizedBox.shrink();
              }

              final type = data['type'] as String;
              final isRead = data['read'] as bool;
              final status = data['status'] as String? ?? 'pending';

              return Dismissible(
                key: Key(notification.id),
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (direction) {
                  _deleteNotification(notification.id);
                },
                child: Card(
                  color: isRead ? null : Colors.blue.shade50,
                  child: ListTile(
                    title: Text(data['data']['jobTitle'] ?? 'Job Application'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${data['data']['applicantName']} sent a message about ${data['data']['businessName'] ?? 'your job posting'}:',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(data['message']),
                          ),
                        ),
                        if (status != 'pending')
                          Text(
                            'Status: ${status.toUpperCase()}',
                            style: TextStyle(
                              color: status == 'accepted' ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (status == 'pending') ...[
                          if (type == 'cv')
                            IconButton(
                              icon: const Icon(Icons.description),
                              onPressed: () async {
                                final cvUrl = data['data']['cvUrl'];
                                if (cvUrl != null) {
                                  await launchUrl(Uri.parse(cvUrl));
                                }
                              },
                              tooltip: 'View CV',
                            ),
                          IconButton(
                            icon: const Icon(Icons.check_circle_outline),
                            color: Colors.green,
                            onPressed: () => _acceptApplication(data, notification.id),
                            tooltip: 'Accept',
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel_outlined),
                            color: Colors.red,
                            onPressed: () => _rejectApplication(notification.id, data),
                            tooltip: 'Reject',
                          ),
                        ],
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteNotification(notification.id),
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}