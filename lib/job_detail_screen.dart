import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/models/job.dart';
import 'package:firebase_auth/firebase_auth.dart';

class JobDetailScreen extends StatefulWidget {
  final Job job;

  const JobDetailScreen({super.key, required this.job});

  @override
  _JobDetailScreenState createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  bool isSaved = false;

  @override
  void initState() {
    super.initState();
    _checkIfSaved();
  }

  void _checkIfSaved() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final savedJobsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('savedJobs')
          .doc(widget.job.id)
          .get();
      setState(() {
        isSaved = savedJobsSnapshot.exists;
      });
    }
  }

  void _toggleSaveJob() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userSavedJobsRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('savedJobs')
          .doc(widget.job.id);

      if (isSaved) {
        await userSavedJobsRef.delete();
      } else {
        await userSavedJobsRef.set({
          'title': widget.job.title,
          'restaurant': widget.job.restaurant,
          'type': widget.job.type,
          'description': widget.job.description,
          'latitude': widget.job.latitude,
          'longitude': widget.job.longitude,
          'category': widget.job.category,
          'imageUrl': widget.job.imageUrl,
        });
      }

      setState(() {
        isSaved = !isSaved;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.job.title),
        actions: [
          IconButton(
            icon: Icon(isSaved ? Icons.favorite : Icons.favorite_border),
            color: isSaved ? Colors.red : Colors.white,
            onPressed: _toggleSaveJob,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.job.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.job.restaurant} - ${widget.job.type} - ${widget.job.category.join(', ')}',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Text(
              widget.job.description,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
