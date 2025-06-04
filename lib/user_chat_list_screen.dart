import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class UserChatListScreen extends StatefulWidget {
  const UserChatListScreen({super.key});

  @override
  _UserChatListScreenState createState() => _UserChatListScreenState();
}

class _UserChatListScreenState extends State<UserChatListScreen> {
  final currentUser = FirebaseAuth.instance.currentUser;
  String _selectedFilter = 'All'; // All, Pending, Accepted

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Messages'),
      ),
      body: Column(
        children: [
          // Filter buttons
          Container(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: _buildFilterChip('All'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFilterChip('Pending'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFilterChip('Accepted'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Chat list
          Expanded(
            child: _buildChatList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('senderId', isEqualTo: currentUser?.uid)
          .where('type', isEqualTo: 'message')
          .snapshots(),
      builder: (context, notificationSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('chats')
              .where('participants', arrayContains: currentUser?.uid)
              .snapshots(),
          builder: (context, chatSnapshot) {
            // Combine pending (notifications) and accepted (chats) messages
            final List<Map<String, dynamic>> allMessages = [];

            // Add pending messages from notifications
            if (notificationSnapshot.hasData) {
              for (var doc in notificationSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                allMessages.add({
                  'id': doc.id,
                  'type': 'pending',
                  'jobTitle': data['data']['jobTitle'] ?? 'Unknown Job',
                  'businessName': data['data']['businessName'] ?? 'Unknown Business',
                  'message': data['message'],
                  'timestamp': data['timestamp'],
                  'data': data,
                });
              }
            }

            // Add accepted messages from chats
            if (chatSnapshot.hasData) {
              for (var doc in chatSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                allMessages.add({
                  'id': doc.id,
                  'type': 'accepted',
                  'jobTitle': data['jobTitle'] ?? 'Job Chat',
                  'businessName': data['businessName'] ?? '',
                  'lastMessage': data['lastMessage'] ?? '',
                  'lastMessageTime': data['lastMessageTime'],
                  'unreadCount': data['unreadCount'] ?? 0,
                  'lastSenderId': data['lastSenderId'],
                  'chatData': data,
                });
              }
            }

            // Filter based on selection
            List<Map<String, dynamic>> filteredMessages = allMessages;
            if (_selectedFilter == 'Pending') {
              filteredMessages = allMessages.where((msg) => msg['type'] == 'pending').toList();
            } else if (_selectedFilter == 'Accepted') {
              filteredMessages = allMessages.where((msg) => msg['type'] == 'accepted').toList();
            }

            // Sort: accepted first, then by timestamp
            filteredMessages.sort((a, b) {
              // First sort by type (accepted before pending)
              if (a['type'] != b['type']) {
                return a['type'] == 'accepted' ? -1 : 1;
              }

              // Then sort by timestamp
              final aTime = a['type'] == 'pending'
                  ? (a['timestamp'] as Timestamp?)
                  : (a['lastMessageTime'] as Timestamp?);
              final bTime = b['type'] == 'pending'
                  ? (b['timestamp'] as Timestamp?)
                  : (b['lastMessageTime'] as Timestamp?);

              if (aTime == null || bTime == null) return 0;
              return bTime.compareTo(aTime);
            });

            if (filteredMessages.isEmpty) {
              return Center(
                child: Text(
                  _selectedFilter == 'All'
                      ? 'No messages yet'
                      : 'No ${_selectedFilter.toLowerCase()} messages',
                ),
              );
            }

            return ListView.builder(
              itemCount: filteredMessages.length,
              itemBuilder: (context, index) {
                final message = filteredMessages[index];

                if (message['type'] == 'pending') {
                  return _buildPendingMessageTile(message);
                } else {
                  return _buildAcceptedChatTile(message);
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPendingMessageTile(Map<String, dynamic> message) {
    final timestamp = (message['timestamp'] as Timestamp?)?.toDate();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Colors.grey[100], // Grey color for pending
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: Colors.grey,
              child: Text(message['jobTitle'][0].toUpperCase()),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
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
                    message['jobTitle'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _getTimeAgo(timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            Text(
              message['businessName'],
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              message['message'],
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[700]),
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
                  fontSize: 11,
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAcceptedChatTile(Map<String, dynamic> message) {
    final chatData = message['chatData'] as Map<String, dynamic>;
    final lastMessageTime = (message['lastMessageTime'] as Timestamp?)?.toDate();
    final hasUnreadMessages = message['lastSenderId'] != currentUser?.uid &&
        message['unreadCount'] > 0;

    return Dismissible(
      key: Key(message['id']),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) => _deleteChat(message['id']),
      child: Card(
        elevation: hasUnreadMessages ? 3 : 1,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: hasUnreadMessages ? Colors.blue.shade50 : Colors.white,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Stack(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue,
                child: Text(message['jobTitle'][0].toUpperCase()),
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
                      message['unreadCount'].toString(),
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
                      message['jobTitle'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    _getTimeAgo(lastMessageTime),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              if (message['businessName'].isNotEmpty)
                Text(
                  message['businessName'],
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
                if (message['lastSenderId'] == currentUser?.uid)
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
                    message['lastMessage'],
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
                  chatRoomId: message['id'],
                  jobTitle: message['jobTitle'],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}