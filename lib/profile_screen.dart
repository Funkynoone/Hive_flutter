import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const ProfileScreen({Key? key, required this.onLogout}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  late String _userName = '';
  late String _userEmail = '';
  late String _userPhone = '';
  ImageProvider _profileImage = AssetImage('assets/profileimage.png'); // Assuming this is your placeholder image

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
      // Here, you should upload the selected image to Firebase Storage and then update the Firestore user document with the new image URL.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Profile"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 20),
            CircleAvatar(
              radius: 60,
              backgroundImage: _profileImage,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _changeProfilePicture,
              child: Text("Change Picture"),
            ),
            SizedBox(height: 20),
            Text("Name: $_userName", style: Theme.of(context).textTheme.headline6),
            SizedBox(height: 10),
            Text("Email: $_userEmail", style: Theme.of(context).textTheme.bodyText1),
            SizedBox(height: 10),
            Text("Phone: $_userPhone", style: Theme.of(context).textTheme.bodyText1),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: widget.onLogout,
              child: Text("Log Out"),
              style: ElevatedButton.styleFrom(
                primary: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
