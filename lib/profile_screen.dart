import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  final VoidCallback onLogout;

  const ProfileScreen({Key? key, required this.onLogout}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Profile"),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: onLogout,
          child: Text("Log Out"),
        ),
      ),
    );
  }
}
