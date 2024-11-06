import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DeleteAccountButton extends StatelessWidget {
  const DeleteAccountButton({Key? key}) : super(key: key);

  // Add this build method which was missing
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
                        '• Messages and chat rooms\n'
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

  Future<void> _deleteAccount(BuildContext context) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(child: CircularProgressIndicator());
        },
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (context.mounted) {
          Navigator.of(context).pop();
        }
        return;
      }

      // Store the user ID before deletion
      final userId = user.uid;

      try {
        // 1. Delete Firestore data first
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('savedJobs')
            .get()
            .then((snapshot) {
          for (var doc in snapshot.docs) {
            doc.reference.delete();
          }
        });

        await FirebaseFirestore.instance
            .collection('notifications')
            .where('senderId', isEqualTo: userId)
            .get()
            .then((snapshot) {
          for (var doc in snapshot.docs) {
            doc.reference.delete();
          }
        });

        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .delete();

        // 2. Delete auth user
        await user.delete();

        // 3. Only navigate after everything is complete
        if (context.mounted) {
          Navigator.of(context).pop(); // Dismiss loading
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        }
      } catch (e) {
        print('Error deleting data: $e');
        // If there's an error, try to sign out anyway
        try {
          await FirebaseAuth.instance.signOut();
        } catch (e) {
          print('Error signing out: $e');
        }

        if (context.mounted) {
          Navigator.of(context).pop(); // Dismiss loading
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        }
      }
    } catch (e) {
      print('Error in delete account: $e');
      if (context.mounted) {
        Navigator.of(context).pop(); // Dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete account: ${e.toString()}')),
        );
      }
    }
  }
}