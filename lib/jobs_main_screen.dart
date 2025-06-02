import 'package:flutter/material.dart';
import 'package:hive_flutter/jobs_screen.dart';
import 'package:hive_flutter/map_filter_screen.dart';

class JobsMainScreen extends StatefulWidget {
  const JobsMainScreen({super.key});

  @override
  _JobsMainScreenState createState() => _JobsMainScreenState();
}

class _JobsMainScreenState extends State<JobsMainScreen> {
  bool _isMapView = true; // Map is now the default view

  void _toggleView() {
    setState(() {
      _isMapView = !_isMapView;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Main content - either map or list view
          if (_isMapView)
            const MapFilterScreen()
          else
            const JobsScreen(),

          // Floating button in top right
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
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
                child: InkWell(
                  onTap: _toggleView,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isMapView ? Icons.view_list : Icons.map,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isMapView ? 'List' : 'Map',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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