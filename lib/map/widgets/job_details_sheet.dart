import 'package:flutter/material.dart';
import 'package:hive_flutter/models/job.dart';
import '../utils/job_marker_utils.dart';
import '../services/job_application_service.dart';

class JobDetailsSheet extends StatefulWidget {
  final Job job;
  final Function(bool) setUploading;
  final Function(bool) setSending;

  const JobDetailsSheet({
    Key? key,
    required this.job,
    required this.setUploading,
    required this.setSending,
  }) : super(key: key);

  @override
  State<JobDetailsSheet> createState() => _JobDetailsSheetState();
}

class _JobDetailsSheetState extends State<JobDetailsSheet> {
  final DraggableScrollableController _controller = DraggableScrollableController();
  bool _isExpanded = false;
  bool _isUploading = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onDragUpdate);
  }

  @override
  void dispose() {
    _controller.removeListener(_onDragUpdate);
    _controller.dispose();
    super.dispose();
  }

  void _onDragUpdate() {
    setState(() {
      _isExpanded = _controller.size > 0.6;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.3,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      snap: true,
      snapSizes: const [0.3, 0.9],
      controller: _controller,
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
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
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
                      const SizedBox(height: 16),
                      if (_isExpanded) ...[
                        _buildFullDescription(),
                        const SizedBox(height: 16),
                        _buildButtons(context),
                      ] else ...[
                        _buildCompactDescription(),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Drag up for more details',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[400],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
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

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: JobMarkerUtils.getJobColor(widget.job.category).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            JobMarkerUtils.getJobIcon(widget.job.category),
            color: JobMarkerUtils.getJobColor(widget.job.category),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.job.restaurant,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.job.title,
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
          Icons.work_outline,
          widget.job.type,
          Colors.blue,
        ),
        _buildTag(
          Icons.euro,
          widget.job.salaryNotGiven
              ? 'Not Given'
              : '${widget.job.salary} ${widget.job.salaryType}',
          Colors.green,
        ),
      ],
    );
  }

  Widget _buildTag(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.job.description,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildFullDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Description',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.job.description,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Requirements',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.job.requirements,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isUploading
                ? null
                : () async {
              setState(() => _isUploading = true);
              widget.setUploading(true);
              await JobApplicationService.uploadCV(
                widget.job,
                context,
                    (value) {
                  setState(() => _isUploading = value);
                  widget.setUploading(value);
                },
              );
            },
            icon: const Icon(Icons.upload_file),
            label: Text(_isUploading ? 'Uploading...' : 'Upload CV'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isSending
                ? null
                : () {
              JobApplicationService.showMessageDialog(
                context,
                widget.job,
                    (value) {
                  setState(() => _isSending = value);
                  widget.setSending(value);
                },
              );
            },
            icon: const Icon(Icons.message),
            label: Text(_isSending ? 'Sending...' : 'Contact Owner'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}