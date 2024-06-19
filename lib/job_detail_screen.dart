import 'package:flutter/material.dart';
import 'package:hive_flutter/models/job.dart'; // Adjust the path as needed

class JobDetailScreen extends StatelessWidget {
  final Job job;

  const JobDetailScreen({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(job.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              job.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${job.restaurant} - ${job.type} - ${job.category}',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Text(
              job.description ?? 'No description available',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Implement sending CV functionality
              },
              child: const Text('Send CV'),
            ),
            ElevatedButton(
              onPressed: () {
                // Implement sending message functionality
              },
              child: const Text('Send Message'),
            ),
          ],
        ),
      ),
    );
  }
}
