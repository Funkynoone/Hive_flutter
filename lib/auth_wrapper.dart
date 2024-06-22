import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dashboard_screen.dart'; // Import the DashboardScreen
import 'login_screen.dart'; // Import the Login Screen

class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return CircularProgressIndicator();
        }
        if (!snapshot.hasData) {
          return LoginScreen(); // Navigate to login screen if not authenticated
        }
        final user = snapshot.data!;
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return CircularProgressIndicator();
            }
            if (!userSnapshot.hasData || userSnapshot.hasError) {
              return LoginScreen(); // Navigate to login screen on error or no data
            }
            final userData = userSnapshot.data!;
            final isBusinessOwner = userData['isBusinessOwner'] as bool;
            return DashboardScreen(); // Navigate to DashboardScreen for both roles
          },
        );
      },
    );
  }
}
