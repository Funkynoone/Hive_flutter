import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(  // Add Scaffold here
      body: Center(  // Center widget for better layout
        child: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            // Handle authentication stream errors
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Authentication Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }

            // Show loading while checking auth state
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            // Not authenticated
            if (!snapshot.hasData) {
              return const LoginScreen();
            }

            // User is authenticated, get Firestore data
            final user = snapshot.data!;
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
              builder: (context, userSnapshot) {
                // Show loading while fetching user data
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                // Handle Firestore errors
                if (userSnapshot.hasError) {
                  return Center(
                    child: Text(
                      'Database Error: ${userSnapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                // Handle missing user data
                if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                  return const Center(
                    child: Text(
                      'User data not found',
                      style: TextStyle(color: Colors.red),
                    ),
                  );
                }

                // Successfully got user data
                try {
                  final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                  final isBusinessOwner = userData['isBusinessOwner'] as bool? ?? false;

                  return const DashboardScreen();
                } catch (e) {
                  return Center(
                    child: Text(
                      'Data Error: $e',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }
              },
            );
          },
        ),
      ),
    );
  }
}