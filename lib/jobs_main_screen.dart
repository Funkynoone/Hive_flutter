import 'package:flutter/material.dart';
import 'package:hive_flutter/jobs_screen.dart';
import 'package:hive_flutter/map_filter_screen.dart';
import 'package:hive_flutter/models/job_filter_state.dart';
import 'package:hive_flutter/widgets/filter_bottom_sheet.dart';

class JobsMainScreen extends StatefulWidget {
  const JobsMainScreen({super.key});

  @override
  _JobsMainScreenState createState() => _JobsMainScreenState();
}

class _JobsMainScreenState extends State<JobsMainScreen> {
  bool _isMapView = true; // Map is now the default view
  final JobFilterState _filterState = JobFilterState();
  final DraggableScrollableController _filterSheetController = DraggableScrollableController();

  void _toggleView() {
    setState(() {
      _isMapView = !_isMapView;
    });
  }

  @override
  void dispose() {
    _filterState.dispose();
    _filterSheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Main content - either map or list view
          if (_isMapView)
            MapFilterScreen(filterState: _filterState)
          else
            JobsScreen(filterState: _filterState),

          // Filter bottom sheet - only visible in map view
          if (_isMapView)
            FilterBottomSheet(
              filterState: _filterState,
              controller: _filterSheetController,
            ),

          // Floating button in top right - circular with icon only
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            right: 16,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: _toggleView,
                  customBorder: const CircleBorder(),
                  child: Center(
                    child: Icon(
                      _isMapView ? Icons.view_list : Icons.map,
                      color: Colors.blue,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}