import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dashboard_screen.dart';
import 'register_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(hintText: 'Username/Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(hintText: 'Password'),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _login,
                child: const Text('Login'),
              ),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen())),
                child: Text("Don't have an account? Register", style: TextStyle(color: Theme.of(context).primaryColor)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _login() async {
    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (userCredential.user != null) {
        // Fetch the user's role from Firestore
        final docSnapshot = await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).get();
        final isBusinessOwner = docSnapshot.data()?['isBusinessOwner'] ?? false;

        // Store the role in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isBusinessOwner', isBusinessOwner);

        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const DashboardScreen())); // Navigate to Dashboard
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Authentication failed: ${e.toString()}")));
    }
  }
}
