import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserApplicationsScreen extends StatefulWidget {
  const UserApplicationsScreen({super.key});

  @override
  _UserApplicationsScreenState createState() => _UserApplicationsScreenState();
}

class _UserApplicationsScreenState extends State<UserApplicationsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _markNotificationsAsRead();
  }

  Future<void> _markNotificationsAsRead() async {
    final user = currentUser;
    if (user == null) return;

    print('[UserApplicationsScreen] Marking application_status notifications as read for user ${user.uid}');

    try {
      final querySnapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .where('type', isEqualTo: 'application_status')
          .where('status', whereIn: [null, 'pending'])
          .get();

      if (querySnapshot.docs.isEmpty) {
        print('[UserApplicationsScreen] No pending application_status notifications to mark as read.');
        return;
      }

      WriteBatch batch = _firestore.batch();
      for (var doc in querySnapshot.docs) {
        batch.update(doc.reference, {'status': 'read'});
      }
      await batch.commit();
      print('[UserApplicationsScreen] Successfully marked ${querySnapshot.docs.length} application_status notifications as read.');
    } catch (e) {
      print('[UserApplicationsScreen] Error marking notifications as read: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating notification statuses: $e')),
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
        title: const Text('My Applications'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('notifications')
            .where('userId', isEqualTo: currentUser?.uid)
            .where('type', isEqualTo: 'application_status') // We are interested in status updates
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            print("[UserApplicationsScreen] Error fetching notifications: ${snapshot.error}");
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No application status updates yet.'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final notificationDoc = snapshot.data!.docs[index];
              final data = notificationDoc.data() as Map<String, dynamic>; // This is the notification data
              final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
              final String message = data['message'] as String? ?? 'No details provided.';
              final String jobTitle = data['jobTitle'] as String? ?? 'Application Update';
              final String businessName = data['businessName'] as String? ?? 'A Business';
              final String notificationStatus = data['status'] as String? ?? 'pending'; // e.g. 'pending', 'accepted', 'declined', 'read'
              final String originalApplicationType = data['originalApplicationType'] as String? ?? 'application'; // 'cv' or 'message'

              IconData iconData = Icons.info_outline;
              Color iconColor = Colors.blue;
              String statusText = notificationStatus.toUpperCase();
              Color statusColor = Colors.orange;

              if (notificationStatus == 'accepted') {
                iconData = Icons.check_circle_outline;
                iconColor = Colors.green;
                statusText = 'ACCEPTED';
                statusColor = Colors.green;
              } else if (notificationStatus == 'declined' || notificationStatus == 'rejected') {
                iconData = Icons.cancel_outlined;
                iconColor = Colors.red;
                statusText = 'DECLINED';
                statusColor = Colors.red;
              } else if (notificationStatus == 'read') {
                 // Could be an accepted/declined notification that was already read
                 // For now, treat 'read' like 'pending' for display if no specific accepted/declined status is on the notification itself
                 // This part might need refinement based on how 'accepted'/'declined' statuses are set on these 'application_status' notifications.
                 // If 'application_status' notifications *also* get an 'accepted' or 'declined' status field directly, use that.
                 // For now, assuming 'read' means it was a pending item that's now viewed.
                iconData = Icons.history;
                iconColor = Colors.grey;
                statusText = 'VIEWED'; // Or derive from another field if available
                statusColor = Colors.grey;
              } else { // pending or null
                iconData = Icons.hourglass_empty;
                iconColor = Colors.orange;
                statusText = 'PENDING';
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: iconColor,
                    child: Icon(iconData, color: Colors.white),
                  ),
                  title: Text(
                    jobTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('From: $businessName'),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (timestamp != null) Text(_getTimeAgo(timestamp), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: statusColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 12,
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    // Optional: Navigate to chat if accepted, or show more details
                    // For now, tapping does nothing on this screen for these notifications.
                    print('Tapped on application status notification: ${notificationDoc.id}');
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}