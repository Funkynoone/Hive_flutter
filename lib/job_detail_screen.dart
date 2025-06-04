import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/models/job.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:hive_flutter/services/notification_service.dart'; // Assuming this service exists and works

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
      if (mounted) {
        setState(() {
          isSaved = savedJobsSnapshot.exists;
        });
      }
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
        // Make sure all fields from Job object are being saved
        await userSavedJobsRef.set({
          'id': widget.job.id, // It's good practice to save the ID too
          'title': widget.job.title,
          'restaurant': widget.job.restaurant,
          'type': widget.job.type,
          'description': widget.job.description,
          'latitude': widget.job.latitude,
          'longitude': widget.job.longitude,
          'category': widget.job.category,
          'imageUrl': widget.job.imageUrl,
          'ownerId': widget.job.ownerId, // Save ownerId if needed later
          'timestamp': FieldValue.serverTimestamp(), // Good to have a saved time
        });
      }
      if (mounted) {
        setState(() {
          isSaved = !isSaved;
        });
      }
    }
  }

  Future<void> _uploadCV() async {
    // Check if mounted at the beginning of the async operation
    if (!mounted) return;
    setState(() => _isUploading = true);

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
      );

      if (!mounted) return; // Check again after await
      if (result == null) {
        setState(() => _isUploading = false);
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please login to apply')),
          );
          setState(() => _isUploading = false);
        }
        return;
      }

      final userDataSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!mounted) return; // Check again after await
      final applicantName = userDataSnapshot.data()?['username'] ?? 'Anonymous Applicant';

      final file = File(result.files.single.path!);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${result.files.single.name}';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('cvs')
          .child(widget.job.id) // Job ID as a folder
          .child(user.uid) // User ID as a subfolder
          .child(fileName);

      await storageRef.putFile(file);
      if (!mounted) return; // Check again after await
      final downloadUrl = await storageRef.getDownloadURL();
      if (!mounted) return; // Check again after await

      final WriteBatch batch = FirebaseFirestore.instance.batch();

      // 1. Create application in JobListings subcollection
      final applicationRef = FirebaseFirestore.instance
          .collection('JobListings')
          .doc(widget.job.id)
          .collection('Applications')
          .doc(); // Auto-generate ID
      batch.set(applicationRef, {
        'userId': user.uid,
        'name': applicantName,
        'status': 'pending', // This status is for the owner's view of applications
        'timestamp': FieldValue.serverTimestamp(),
        'cvUrl': downloadUrl,
        'fileName': result.files.single.name,
        'type': 'cv', // Differentiate CV application
      });

      // 2. Create notification for the owner
      final notificationRef = FirebaseFirestore.instance.collection('notifications').doc();
      batch.set(notificationRef, {
        'userId': widget.job.ownerId, // Owner who receives notification
        'senderId': user.uid, // User who sent it
        'title': 'New CV Application for ${widget.job.title}',
        'message': '$applicantName submitted a CV for ${widget.job.title}.',
        'type': 'cv_application', // More specific type
        'data': {
          'jobId': widget.job.id,
          'jobTitle': widget.job.title,
          'businessName': widget.job.restaurant,
          'applicantName': applicantName,
          'applicationId': applicationRef.id, // Link to the application document
          'cvUrl': downloadUrl,
        },
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });


      // 3. Create message in user_messages for the applicant (for their Pending tab)
      final userMessageRef = FirebaseFirestore.instance.collection('user_messages').doc(); // Auto-ID or custom
      batch.set(userMessageRef, {
        'userId': user.uid, // The applicant themselves
        'status': 'pending',
        'message': 'CV submitted for ${widget.job.title}', // Or a more generic message
        'data': {
          'jobTitle': widget.job.title,
          'businessName': widget.job.restaurant,
          'jobId': widget.job.id,
          'ownerId': widget.job.ownerId,
          'applicationType': 'cv',
          'applicationId': applicationRef.id, // Link to the application document
        },
        'timestamp': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CV submitted successfully!')),
        );
      }
    } catch (e) {
      print('Error uploading CV: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading CV: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _sendApplication(String message) async {
    if (!mounted) return; // Check if mounted at the beginning
    setState(() => _isSending = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) { // Check mounted before showing SnackBar
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please login to apply')),
          );
        }
        // No need to call setState here if already returning
        // setState(() => _isSending = false); // This was potentially problematic
        return; // Return early
      }

      final userDataSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return; // Check mounted after await

      final applicantName = userDataSnapshot.data()?['username'] ?? 'Anonymous Applicant';

      final WriteBatch batch = FirebaseFirestore.instance.batch();

      // 1. Create the application in JobListings subcollection
      final applicationRef = FirebaseFirestore.instance
          .collection('JobListings')
          .doc(widget.job.id)
          .collection('Applications')
          .doc(); // Auto-generate ID
      batch.set(applicationRef, {
        'userId': user.uid,
        'name': applicantName,
        'message': message,
        'status': 'pending', // This status is for the owner's view of applications
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'message', // Differentiate message application
      });

      // 2. Create notification for the owner
      final notificationRef = FirebaseFirestore.instance.collection('notifications').doc();
      batch.set(notificationRef, {
        'userId': widget.job.ownerId, // Owner who receives notification
        'senderId': user.uid, // User who sent it
        'title': 'New Message for ${widget.job.title}',
        'message': message, // The actual message content
        'type': 'message_application', // More specific type
        'data': {
          'jobId': widget.job.id,
          'jobTitle': widget.job.title,
          'businessName': widget.job.restaurant,
          'applicantName': applicantName,
          'applicationId': applicationRef.id, // Link to the application document
        },
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      // 3. Create message in user_messages for the applicant (for their Pending tab)
      final userMessageRef = FirebaseFirestore.instance.collection('user_messages').doc(); // Auto-ID or custom
      batch.set(userMessageRef, {
        'userId': user.uid, // The applicant themselves
        'status': 'pending',
        'message': message, // The message content
        'data': { // Data expected by UserChatListScreen's _buildMessageCard
          'jobTitle': widget.job.title,
          'businessName': widget.job.restaurant,
          'jobId': widget.job.id, // For linking with owner's actions
          'ownerId': widget.job.ownerId, // For reference
          'applicationType': 'message',
          'applicationId': applicationRef.id, // Link to the application document
        },
        'timestamp': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (mounted) { // Check mounted before showing SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message sent successfully!')),
        );
      }
    } catch (e) {
      print('Error sending message: $e');
      if (mounted) { // Check mounted before showing SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) { // Check mounted before calling setState
        setState(() => _isSending = false);
      }
    }
  }

  void _showMessageDialog() {
    final messageController = TextEditingController();
    showDialog(
      context: context,
      builder: (contextDialog) => AlertDialog( // Renamed context to contextDialog
        title: const Text('Send Message to Owner'),
        content: TextField(
          controller: messageController,
          decoration: const InputDecoration(
            hintText: 'Write your message...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contextDialog),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (messageController.text.trim().isNotEmpty) {
                // It's generally safer to pop the dialog *after* the async operation might start,
                // or ensure the async operation checks for `mounted` if it interacts with the dialog's context.
                // However, since _sendApplication handles its own mounted checks for UI updates,
                // popping here is okay.
                final messageToSend = messageController.text.trim();
                Navigator.pop(contextDialog); // Pop the dialog first
                _sendApplication(messageToSend);
              } else {
                // Check if contextDialog is still valid if it were used for ScaffoldMessenger
                // For this simple SnackBar, using the main screen's context is fine if dialog is popped.
                ScaffoldMessenger.of(context).showSnackBar( // Using the main context after dialog pop
                    const SnackBar(content: Text('Message cannot be empty.'), duration: Duration(seconds: 2),)
                );
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
            color: isSaved ? Colors.red : null, // Use default color or Colors.white
            onPressed: _toggleSaveJob,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.job.imageUrl.isNotEmpty)
              Image.network(
                widget.job.imageUrl,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Container(
                      height: 200,
                      width: double.infinity,
                      color: Colors.grey[300],
                      child: Icon(Icons.business, size: 100, color: Colors.grey[600]),
                    ),
              )
            else
              Container(
                height: 200,
                width: double.infinity,
                color: Colors.grey[300],
                child: Icon(Icons.business, size: 100, color: Colors.grey[600]),
              ),
            const SizedBox(height: 16),
            Text(
              widget.job.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              widget.job.restaurant,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: [
                Chip(label: Text('Type: ${widget.job.type}')),
                if(widget.job.category.isNotEmpty)
                  Chip(label: Text('Category: ${widget.job.category.join(", ")}')),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Description:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              widget.job.description,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 24),
            if (_isSending || _isUploading)
              const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: CircularProgressIndicator(),
              ))
            else
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showMessageDialog,
                      icon: const Icon(Icons.message_outlined),
                      label: const Text('Contact Owner'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        // backgroundColor: Theme.of(context).primaryColor,
                        // foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _uploadCV,
                      icon: const Icon(Icons.upload_file_outlined),
                      label: const Text('Send CV'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        // backgroundColor: Colors.green,
                        // foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 20), // Add some padding at the bottom
          ],
        ),
      ),
    );
  }
}
