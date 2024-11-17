import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  _ChatListScreenState createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final currentUser = FirebaseAuth.instance.currentUser;

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
      ),
      body: StreamBuilder<QuerySnapshot>(
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
            return const Center(child: Text('No messages yet'));
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
                    trailing: PopupMenuButton(
                      icon: const Icon(Icons.more_vert),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          child: const ListTile(
                            leading: Icon(Icons.delete),
                            title: Text('Delete Chat'),
                            contentPadding: EdgeInsets.zero,
                          ),
                          onTap: () => _deleteChat(chat.id),
                        ),
                      ],
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
      ),
    );
  }
}