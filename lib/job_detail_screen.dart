import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/models/job.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:hive_flutter/user_applications_screen.dart';
import 'package:hive_flutter/chat_screen.dart';
import 'dart:io';

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

  Future<bool> _checkForExistingApplication() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    try {
      // Check for existing notifications (pending applications)
      final existingNotifications = await FirebaseFirestore.instance
          .collection('notifications')
          .where('senderId', isEqualTo: user.uid)
          .where('userId', isEqualTo: widget.job.ownerId)
          .get();

      for (var doc in existingNotifications.docs) {
        final data = doc.data();
        final jobId = data['data']?['jobId'] as String?;
        final status = data['status'] as String?;

        if (jobId == widget.job.id) {
          if (status == null || status == 'pending') {
            // Found pending application - prevent duplicate
            print('Found pending application for job ${widget.job.id}');
            return true;
          } else if (status == 'accepted') {
            // Found accepted application - redirect to chat
            print('Found accepted application for job ${widget.job.id}');
            final chatRoomId = data['chatRoomId'] as String?;
            if (chatRoomId != null && mounted) {
              _navigateToExistingChat(chatRoomId);
              return true;
            }
          } else if (status == 'rejected' || status == 'declined') {
            // Application was rejected - allow new application
            print('Found rejected application for job ${widget.job.id} - allowing new application');
            continue; // Don't prevent, allow new application
          }
        }
      }

      // Check for existing chats (active conversations)
      final existingChats = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: user.uid)
          .where('ownerId', isEqualTo: widget.job.ownerId)
          .where('jobId', isEqualTo: widget.job.id)
          .get();

      if (existingChats.docs.isNotEmpty && mounted) {
        print('Found existing chat for job ${widget.job.id}');
        _navigateToExistingChat(existingChats.docs.first.id);
        return true;
      }

      print('No existing application found for job ${widget.job.id} - allowing new application');
      return false;
    } catch (e) {
      print('Error checking for existing application: $e');
      return false;
    }
  }

  void _navigateToExistingChat(String chatRoomId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          chatRoomId: chatRoomId,
          jobTitle: widget.job.title,
        ),
      ),
    );
  }

  void _showDuplicateApplicationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange),
              SizedBox(width: 8),
              Text('Application Exists'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You already have an application with ${widget.job.restaurant} for this position.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 12),
              Text(
                'What would you like to do?',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _findAndNavigateToApplication();
              },
              child: Text('View Application'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _findAndNavigateToApplication() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // First check for active chats
      final chats = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: user.uid)
          .where('ownerId', isEqualTo: widget.job.ownerId)
          .where('jobId', isEqualTo: widget.job.id)
          .get();

      if (chats.docs.isNotEmpty) {
        _navigateToExistingChat(chats.docs.first.id);
        return;
      }

      // If no chat, navigate to user applications screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const UserApplicationsScreen(),
        ),
      );
    } catch (e) {
      print('Error finding application: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error finding your application: $e')),
        );
      }
    }
  }

  void _showMessageDialog() {
    final messageController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
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
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (messageController.text.trim().isNotEmpty) {
                final messageToSend = messageController.text.trim();

                // Close dialog first
                Navigator.pop(dialogContext);

                // Check for existing application before sending
                final hasExisting = await _checkForExistingApplication();
                if (hasExisting) {
                  _showDuplicateApplicationDialog();
                  return;
                }

                // Add a small delay to ensure dialog is closed
                await Future.delayed(const Duration(milliseconds: 100));

                // Send the message
                await _sendApplication(messageToSend);
              } else {
                // Show error in dialog context
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Message cannot be empty.'),
                    duration: Duration(seconds: 2),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadCV() async {
    // Check for existing application before uploading CV
    final hasExisting = await _checkForExistingApplication();
    if (hasExisting) {
      _showDuplicateApplicationDialog();
      return;
    }

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
      final userMessageRef = FirebaseFirestore.instance.collection('user_messages').doc();
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
    print("🔵 DEBUG: Starting _sendApplication");
    print("🔵 DEBUG: Message: $message");
    print("🔵 DEBUG: Job ID: ${widget.job.id}");
    print("🔵 DEBUG: Owner ID: ${widget.job.ownerId}");

    if (!mounted) {
      print("🔴 DEBUG: Widget not mounted, returning early");
      return;
    }

    setState(() => _isSending = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print("🔴 DEBUG: No user logged in");
        if (mounted) {
          setState(() => _isSending = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please login to apply'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      print("🔵 DEBUG: Current user ID: ${user.uid}");

      final userDataSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) {
        print("🔴 DEBUG: Widget unmounted after getting user data");
        return;
      }

      final applicantName = userDataSnapshot.data()?['username'] ?? 'Anonymous Applicant';
      print("🔵 DEBUG: Applicant name: $applicantName");

      final WriteBatch batch = FirebaseFirestore.instance.batch();

      // 1. Create notification for the owner
      final notificationRef = FirebaseFirestore.instance.collection('notifications').doc();
      print("🔵 DEBUG: Creating notification with ID: ${notificationRef.id}");

      final notificationData = {
        'userId': widget.job.ownerId,
        'senderId': user.uid,
        'type': 'message',
        'message': message,
        'data': {
          'jobId': widget.job.id,
          'jobTitle': widget.job.title,
          'businessName': widget.job.restaurant,
          'applicantName': applicantName,
        },
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      };

      print("🔵 DEBUG: Notification data: $notificationData");
      batch.set(notificationRef, notificationData);

      // 2. Create message in user_messages
      final userMessageRef = FirebaseFirestore.instance.collection('user_messages').doc();
      print("🔵 DEBUG: Creating user_message with ID: ${userMessageRef.id}");

      final userMessageData = {
        'userId': user.uid,
        'ownerId': widget.job.ownerId,
        'status': 'pending',
        'message': message,
        'data': {
          'jobTitle': widget.job.title,
          'businessName': widget.job.restaurant,
          'jobId': widget.job.id,
          'ownerId': widget.job.ownerId,
        },
        'timestamp': FieldValue.serverTimestamp(),
      };

      print("🔵 DEBUG: User message data: $userMessageData");
      batch.set(userMessageRef, userMessageData);

      print("🔵 DEBUG: Committing batch...");
      await batch.commit();
      print("✅ DEBUG: Batch committed successfully");

      if (mounted) {
        setState(() => _isSending = false);

        // Show success message
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Message sent successfully!',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(10),
          ),
        );

        print("✅ DEBUG: SnackBar should be showing now");

        // Navigate back after a short delay
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      }
    } catch (e) {
      print("🔴 ERROR in _sendApplication: $e");
      print("🔴 ERROR Stack trace: ${StackTrace.current}");
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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