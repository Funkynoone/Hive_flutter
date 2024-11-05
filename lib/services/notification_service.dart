import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/models/notification_model.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createNotification({
    required String userId,  // Owner's ID
    required String senderId,  // Applicant's ID
    required String title,
    required String message,
    required String type,
    required Map<String, dynamic> data,
  }) async {
    await _firestore.collection('notifications').add({
      'userId': userId,
      'senderId': senderId,
      'title': title,
      'message': message,
      'type': type,
      'read': false,
      'timestamp': FieldValue.serverTimestamp(),
      'data': data,
    });
  }

  Stream<List<NotificationModel>> getNotifications(String userId) {
    return _firestore
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => NotificationModel.fromFirestore(doc))
        .toList());
  }

  Future<void> markAsRead(String notificationId) async {
    await _firestore
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});
  }

  Future<void> deleteNotification(String notificationId) async {
    await _firestore.collection('notifications').doc(notificationId).delete();
  }
}