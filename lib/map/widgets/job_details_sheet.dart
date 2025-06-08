import 'package:flutter/material.dart';
import 'package:hive_flutter/models/job.dart';
import '../utils/job_marker_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/user_applications_screen.dart';
import 'package:hive_flutter/chat_screen.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class JobDetailsSheet extends StatefulWidget {
  final Job job;
  final Function(bool) setUploading;
  final Function(bool) setSending;

  const JobDetailsSheet({
    super.key,
    required this.job,
    required this.setUploading,
    required this.setSending,
  });

  @override
  State<JobDetailsSheet> createState() => _JobDetailsSheetState();
}

class _JobDetailsSheetState extends State<JobDetailsSheet> {
  final DraggableScrollableController _controller = DraggableScrollableController();
  bool _isExpanded = false;
  bool _isUploading = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onDragUpdate);
  }

  @override
  void dispose() {
    _controller.removeListener(_onDragUpdate);
    _controller.dispose();
    super.dispose();
  }

  void _onDragUpdate() {
    setState(() {
      _isExpanded = _controller.size > 0.6;
    });
  }

  // Updated _checkForExistingApplication for both job_detail_screen.dart and job_details_sheet.dart

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
    // Close the bottom sheet first
    Navigator.of(context).pop();

    // Then navigate to chat
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

      // If no chat, close bottom sheet and navigate to user applications screen
      Navigator.of(context).pop(); // Close bottom sheet
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

                setState(() => _isSending = true);
                widget.setSending(true);
                await _sendMessage(messageToSend);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Message cannot be empty.'),
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

  Future<void> _sendMessage(String message) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please login to apply'),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isSending = false);
          widget.setSending(false);
        }
        return;
      }

      final userDataSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final applicantName = userDataSnapshot.data()?['username'] ?? 'Anonymous Applicant';

      final WriteBatch batch = FirebaseFirestore.instance.batch();

      // 1. Create notification for the owner
      final notificationRef = FirebaseFirestore.instance.collection('notifications').doc();
      batch.set(notificationRef, {
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
        // Don't set status - let it remain null for pending state
      });

      // 2. Create message in user_messages for tracking user's applications
      final userMessageRef = FirebaseFirestore.instance.collection('user_messages').doc();
      batch.set(userMessageRef, {
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
      });

      await batch.commit();

      if (mounted) {
        // Show success toast
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Message sent successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Close the bottom sheet after a short delay
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    } catch (e) {
      print('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        widget.setSending(false);
      }
    }
  }

  Future<void> _uploadCV() async {
    // Check for existing application before uploading CV
    final hasExisting = await _checkForExistingApplication();
    if (hasExisting) {
      _showDuplicateApplicationDialog();
      return;
    }

    setState(() => _isUploading = true);
    widget.setUploading(true);

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
      );

      if (!mounted) return;
      if (result == null) {
        setState(() => _isUploading = false);
        widget.setUploading(false);
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please login to apply')),
          );
          setState(() => _isUploading = false);
          widget.setUploading(false);
        }
        return;
      }

      final userDataSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!mounted) return;
      final applicantName = userDataSnapshot.data()?['username'] ?? 'Anonymous Applicant';

      final file = File(result.files.single.path!);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${result.files.single.name}';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('cvs')
          .child(widget.job.id)
          .child(user.uid)
          .child(fileName);

      await storageRef.putFile(file);
      if (!mounted) return;
      final downloadUrl = await storageRef.getDownloadURL();
      if (!mounted) return;

      final WriteBatch batch = FirebaseFirestore.instance.batch();

      // 1. Create application in JobListings subcollection
      final applicationRef = FirebaseFirestore.instance
          .collection('JobListings')
          .doc(widget.job.id)
          .collection('Applications')
          .doc();
      batch.set(applicationRef, {
        'userId': user.uid,
        'name': applicantName,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
        'cvUrl': downloadUrl,
        'fileName': result.files.single.name,
        'type': 'cv',
      });

      // 2. Create notification for the owner
      final notificationRef = FirebaseFirestore.instance.collection('notifications').doc();
      batch.set(notificationRef, {
        'userId': widget.job.ownerId,
        'senderId': user.uid,
        'title': 'New CV Application for ${widget.job.title}',
        'message': '$applicantName submitted a CV for ${widget.job.title}.',
        'type': 'cv_application',
        'data': {
          'jobId': widget.job.id,
          'jobTitle': widget.job.title,
          'businessName': widget.job.restaurant,
          'applicantName': applicantName,
          'applicationId': applicationRef.id,
          'cvUrl': downloadUrl,
        },
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      // 3. Create message in user_messages for tracking
      final userMessageRef = FirebaseFirestore.instance.collection('user_messages').doc();
      batch.set(userMessageRef, {
        'userId': user.uid,
        'status': 'pending',
        'message': 'CV submitted for ${widget.job.title}',
        'data': {
          'jobTitle': widget.job.title,
          'businessName': widget.job.restaurant,
          'jobId': widget.job.id,
          'ownerId': widget.job.ownerId,
          'applicationType': 'cv',
          'applicationId': applicationRef.id,
        },
        'timestamp': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CV uploaded successfully!')),
        );

        // Close the bottom sheet after success
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    } catch (e) {
      print('Error uploading CV: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading CV: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
        widget.setUploading(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Dismiss the sheet when tapping outside
        Navigator.of(context).pop();
      },
      child: Container(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: () {}, // Prevent dismissal when tapping on the sheet itself
          child: DraggableScrollableSheet(
            initialChildSize: 0.35,
            minChildSize: 0.35,
            maxChildSize: 0.9,
            snap: true,
            snapSizes: const [0.35, 0.9],
            controller: _controller,
            builder: (context, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      spreadRadius: 2,
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildDragHandle(),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 12),
                            _buildTags(),
                            const SizedBox(height: 16),

                            // Show buttons in both collapsed and expanded states
                            _buildButtons(context, isCompact: !_isExpanded),

                            if (_isExpanded) ...[
                              const SizedBox(height: 16),
                              _buildFullDescription(),
                            ] else ...[
                              const SizedBox(height: 12),
                              _buildCompactDescription(),
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    'Drag up for more details',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: JobMarkerUtils.getJobColor(widget.job.category).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            JobMarkerUtils.getJobIcon(widget.job.category),
            color: JobMarkerUtils.getJobColor(widget.job.category),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.job.restaurant,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.job.title,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTags() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildTag(
          Icons.work_outline,
          widget.job.type,
          Colors.blue,
        ),
        _buildTag(
          Icons.euro,
          widget.job.salaryNotGiven
              ? 'Not Given'
              : '${widget.job.salary} ${widget.job.salaryType}',
          Colors.green,
        ),
      ],
    );
  }

  Widget _buildTag(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.job.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildFullDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Description',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.job.description,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Requirements',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.job.requirements,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildButtons(BuildContext context, {bool isCompact = false}) {
    final verticalPadding = isCompact ? 8.0 : 12.0;
    final fontSize = isCompact ? 14.0 : 16.0;

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isUploading ? null : _uploadCV,
            icon: Icon(Icons.upload_file, size: isCompact ? 18 : 24),
            label: Text(
              _isUploading ? 'Uploading...' : 'Send CV',
              style: TextStyle(fontSize: fontSize),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: verticalPadding),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isSending ? null : _showMessageDialog,
            icon: Icon(Icons.message, size: isCompact ? 18 : 24),
            label: Text(
              _isSending ? 'Sending...' : 'Contact',
              style: TextStyle(fontSize: fontSize),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: verticalPadding),
            ),
          ),
        ),
      ],
    );
  }
}