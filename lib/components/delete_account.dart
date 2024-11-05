// In your lib/screens/profile_screen.dart or wherever your profile screen is

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DeleteAccountButton extends StatelessWidget {
  const DeleteAccountButton({Key? key}) : super(key: key);

  Future<void> _deleteAccount(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // Create a batch to handle multiple deletions
      final batch = FirebaseFirestore.instance.batch();

      // Delete saved jobs
      final savedJobsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('savedJobs')
          .get();

      for (var doc in savedJobsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete applications
      final applicationsQuery = await FirebaseFirestore.instance
          .collectionGroup('Applications')
          .where('userId', isEqualTo: user.uid)
          .get();

      for (var doc in applicationsQuery.docs) {
        batch.delete(doc.reference);
      }

      // Delete notifications
      final notificationsSnapshot = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .get();

      for (var doc in notificationsSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete user document
      batch.delete(FirebaseFirestore.instance.collection('users').doc(user.uid));

      // Commit the batch
      await batch.commit();

      // Delete the user authentication
      await user.delete();

      // Navigate to login screen
      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed('/login'); // Adjust route name as needed
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete account: ${e.toString()}')),
        );
      }
    }
  }

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
        onPressed: () {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Delete Account'),
                content: const Text(
                    'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently deleted, including:\n\n'
                        '• Your profile information\n'
                        '• Saved jobs\n'
                        '• Job applications\n'
                        '• Notifications'
                ),
                actions: [
                  TextButton(
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  TextButton(
                    child: const Text(
                      'Delete',
                      style: TextStyle(color: Colors.red),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _deleteAccount(context);
                    },
                  ),
                ],
              );
            },
          );
        },
        child: const Text('Delete Account'),
      ),
    );
  }
}