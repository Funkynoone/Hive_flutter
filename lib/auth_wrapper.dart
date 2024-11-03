import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, authSnapshot) {
          if (authSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // If not authenticated, show login screen
          if (!authSnapshot.hasData) {
            return const LoginScreen();
          }

          // User is authenticated, get Firestore data
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(authSnapshot.data!.uid)
                .snapshots(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // Check if document exists and has data
              if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                // If no data, log out and return to login screen
                FirebaseAuth.instance.signOut();
                return const LoginScreen();
              }

              // Successfully got user data, show dashboard
              return const DashboardScreen();
            },
          );
        },
      ),
    );
  }
}