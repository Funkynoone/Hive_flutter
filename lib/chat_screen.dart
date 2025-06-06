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
  bool isBusinessOwner = false;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
    _markMessagesAsRead();
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
      });
    }
  }

  Future<void> _markMessagesAsRead() async {
    final chatRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatRoomId);

    // Get the chat document first to check current state
    final chatDoc = await chatRef.get();
    if (!chatDoc.exists) return;

    final chatData = chatDoc.data() as Map<String, dynamic>;
    final ownerId = chatData['ownerId'] as String?;
    final applicantId = chatData['applicantId'] as String?;

    // Determine which unread count field to reset based on who's viewing
    String unreadCountField;
    if (currentUser?.uid == ownerId) {
      unreadCountField = 'ownerUnreadCount';
    } else if (currentUser?.uid == applicantId) {
      unreadCountField = 'applicantUnreadCount';
    } else {
      return; // User not part of this chat
    }

    // Get unread messages sent by the other person
    final messagesRef = chatRef.collection('messages');
    final unreadMessages = await messagesRef
        .where('senderId', isNotEqualTo: currentUser?.uid)
        .where('isRead', isEqualTo: false)
        .get();

    if (unreadMessages.docs.isNotEmpty) {
      // Mark messages as read
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      // Reset the appropriate unread count
      batch.update(chatRef, {unreadCountField: 0});

      await batch.commit();
    }
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    try {
      final chatRef = FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatRoomId);

      // Get chat data to determine other participant and current counts
      final chatData = await chatRef.get();
      final data = chatData.data() as Map<String, dynamic>;
      final ownerId = data['ownerId'] as String?;
      final applicantId = data['applicantId'] as String?;

      // Determine which unread count to increment
      String incrementField;
      if (currentUser?.uid == ownerId) {
        incrementField = 'applicantUnreadCount';
      } else {
        incrementField = 'ownerUnreadCount';
      }

      // Get current unread count for the recipient
      final currentUnreadCount = data[incrementField] ?? 0;

      // Add message
      await chatRef.collection('messages').add({
        'text': _messageController.text,
        'senderId': currentUser?.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'senderName': currentUser?.displayName ?? 'User'
      });

      // Update chat room
      await chatRef.update({
        'lastMessage': _messageController.text,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSenderId': currentUser?.uid,
        // Increment unread count only for the recipient
        incrementField: currentUnreadCount + 1
      });

      _messageController.clear();
    } catch (e) {
      print('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
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

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final message = snapshot.data!.docs[index];
                    final isMe = message['senderId'] == currentUser?.uid;
                    final isRead = message['isRead'] ?? false;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: EdgeInsets.only(
                          left: isMe ? 64 : 8,
                          right: isMe ? 8 : 64,
                          top: 4,
                          bottom: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue : Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Column(
                                crossAxisAlignment: isMe
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    message['text'],
                                    style: TextStyle(
                                      color: isMe ? Colors.white : Colors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    message['senderName'] ?? 'Unknown',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isMe ? Colors.white70 : Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isMe)
                              Positioned(
                                right: 4,
                                bottom: 4,
                                child: Icon(
                                  isRead ? Icons.done_all : Icons.done,
                                  size: 12,
                                  color: Colors.white70,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
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
                    onSubmitted: (_) => _sendMessage(),
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