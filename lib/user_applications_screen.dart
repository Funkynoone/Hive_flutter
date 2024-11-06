import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class UserApplicationsScreen extends StatelessWidget {
  const UserApplicationsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Applications'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: currentUser?.uid)
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
              final status = data['status'] as String? ?? 'pending';

              return Card(
                child: ListTile(
                  title: Text(data['title'] ?? 'Job Application'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['message'] ?? ''),
                      const SizedBox(height: 4),
                      Text(
                        'Status: ${status.toUpperCase()}',
                        style: TextStyle(
                          color: status == 'accepted'
                              ? Colors.green
                              : status == 'rejected'
                              ? Colors.red
                              : Colors.orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  trailing: status == 'accepted'
                      ? IconButton(
                    icon: const Icon(Icons.chat),
                    onPressed: () {
                      // Make sure this matches exactly how it's created in ApplicationManagerScreen
                      final chatRoomId = '${data['userId']}_${currentUser?.uid}_${data['data']['jobId']}';
                      print('Opening chat with ID: $chatRoomId'); // Debug print
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            chatRoomId: chatRoomId,
                            jobTitle: data['data']['jobTitle'] ?? 'Chat',
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