import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class ApplicationManagerScreen extends StatefulWidget {
  final String ownerId;

  const ApplicationManagerScreen({super.key, required this.ownerId});

  @override
  _ApplicationManagerScreenState createState() => _ApplicationManagerScreenState();
}

class _ApplicationManagerScreenState extends State<ApplicationManagerScreen> {
  @override
  void initState() {
    super.initState();
    // Mark all notifications as read when opening the screen
    _markNotificationsAsRead();
  }

  Future<void> _markNotificationsAsRead() async {
    try {
      // Get all unread notifications for this user
      final notifications = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: widget.ownerId)
          .where('isRead', isEqualTo: false)
          .get();

      if (notifications.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (var doc in notifications.docs) {
          batch.update(doc.reference, {'isRead': true});
        }
        await batch.commit();

        print("Marked ${notifications.docs.length} notifications as read");
      }
    } catch (e) {
      print("Error marking notifications as read: $e");
    }
  }

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
        final type = (doc.data())['type'] as String?;
        if (type == 'cv' || type == 'message') {
          batch.delete(doc.reference);
        }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
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
            return const Center(child: Text('No notifications'));
          }

          // Filter and sort notifications manually
          final notifications = snapshot.data!.docs
              .where((doc) {
            final type = (doc.data() as Map<String, dynamic>)['type'] as String?;
            return type == 'cv' || type == 'message' || type == 'cv_application';
          })
              .toList();

          if (notifications.isEmpty) {
            return const Center(child: Text('No notifications'));
          }

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              final data = notification.data() as Map<String, dynamic>;
              final type = data['type'] as String;
              final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
              final isRead = data['isRead'] as bool? ?? false;
              final status = data['status'] as String?;

              // Determine notification appearance based on status
              Color cardColor = Colors.white;
              Color borderColor = Colors.grey.shade300;

              if (!isRead) {
                cardColor = Colors.blue.shade50;
                borderColor = Colors.blue.shade200;
              }

              if (status == 'accepted') {
                cardColor = Colors.green.shade50;
                borderColor = Colors.green.shade200;
              } else if (status == 'rejected' || status == 'declined') {
                cardColor = Colors.red.shade50;
                borderColor = Colors.red.shade200;
              }

              if (type == 'message') {
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  color: cardColor,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: borderColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: status == 'accepted'
                              ? Colors.green
                              : status == 'rejected'
                              ? Colors.red
                              : Colors.blue,
                          child: Icon(
                              status == 'accepted'
                                  ? Icons.check
                                  : status == 'rejected'
                                  ? Icons.close
                                  : Icons.message,
                              color: Colors.white
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Message from ${data['data']?['applicantName'] ?? 'someone'}',
                                      style: TextStyle(
                                        fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (status != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: status == 'accepted'
                                            ? Colors.green
                                            : status == 'rejected'
                                            ? Colors.red
                                            : Colors.orange,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        status.toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Regarding: ${data['data']?['jobTitle'] ?? 'your job posting'}',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  data['message'] ?? 'No message content',
                                  style: const TextStyle(fontSize: 14),
                                ),
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
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteNotification(notification.id),
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                  ),
                );
              } else if (type == 'cv' || type == 'cv_application') {
                // CV notification
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  color: cardColor,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: borderColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: !isRead ? Colors.green : Colors.green.shade300,
                      child: const Icon(Icons.description, color: Colors.white),
                    ),
                    title: Text(
                      'CV received from ${data['data']?['applicantName'] ?? 'someone'}',
                      style: TextStyle(
                        fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'For: ${data['data']?['jobTitle'] ?? 'your job posting'}',
                          style: TextStyle(color: Colors.grey[600]),
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
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (data['data']?['cvUrl'] != null)
                          IconButton(
                            icon: const Icon(Icons.download),
                            onPressed: () async {
                              final cvUrl = data['data']['cvUrl'];
                              if (cvUrl != null) {
                                try {
                                  await launchUrl(Uri.parse(cvUrl));
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Could not open CV: $e')),
                                    );
                                  }
                                }
                              }
                            },
                            tooltip: 'Download CV',
                          ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteNotification(notification.id),
                          tooltip: 'Delete',
                        ),
                      ],
                    ),
                  ),
                );
              }

              return const SizedBox.shrink();
            },
          );
        },
      ),
    );
  }
}