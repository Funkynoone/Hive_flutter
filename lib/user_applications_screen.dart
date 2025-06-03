import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserApplicationsScreen extends StatefulWidget {
  const UserApplicationsScreen({super.key});

  @override
  _UserApplicationsScreenState createState() => _UserApplicationsScreenState();
}

class _UserApplicationsScreenState extends State<UserApplicationsScreen> {
  final currentUser = FirebaseAuth.instance.currentUser;

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
        stream: FirebaseFirestore.instance
            .collection('JobListings')
            .snapshots(),
        builder: (context, jobSnapshot) {
          if (jobSnapshot.hasError) {
            return Center(child: Text('Error: ${jobSnapshot.error}'));
          }

          if (jobSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Get all applications for the current user
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collectionGroup('Applications')
                .where('userId', isEqualTo: currentUser?.uid)
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, appSnapshot) {
              if (appSnapshot.hasError) {
                return Center(child: Text('Error: ${appSnapshot.error}'));
              }

              if (appSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!appSnapshot.hasData || appSnapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No applications yet'));
              }

              return ListView.builder(
                itemCount: appSnapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final application = appSnapshot.data!.docs[index];
                  final data = application.data() as Map<String, dynamic>;
                  final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
                  final type = data['type'] as String? ?? 'message';

                  // Get job details from parent
                  final pathSegments = application.reference.path.split('/');
                  final jobId = pathSegments[pathSegments.length - 3];

                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('JobListings')
                        .doc(jobId)
                        .get(),
                    builder: (context, jobSnapshot) {
                      if (!jobSnapshot.hasData) {
                        return const SizedBox.shrink();
                      }

                      final jobData = jobSnapshot.data!.data() as Map<String, dynamic>?;
                      if (jobData == null) return const SizedBox.shrink();

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
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}