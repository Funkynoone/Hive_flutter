import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatScreen extends StatefulWidget {
  final String chatRoomId;
  final String jobTitle;

  const ChatScreen({
    super.key,
    required this.chatRoomId,
    required this.jobTitle,
  });

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    // Mark messages as read when opening chat
    _markMessagesAsRead();
  }

  Future<void> _markMessagesAsRead() async {
    final messagesRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatRoomId)
        .collection('messages');

    final unreadMessages = await messagesRef
        .where('senderId', isNotEqualTo: currentUser?.uid)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = FirebaseFirestore.instance.batch();

    for (var doc in unreadMessages.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();

    // Reset unread count
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatRoomId)
        .update({'unreadCount': 0});
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    try {
      final chatRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatRoomId);

      // Add message with isRead field
      await chatRef.collection('messages').add({
        'text': _messageController.text,
        'senderId': currentUser?.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,  // Add this field
        'senderName': currentUser?.displayName ?? 'User'  // Optional: add sender name
      });

      // Update chat room
      await chatRef.update({
        'lastMessage': _messageController.text,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSenderId': currentUser?.uid  // Add this to track who sent last message
      });

      _messageController.clear();
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Fix red background
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chat'),
            Text(
              widget.jobTitle,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatRoomId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                int unreadCount = 0;
                for (var doc in snapshot.data!.docs) {
                  if (doc['senderId'] != currentUser?.uid && !(doc['isRead'] ?? false)) {
                    unreadCount++;
                  }
                }

                return Stack(
                  children: [
                    ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final message = snapshot.data!.docs[index];
                        final isMe = message['senderId'] == currentUser?.uid;
                        final isRead = message['isRead'] ?? false;

                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Stack(
                            children: [
                              Container(
                                margin: const EdgeInsets.symmetric(
                                  vertical: 4,
                                  horizontal: 8,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isMe ? Colors.blue : Colors.grey[300],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  message['text'],
                                  style: TextStyle(
                                    color: isMe ? Colors.white : Colors.black,
                                  ),
                                ),
                              ),
                              if (!isMe && !isRead)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 12,
                                      minHeight: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$unreadCount new messages',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}