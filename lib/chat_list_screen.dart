import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
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
      setState(() {
        isBusinessOwner = docSnapshot['isBusinessOwner'] ?? false;
        _isLoading = false;
      });
    }
  }

  Future<void> _acceptMessage(Map<String, dynamic> data, String notificationId) async {
    try {
      // Create chat room
      final String chatRoomId = '${currentUser!.uid}_${data['senderId']}_${data['data']['jobId']}';
      final String jobTitle = data['data']['jobTitle'] ?? 'Job Chat';

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatRoomId)
          .set({
        'participants': [currentUser!.uid, data['senderId']],
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

      // Delete the notification
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message accepted')),
        );

        // Navigate to chat
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
    } catch (e) {
      print("Error accepting message: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error accepting message: $e')),
        );
      }
    }
  }

  Future<void> _rejectMessage(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message rejected')),
        );
      }
    } catch (e) {
      print("Error rejecting message: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rejecting message: $e')),
        );
      }
    }
  }

  Future<void> _deleteChat(String chatRoomId) async {
    try {
      // Delete all messages in the chat
      final messages = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatRoomId)
          .collection('messages')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var message in messages.docs) {
        batch.delete(message.reference);
      }
      await batch.commit();

      // Delete the chat document itself
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatRoomId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat deleted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting chat: $e')),
      );
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

    // If not a business owner, show the user chat list
    if (!isBusinessOwner) {
      return const UserChatListScreen();
    }

    // For business owners, show the tabbed interface
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Unread'),
            Tab(text: 'Read'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Unread Messages Tab
          _buildUnreadMessages(),
          // Read Messages Tab
          _buildReadMessages(),
        ],
      ),
    );
  }

  Widget _buildUnreadMessages() {
    if (!isBusinessOwner) {
      return const Center(
        child: Text('Only business owners can receive new messages'),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: currentUser?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No unread messages'));
        }

        // Filter for message type notifications and sort manually
        final messageDocs = snapshot.data!.docs
            .where((doc) => (doc.data() as Map<String, dynamic>)['type'] == 'message')
            .toList();

        messageDocs.sort((a, b) {
          final aTime = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
          final bTime = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime);
        });

        if (messageDocs.isEmpty) {
          return const Center(child: Text('No unread messages'));
        }

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
                            (data['data']['applicantName'] ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['data']['applicantName'] ?? 'Unknown',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Applied for: ${data['data']['jobTitle']}',
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
                        data['message'],
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => _rejectMessage(notification.id),
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
          return const Center(child: Text('No conversations yet'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final chat = snapshot.data!.docs[index];
            final data = chat.data() as Map<String, dynamic>;

            final lastMessage = data['lastMessage'] as String? ?? '';
            final jobTitle = data['jobTitle'] as String? ?? 'Job Chat';
            final businessName = data['businessName'] as String? ?? '';
            final lastSenderId = data['lastSenderId'] as String?;
            final lastMessageTime = (data['lastMessageTime'] as Timestamp?)?.toDate();
            final unreadCount = data['unreadCount'] as int? ?? 0;
            final participants = List<String>.from(data['participants'] ?? []);

            final isLastMessageMine = lastSenderId == currentUser?.uid;
            final hasUnreadMessages = !isLastMessageMine && unreadCount > 0;

            // Get the other participant's ID
            final otherUserId = participants.firstWhere(
                  (id) => id != currentUser?.uid,
              orElse: () => '',
            );

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
                        backgroundColor: hasUnreadMessages ? Colors.blue : Colors.grey,
                        child: Text(jobTitle[0].toUpperCase()),
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
                              jobTitle,
                              style: const TextStyle(fontWeight: FontWeight.bold),
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
                      if (businessName.isNotEmpty)
                        Text(
                          businessName,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        if (isLastMessageMine)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
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
                              color: hasUnreadMessages ? Colors.black87 : Colors.grey[600],
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
                        builder: (context) => ChatScreen(
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