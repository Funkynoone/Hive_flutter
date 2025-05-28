import 'package:flutter/material.dart';
import 'package:hive_flutter/models/job.dart';
import 'dart:math' show pi, cos, sin;
import '../utils/job_marker_utils.dart';

class RadialJobMenu extends StatefulWidget {
  final List<Job> jobs;
  final Function(Job) onJobSelected;
  final VoidCallback onDismiss;
  final Offset center;

  const RadialJobMenu({
    super.key,
    required this.jobs,
    required this.onJobSelected,
    required this.onDismiss,
    required this.center,
  });

  @override
  State<RadialJobMenu> createState() => _RadialJobMenuState();
}

class _RadialJobMenuState extends State<RadialJobMenu> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<double>> _animations;
  bool _isDisposed = false;
  bool _isMenuActive = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _setupAnimations();
    _controller.forward();
  }

  void _setupAnimations() {
    final count = widget.jobs.length;
    _animations = List.generate(count, (index) {
      return CurvedAnimation(
        parent: _controller,
        curve: Interval(
          index / count,
          (index + 1) / count,
          curve: Curves.easeOutCubic,
        ),
      );
    });
  }

  void _handleJobTap(Job job) {
    if (!_isMenuActive) return;

    setState(() => _isMenuActive = false);
    _controller.reverse().then((_) {
      if (!_isDisposed) widget.onJobSelected(job);
    });
  }

  @override
  void didUpdateWidget(RadialJobMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.jobs.length != widget.jobs.length) {
      _setupAnimations();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) {
        if (_isMenuActive) {
          _controller.reverse().then((_) {
            if (!_isDisposed) widget.onDismiss();
          });
        }
      },
      child: Container(
        color: Colors.transparent,
        child: Stack(
          children: List.generate(widget.jobs.length, (index) {
            final job = widget.jobs[index];
            final angle = (2 * pi * index) / widget.jobs.length - (pi / 2);
            const radius = 80.0;

            return AnimatedBuilder(
              animation: _animations[index],
              builder: (context, child) {
                final progress = _animations[index].value;
                final x = widget.center.dx + radius * cos(angle) * progress;
                final y = widget.center.dy + radius * sin(angle) * progress;

                return Positioned(
                  left: x - 20,
                  top: y - 20,
                  child: GestureDetector(
                    onTap: () => _handleJobTap(job),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: JobMarkerUtils.getJobColor(job.category),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            spreadRadius: 2,
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Tooltip(
                        message: job.title,
                        child: Icon(
                          JobMarkerUtils.getJobIcon(job.category),
                          color: JobMarkerUtils.getJobColor(job.category),
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }
}