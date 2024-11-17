import 'package:flutter/material.dart';
import 'package:hive_flutter/models/job.dart';
import '../utils/job_marker_utils.dart';
import '../services/job_application_service.dart';

class JobDetailsSheet extends StatelessWidget {
  final Job job;
  final bool isFullDetails;
  final bool isUploading;
  final bool isSending;
  final Function(DragEndDetails) onVerticalDragEnd;
  final Function(bool) setUploading;
  final Function(bool) setSending;
  final double animationValue;

  const JobDetailsSheet({
    Key? key,
    required this.job,
    required this.isFullDetails,
    required this.isUploading,
    required this.isSending,
    required this.onVerticalDragEnd,
    required this.setUploading,
    required this.setSending,
    required this.animationValue,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragEnd: onVerticalDragEnd,
      child: Container(
        height: isFullDetails
            ? MediaQuery.of(context).size.height * 0.8
            : 140 * animationValue,
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
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDragHandle(),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 12),
                    _buildTags(),
                    const SizedBox(height: 12),
                    if (!isFullDetails)
                      _buildCollapsedContent(context)
                    else
                      _buildExpandedContent(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: JobMarkerUtils.getJobColor(job.category).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            JobMarkerUtils.getJobIcon(job.category),
            color: JobMarkerUtils.getJobColor(job.category),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                job.restaurant,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                job.title,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTags() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildTag(
          icon: Icons.work_outline,
          text: job.type,
          color: Colors.blue,
        ),
        _buildTag(
          icon: Icons.euro,
          text: job.salaryNotGiven
              ? 'Not Given'
              : '${job.salary} ${job.salaryType}',
          color: Colors.green,
        ),
      ],
    );
  }

  Widget _buildTag({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),  // Changed from shade50
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),  // Changed from shade100
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),  // Changed from shade700
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,  // Changed from shade700
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsedContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          job.description.length > 100
              ? '${job.description.substring(0, 100)}...'
              : job.description,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Swipe up for more details',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[400],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        _buildSection('Job Description', job.description),
        const SizedBox(height: 24),
        _buildSection('Requirements', job.requirements),
        const SizedBox(height: 24),
        _buildButtons(context),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton.icon(
          onPressed: isUploading
              ? null
              : () => JobApplicationService.uploadCV(job, context, setUploading),
          icon: const Icon(Icons.upload_file),
          label: Text(isUploading ? 'Uploading...' : 'Upload CV'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        ElevatedButton.icon(
          onPressed: isSending
              ? null
              : () => JobApplicationService.showMessageDialog(
            context,
            job,
            setSending,
          ),
          icon: const Icon(Icons.message),
          label: Text(isSending ? 'Sending...' : 'Send Message'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }
}