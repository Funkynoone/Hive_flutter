import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:hive_flutter/services/notification_service.dart';
import 'package:hive_flutter/models/job.dart';

class JobApplicationService {
  static Future<bool> uploadCV(
      Job job,
      BuildContext context,
      Function(bool) setUploading,
      ) async {
    try {
      setUploading(true);

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
      );

      if (result == null) {
        setUploading(false);
        return false;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setUploading(false);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please login to apply')),
          );
        }
        return false;
      }

      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final file = File(result.files.single.path!);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${result.files.single.name}';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('cvs')
          .child(job.id)
          .child(fileName);

      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('JobListings')
          .doc(job.id)
          .collection('Applications')
          .add({
        'userId': user.uid,
        'name': userData['username'] ?? 'Anonymous',
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
        'cvUrl': downloadUrl,
        'fileName': result.files.single.name,
        'type': 'cv',
      });

      await NotificationService().createNotification(
        userId: job.ownerId,
        senderId: user.uid,
        title: 'New CV Application',
        message: '${userData['username'] ?? 'Anonymous'} submitted a CV application',
        type: 'cv',
        data: {
          'jobId': job.id,
          'jobTitle': job.title,
          'businessName': job.restaurant,
          'applicantName': userData['username'] ?? 'Anonymous',
          'cvUrl': downloadUrl,
          'timestamp': FieldValue.serverTimestamp(),
        },
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CV uploaded successfully!')),
        );
      }
      return true;
    } catch (e) {
      print('Error uploading CV: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading CV: $e')),
        );
      }
      return false;
    } finally {
      setUploading(false);
    }
  }

  static Future<bool> sendApplication(
      Job job,
      String message,
      BuildContext context,
      Function(bool) setSending,
      ) async {
    setSending(true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to apply')),
        );
        return false;
      }

      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      await FirebaseFirestore.instance
          .collection('JobListings')
          .doc(job.id)
          .collection('Applications')
          .add({
        'userId': user.uid,
        'name': userData['username'] ?? 'Anonymous',
        'message': message,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'message',
      });

      await NotificationService().createNotification(
        userId: job.ownerId,
        senderId: user.uid,
        title: 'New Message',
        message: message,
        type: 'message',
        data: {
          'jobId': job.id,
          'jobTitle': job.title,
          'businessName': job.restaurant,
          'applicantName': userData['username'] ?? 'Anonymous',
          'timestamp': FieldValue.serverTimestamp(),
        },
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message sent successfully!')),
        );
      }
      return true;
    } catch (e) {
      print('Error sending message: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
        );
      }
      return false;
    } finally {
      setSending(false);
    }
  }

  static void showMessageDialog(BuildContext context, Job job, Function(bool) setSending) {
    final messageController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Message to Owner'),
        content: TextField(
          controller: messageController,
          decoration: const InputDecoration(
            hintText: 'Write your message...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (messageController.text.isNotEmpty) {
                Navigator.pop(context);
                sendApplication(job, messageController.text, context, setSending);
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}