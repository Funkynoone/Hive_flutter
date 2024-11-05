import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/models/job.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:hive_flutter/services/notification_service.dart';

class JobDetailScreen extends StatefulWidget {
  final Job job;

  const JobDetailScreen({super.key, required this.job});

  @override
  _JobDetailScreenState createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  bool isSaved = false;
  bool _isSending = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _checkIfSaved();
  }

  void _checkIfSaved() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final savedJobsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('savedJobs')
          .doc(widget.job.id)
          .get();
      setState(() {
        isSaved = savedJobsSnapshot.exists;
      });
    }
  }

  void _toggleSaveJob() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userSavedJobsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('savedJobs')
          .doc(widget.job.id);

      if (isSaved) {
        await userSavedJobsRef.delete();
      } else {
        await userSavedJobsRef.set({
          'title': widget.job.title,
          'restaurant': widget.job.restaurant,
          'type': widget.job.type,
          'description': widget.job.description,
          'latitude': widget.job.latitude,
          'longitude': widget.job.longitude,
          'category': widget.job.category,
          'imageUrl': widget.job.imageUrl,
        });
      }

      setState(() {
        isSaved = !isSaved;
      });
    }
  }

  Future<void> _uploadCV() async {
    try {
      setState(() => _isUploading = true);

      // Pick file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
      );

      if (result == null) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Get user data
      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      // Upload to Firebase Storage
      final file = File(result.files.single.path!);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${result.files.single.name}';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('cvs')
          .child(widget.job.id)
          .child(fileName);

      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();

      // Create application with CV
      await FirebaseFirestore.instance
          .collection('JobListings')
          .doc(widget.job.id)
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CV uploaded successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading CV: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _sendApplication(String message) async {
    setState(() => _isSending = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to apply')),
        );
        return;
      }

      // Get user data
      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      // Create the application
      await FirebaseFirestore.instance
          .collection('JobListings')
          .doc(widget.job.id)
          .collection('Applications')
          .add({
        'userId': user.uid,
        'name': userData['username'] ?? 'Anonymous',
        'message': message,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'message',
      });

      // Create notification for the owner
      await NotificationService().createNotification(
        userId: widget.job.ownerId,  // Make sure Job model includes ownerId
        senderId: user.uid,
        title: 'New Message',
        message: '${userData['username']} sent a message about ${widget.job.title}',
        type: 'message',
        data: {
          'jobId': widget.job.id,
          'jobTitle': widget.job.title,
          'applicantName': userData['username'],
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message sent successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _showMessageDialog() {
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
                _sendApplication(messageController.text);
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.job.title),
        actions: [
          IconButton(
            icon: Icon(isSaved ? Icons.favorite : Icons.favorite_border),
            color: isSaved ? Colors.red : Colors.white,
            onPressed: _toggleSaveJob,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.network(
              widget.job.imageUrl,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.business, size: 200),
            ),
            const SizedBox(height: 16),
            Text(
              widget.job.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              widget.job.restaurant,
              style: const TextStyle(fontSize: 20, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Type: ${widget.job.type}',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              'Category: ${widget.job.category.join(", ")}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'Description:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              widget.job.description,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            if (!_isSending && !_isUploading)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showMessageDialog,
                      icon: const Icon(Icons.message),
                      label: const Text('Contact Owner'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _uploadCV,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Send CV'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              )
            else
              const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}