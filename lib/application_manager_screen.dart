import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/models/application.dart';
import 'package:hive_flutter/models/job.dart';

class ApplicationManagerScreen extends StatefulWidget {
  final String ownerId;

  const ApplicationManagerScreen({super.key, required this.ownerId});

  @override
  _ApplicationManagerScreenState createState() => _ApplicationManagerScreenState();
}

class _ApplicationManagerScreenState extends State<ApplicationManagerScreen> {
  List<Job> _jobs = [];
  Map<String, List<Application>> _applications = {};

  @override
  void initState() {
    super.initState();
    _fetchJobs();
  }

  void _fetchJobs() async {
    QuerySnapshot jobSnapshot = await FirebaseFirestore.instance
        .collection('JobListings')
        .where('ownerId', isEqualTo: widget.ownerId)
        .get();

    List<Job> jobs = jobSnapshot.docs.map((doc) {
      return Job.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
    }).toList();

    setState(() {
      _jobs = jobs;
    });

    _fetchApplications();
  }

  void _fetchApplications() async {
    for (var job in _jobs) {
      QuerySnapshot applicationSnapshot = await FirebaseFirestore.instance
          .collection('JobListings')
          .doc(job.id)
          .collection('Applications')
          .get();

      List<Application> applications = applicationSnapshot.docs.map((doc) {
        return Application.fromFirestore(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();

      setState(() {
        _applications[job.id] = applications;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Application Manager'),
      ),
      body: ListView.builder(
        itemCount: _jobs.length,
        itemBuilder: (context, index) {
          final job = _jobs[index];
          final jobApplications = _applications[job.id] ?? [];

          return ExpansionTile(
            title: Text(job.title),
            subtitle: Text(job.restaurant),
            children: jobApplications.map((application) {
              return ListTile(
                title: Text(application.name),
                subtitle: Text(application.message),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.check),
                      onPressed: () {
                        _markAsReviewed(application, job.id);
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () {
                        _rejectApplication(application, job.id);
                      },
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  void _markAsReviewed(Application application, String jobId) {
    // Update application status in Firestore
    FirebaseFirestore.instance
        .collection('JobListings')
        .doc(jobId)
        .collection('Applications')
        .doc(application.id)
        .update({'status': 'reviewed'});
  }

  void _rejectApplication(Application application, String jobId) {
    // Update application status in Firestore
    FirebaseFirestore.instance
        .collection('JobListings')
        .doc(jobId)
        .collection('Applications')
        .doc(application.id)
        .update({'status': 'rejected'});
  }
}
