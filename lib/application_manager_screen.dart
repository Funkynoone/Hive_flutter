import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'chat_screen.dart';

class ApplicationManagerScreen extends StatefulWidget {
  final String ownerId;

  const ApplicationManagerScreen({super.key, required this.ownerId});

  @override
  _ApplicationManagerScreenState createState() => _ApplicationManagerScreenState();
}

class _ApplicationManagerScreenState extends State<ApplicationManagerScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Applications'),
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
              final type = data['type'] as String;
              final isRead = data['read'] as bool;
              final status = data['status'] as String? ?? 'pending';

              return Card(
                color: isRead ? null : Colors.blue.shade50,
                child: ListTile(
                  title: Text(data['data']['jobTitle'] ?? 'Job Application'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['message']),
                      Text(
                        'From: ${data['data']['applicantName']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
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
                  trailing: status == 'pending'
                      ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                        onPressed: () async {
                          try {
                            final chatRoomId = '${widget.ownerId}_${data['senderId']}_${data['data']['jobId']}';

                            // Create chat room
                            await FirebaseFirestore.instance
                                .collection('chats')
                                .doc(chatRoomId)
                                .set({
                              'participants': [widget.ownerId, data['senderId']],
                              'jobId': data['data']['jobId'],
                              'jobTitle': data['data']['jobTitle'],
                              'lastMessage': data['message'],
                              'lastMessageTime': FieldValue.serverTimestamp(),
                              'lastSenderId': data['senderId'],
                              'unreadCount': 0
                            });

                            // Add the original message
                            await FirebaseFirestore.instance
                                .collection('chats')
                                .doc(chatRoomId)
                                .collection('messages')
                                .add({
                              'text': data['message'],
                              'senderId': data['senderId'],
                              'timestamp': FieldValue.serverTimestamp(),
                              'isRead': false,
                              'senderName': data['data']['applicantName']
                            });

                            // Update notification status
                            await FirebaseFirestore.instance
                                .collection('notifications')
                                .doc(notification.id)
                                .update({
                              'status': 'accepted',
                              'read': true,
                            });

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Application accepted')),
                              );
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatScreen(
                                    chatRoomId: chatRoomId,
                                    jobTitle: data['data']['jobTitle'],
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            print("Error accepting application: $e");
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error accepting application: $e')),
                              );
                            }
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel_outlined),
                        color: Colors.red,
                        onPressed: () async {
                          try {
                            // Just update status to rejected
                            await FirebaseFirestore.instance
                                .collection('notifications')
                                .doc(notification.id)
                                .update({
                              'status': 'rejected',
                              'read': true,
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
                        },
                      ),
                    ],
                  )
                      : status == 'accepted'
                      ? IconButton(
                    icon: const Icon(Icons.chat),
                    onPressed: () {
                      final chatRoomId = '${widget.ownerId}_${data['senderId']}_${data['data']['jobId']}';
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            chatRoomId: chatRoomId,
                            jobTitle: data['data']['jobTitle'],
                          ),
                        ),
                      );
                    },
                  )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}