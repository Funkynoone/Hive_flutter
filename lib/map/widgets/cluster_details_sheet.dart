import 'package:flutter/material.dart';
import 'package:hive_flutter/models/job.dart';
import '../utils/job_marker_utils.dart';

class ClusterDetailsSheet extends StatelessWidget {
  final List<Job> jobs;
  final Function(Job) onJobSelected;

  const ClusterDetailsSheet({
    super.key,
    required this.jobs,
    required this.onJobSelected,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.4,
      minChildSize: 0.2,
      maxChildSize: 0.8,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                spreadRadius: 2,
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            children: [
              _buildDragHandle(),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: jobs.length,
                  itemBuilder: (context, index) => _buildJobTile(jobs[index]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildJobTile(Job job) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: JobMarkerUtils.getJobColor(job.category).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          JobMarkerUtils.getJobIcon(job.category),
          color: JobMarkerUtils.getJobColor(job.category),
        ),
      ),
      title: Text(
        job.title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(job.restaurant),
          Text(
            job.salaryNotGiven
                ? 'Salary not given'
                : '${job.salary} ${job.salaryType}',
            style: TextStyle(
              color: Colors.green[700],
              fontSize: 12,
            ),
          ),
        ],
      ),
      onTap: () => onJobSelected(job),
    );
  }
}