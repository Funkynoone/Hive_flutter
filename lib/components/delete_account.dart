import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DeleteAccountButton extends StatelessWidget {
  const DeleteAccountButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
        ),
        onPressed: () => _showDeleteConfirmation(context),
        child: const Text('Delete Account'),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) { // Use separate context for dialog
        return AlertDialog(
          title: const Text('Delete Account'),
          content: const Text(
              'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently deleted, including:\n\n'
                  '• Your profile information\n'
                  '• Saved jobs\n'
                  '• Job applications\n'
                  '• Messages and chat rooms\n'
                  '• Notifications'
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _deleteAccount(context); // Pass original context
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext loadingContext) {
        return WillPopScope(
          onWillPop: () async => false,
          child: const Center(child: CircularProgressIndicator()),
        );
      },
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        return;
      }

      final userId = user.uid;

      // Delete Firestore data
      await _deleteFirestoreData(userId);

      // Delete auth user
      await user.delete();

      // Navigate to login screen
      if (context.mounted) {
        // Pop the loading dialog first
        Navigator.of(context).pop();
        // Then navigate to login
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      print('Error in delete account: $e');
      // Make sure to pop the loading dialog on error
      if (context.mounted) {
        Navigator.of(context).pop(); // Remove loading dialog

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete account: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );

        // Try to sign out anyway if there was an error
        try {
          await FirebaseAuth.instance.signOut();
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        } catch (signOutError) {
          print('Error signing out: $signOutError');
        }
      }
    }
  }

  Future<void> _deleteFirestoreData(String userId) async {
    // Delete saved jobs
    final savedJobsSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('savedJobs')
        .get();

    for (var doc in savedJobsSnapshot.docs) {
      await doc.reference.delete();
    }

    // Delete notifications
    final notificationsSnapshot = await FirebaseFirestore.instance
        .collection('notifications')
        .where('senderId', isEqualTo: userId)
        .get();

    for (var doc in notificationsSnapshot.docs) {
      await doc.reference.delete();
    }

    // Delete user document
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .delete();
  }
}