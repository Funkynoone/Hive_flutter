import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String userId;  // Owner's ID
  final String senderId;  // Applicant's ID
  final String title;
  final String message;
  final String type;  // 'message' or 'cv'
  final bool read;
  final DateTime timestamp;
  final Map<String, dynamic> data;  // Additional data like jobId, etc.

  NotificationModel({
    required this.id,
    required this.userId,
    required this.senderId,
    required this.title,
    required this.message,
    required this.type,
    required this.read,
    required this.timestamp,
    required this.data,
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      senderId: data['senderId'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      type: data['type'] ?? '',
      read: data['read'] ?? false,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      data: data['data'] ?? {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'senderId': senderId,
      'title': title,
      'message': message,
      'type': type,
      'read': read,
      'timestamp': Timestamp.fromDate(timestamp),
      'data': data,
    };
  }
}