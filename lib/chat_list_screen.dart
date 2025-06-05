import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/chat_screen.dart';
import 'package:hive_flutter/user_chat_list_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  _ChatListScreenState createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with SingleTickerProviderStateMixin {
  final currentUser = FirebaseAuth.instance.currentUser;
  late TabController _tabController;
  bool isBusinessOwner = false;
  bool _isLoading = true;

  int _unreadMessagesCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkUserRole();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (mounted) {
        setState(() {
          isBusinessOwner = docSnapshot.exists
              ? (docSnapshot.data()?['isBusinessOwner'] ?? false)
              : false;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _acceptMessage(Map<String, dynamic> originalNotificationData,
      String notificationId) async {
    final ownerUid = currentUser!.uid;
    final applicantId = originalNotificationData['senderId'] as String?;
    final jobId = originalNotificationData['data']?['jobId'] as String?;
    final jobTitle = originalNotificationData['data']?['jobTitle'] ?? 'Job Chat';
    final initialMessage = originalNotificationData['message'] as String?;
    final applicantName = originalNotificationData['data']?['applicantName'] as String?;
    final businessName = originalNotificationData['data']?['businessName'] ?? 'Your Business';

    if (applicantId == null || jobId == null || initialMessage == null) {
      print("Error: Missing crucial data in notification for acceptance.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Error processing acceptance: key data missing.')),
        );
      }
      return;
    }

    try {
      final String chatRoomId = '${ownerUid}_${applicantId}_$jobId';
      WriteBatch batch = FirebaseFirestore.instance.batch();

      // 1. Create the chat room
      DocumentReference chatRef = FirebaseFirestore.instance.collection('chats')
          .doc(chatRoomId);
      batch.set(chatRef, {
        'participants': [ownerUid, applicantId],
        'jobId': jobId,
        'jobTitle': jobTitle,
        'businessName': businessName,
        'applicantName': applicantName,
        'ownerId': ownerUid,
        'applicantId': applicantId,
        'lastMessage': initialMessage,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSenderId': applicantId,
        'unreadCount': 1,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'active',
      });

      // 2. Add the initial message to the chat
      DocumentReference messageRef = chatRef.collection('messages').doc();
      batch.set(messageRef, {
        'text': initialMessage,
        'senderId': applicantId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'senderName': applicantName,
      });

      // 3. Update notification status instead of deleting
      DocumentReference notificationRefDoc = FirebaseFirestore.instance
          .collection('notifications').doc(notificationId);
      batch.update(notificationRefDoc, {
        'status': 'accepted',
        'processedAt': FieldValue.serverTimestamp(),
        'chatRoomId': chatRoomId,
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Application accepted. Chat started.')),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ChatScreen(
                  chatRoomId: chatRoomId,
                  jobTitle: jobTitle,
                ),
          ),
        );
      }
    } catch (e) {
      print("Error accepting message: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error accepting message: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _rejectMessage(Map<String, dynamic> originalNotificationData,
      String notificationId) async {
    final applicantId = originalNotificationData['senderId'] as String?;
    final jobId = originalNotificationData['data']?['jobId'] as String?;
    final jobTitle = originalNotificationData['data']?['jobTitle'] as String?;
    final businessName = originalNotificationData['data']?['businessName'] as String?;
    final ownerUid = currentUser!.uid;

    if (applicantId == null || jobId == null || jobTitle == null || businessName == null) {
      print("Error: Missing crucial data in notification for rejection feedback.");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Error processing rejection: key data missing for feedback.')),
        );
      }
      return;
    }

    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();

      // 1. Create a "declined" feedback document for the user
      DocumentReference feedbackRef = FirebaseFirestore.instance.collection('userApplicationFeedback').doc();
      batch.set(feedbackRef, {
        'userId': applicantId,
        'ownerId': ownerUid,
        'jobId': jobId,
        'jobTitle': jobTitle,
        'businessName': businessName,
        'status': 'declined',
        'timestamp': FieldValue.serverTimestamp(),
        'originalNotificationId': notificationId,
      });

      // 2. Update notification status instead of deleting
      DocumentReference notificationRefDoc = FirebaseFirestore.instance
          .collection('notifications').doc(notificationId);
      batch.update(notificationRefDoc, {
        'status': 'declined',
        'processedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Application rejected. Feedback sent to user.')),
        );
      }
    } catch (e) {
      print("Error rejecting message: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rejecting message: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _deleteChat(String chatRoomId) async {
    try {
      final messages = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatRoomId)
          .collection('messages')
          .get();

      final batchDelete = FirebaseFirestore.instance.batch();
      for (var message in messages.docs) {
        batchDelete.delete(message.reference);
      }
      await batchDelete.commit();

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatRoomId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting chat: $e')),
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
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Messages')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!isBusinessOwner) {
      return const UserChatListScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Applicants'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: [
            Tab(text: 'Unread ($_unreadMessagesCount)'),
            const Tab(text: 'Active Chats'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUnreadMessages(),
          _buildReadMessages(),
        ],
      ),
    );
  }

  Widget _buildUnreadMessages() {
    if (!isBusinessOwner) {
      return const Center(child: Text("Access denied."));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: currentUser?.uid)
          .where('type', isEqualTo: 'message')
          .where('status', isNull: true) // Only show unprocessed notifications
          .orderBy('status') // Add this to the compound index
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        print("DEBUG: Unread messages stream - ConnectionState: ${snapshot.connectionState}");
        print("DEBUG: Has data: ${snapshot.hasData}, Has error: ${snapshot.hasError}");

        if (snapshot.hasError) {
          print("ERROR in unread messages: ${snapshot.error}");
          if (snapshot.error.toString().contains('index')) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.orange),
                    const SizedBox(height: 16),
                    const Text('Database index required'),
                    const SizedBox(height: 8),
                    Text(
                      'Please create an index for:\nnotifications -> userId + type + status + timestamp (descending)',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    Text('Error details: ${snapshot.error}', style: TextStyle(fontSize: 12, color: Colors.red[300])),
                  ],
                ),
              ),
            );
          }
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.hasData) {
          final newCount = snapshot.data!.docs.length;
          if (_unreadMessagesCount != newCount) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _unreadMessagesCount = newCount;
                });
              }
            });
          }
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No new applications'));
        }

        final messageDocs = snapshot.data!.docs;

        return ListView.builder(
          itemCount: messageDocs.length,
          itemBuilder: (context, index) {
            final notification = messageDocs[index];
            final data = notification.data() as Map<String, dynamic>;

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: Text(
                            (data['data']?['applicantName'] ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['data']?['applicantName'] ?? 'Unknown Applicant',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Applied for: ${data['data']?['jobTitle'] ?? 'N/A'}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _getTimeAgo((data['timestamp'] as Timestamp?)?.toDate()),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        data['message'] ?? 'No message content.',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => _rejectMessage(data, notification.id),
                          icon: const Icon(Icons.close, color: Colors.red),
                          label: const Text('Reject', style: TextStyle(color: Colors.red)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () => _acceptMessage(data, notification.id),
                          icon: const Icon(Icons.check),
                          label: const Text('Accept'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
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

  Widget _buildReadMessages() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUser?.uid)
          .orderBy('lastMessageTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No active conversations'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final chat = snapshot.data!.docs[index];
            final data = chat.data() as Map<String, dynamic>;

            final lastMessage = data['lastMessage'] as String? ?? '';
            final jobTitle = data['jobTitle'] as String? ?? 'Job Chat';
            final otherPartyName = data['applicantName'] as String? ?? 'Applicant';
            final lastSenderId = data['lastSenderId'] as String?;
            final lastMessageTime = (data['lastMessageTime'] as Timestamp?)
                ?.toDate();
            final unreadCount = data['unreadCount'] as int? ?? 0;

            final isLastMessageMine = lastSenderId == currentUser?.uid;
            final hasUnreadMessages = !isLastMessageMine && unreadCount > 0;

            return Dismissible(
              key: Key(chat.id),
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              onDismissed: (direction) => _deleteChat(chat.id),
              child: Card(
                elevation: hasUnreadMessages ? 3 : 1,
                color: hasUnreadMessages ? Colors.blue.shade50 : null,
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        backgroundColor: hasUnreadMessages
                            ? Colors.blue
                            : Colors.grey,
                        child: Text(otherPartyName.isNotEmpty ? otherPartyName[0]
                            .toUpperCase() : jobTitle[0].toUpperCase()),
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
                              unreadCount.toString(),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              otherPartyName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (lastMessageTime != null)
                            Text(
                              _getTimeAgo(lastMessageTime),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                      Text(
                        jobTitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Row(
                      children: [
                        if (isLastMessageMine)
                          Padding(
                            padding: const EdgeInsets.only(right: 4.0),
                            child: Icon(
                              Icons.done,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        Expanded(
                          child: Text(
                            lastMessage,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: hasUnreadMessages ? Colors.black87 : Colors
                                  .grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ChatScreen(
                              chatRoomId: chat.id,
                              jobTitle: jobTitle,
                            ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}