import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'editpersonalinfo_screen.dart';


class ProfileScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const ProfileScreen({super.key, required this.onLogout});
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? user = FirebaseAuth.instance.currentUser;
  FirebaseFirestore firestore = FirebaseFirestore.instance;

  late String _userName;
  late String _userEmail;
  late String _userPhone;
  ImageProvider? _profileImage = const AssetImage('assets/profileimage.png'); // Update to use your asset

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    if (user != null) {
      var userData = await firestore.collection('users').doc(user!.uid).get();
      setState(() {
        _userName = userData.data()?['username'] ?? 'No Name';
        _userEmail = userData.data()?['email'] ?? 'No Email';
        _userPhone = userData.data()?['phone'] ?? 'No Phone';
      });
    }
  }

  Future<void> _changeProfilePicture() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _profileImage = FileImage(File(pickedFile.path));
      });
      // Here, upload the selected image to Firebase Storage and update the user profile accordingly
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundImage: _profileImage,
              ),
              ElevatedButton(
                onPressed: _changeProfilePicture,
                child: const Text('Change Picture'),
              ),
              Text(_userName),
              Text(_userEmail),
              Text(_userPhone),
              ElevatedButton(
                onPressed: () {
                  // Navigate to Edit Personal Info Screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const EditPersonalInfoScreen()),
                  );
                },
                child: const Text('Edit Personal Info'),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  return const Icon(Icons.star, color: Colors.amber);
                }),
              ),
              ElevatedButton(
                onPressed: () {
                  FirebaseAuth.instance.signOut();
                  Navigator.pushReplacementNamed(context, '/login');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: const Text('Log Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
