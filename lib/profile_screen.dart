import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'editpersonalinfo_screen.dart';
import 'package:hive_flutter/components/delete_account.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const ProfileScreen({super.key, required this.onLogout});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? user = FirebaseAuth.instance.currentUser;
  FirebaseFirestore firestore = FirebaseFirestore.instance;

  // Make these nullable and provide default values
  String? _userName;
  String? _userEmail;
  String? _userPhone;
  ImageProvider? _profileImage = const AssetImage('assets/profileimage.png');
  bool _isLoading = true; // Add loading state

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      if (user != null) {
        var userData = await firestore.collection('users').doc(user!.uid).get();
        if (mounted) {
          setState(() {
            _userName = userData.data()?['username'] ?? 'No Name';
            _userEmail = userData.data()?['email'] ?? 'No Email';
            _userPhone = userData.data()?['phone'] ?? 'No Phone';
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _userName = 'No Name';
            _userEmail = 'No Email';
            _userPhone = 'No Phone';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error fetching user data: $e');
      if (mounted) {
        setState(() {
          _userName = 'Error loading name';
          _userEmail = 'Error loading email';
          _userPhone = 'Error loading phone';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _changeProfilePicture() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _profileImage = FileImage(File(pickedFile.path));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              CircleAvatar(
                radius: 50,
                backgroundImage: _profileImage,
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _changeProfilePicture,
                child: const Text('Change Picture'),
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        _userName ?? 'Loading...',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _userEmail ?? 'Loading...',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _userPhone ?? 'Loading...',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const EditPersonalInfoScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: const Text('Edit Personal Info'),
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return const Icon(Icons.star, color: Colors.amber);
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await FirebaseAuth.instance.signOut();
                    if (mounted) {
                      widget.onLogout();
                    }
                  } catch (e) {
                    print("Error during logout: $e");
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error logging out: $e')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  minimumSize: const Size.fromHeight(50),
                ),
                child: const Text('Log Out'),
              ),
              const SizedBox(height: 20),
              const DeleteAccountButton(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}