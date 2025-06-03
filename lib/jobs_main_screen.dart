import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:hive_flutter/jobs_screen.dart';
import 'package:hive_flutter/map_filter_screen.dart';
import 'package:hive_flutter/models/job_filter_state.dart';
import 'package:hive_flutter/models/job.dart'; // Import your Job model

class JobsMainScreen extends StatefulWidget {
  const JobsMainScreen({super.key});

  @override
  _JobsMainScreenState createState() => _JobsMainScreenState();
}

class _JobsMainScreenState extends State<JobsMainScreen> {
  bool _isMapView = true; // Map is now the default view
  bool _showFilters = false;
  final JobFilterState _filterState = JobFilterState();
  late Future<List<Job>> _jobsFuture; // Future to hold fetched jobs

  @override
  void initState() {
    super.initState();
    // Initialize the future to fetch jobs when the screen starts
    _jobsFuture = _fetchJobsFromFirestore();

    // Listen to filter changes
    _filterState.addListener(() {
      setState(() {
        // This will rebuild the UI when filters change,
        // which will cause MapFilterScreen and JobsScreen to re-evaluate their filters
      });
    });
  }

  // New method to fetch jobs from Firestore
  Future<List<Job>> _fetchJobsFromFirestore() async {
    try {
      print('JobsMainScreen: Starting to fetch jobs from Firestore...');
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('JobListings') // Use 'JobListings' as confirmed
          .get();

      final List<Job> jobs = snapshot.docs
          .map((doc) => Job.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      print('JobsMainScreen: Successfully fetched ${jobs.length} jobs from Firestore.');
      return jobs;
    } catch (e) {
      print('JobsMainScreen: Error fetching jobs: $e');
      // Return an empty list on error to prevent app crash
      return [];
    }
  }

  @override
  void dispose() {
    _filterState.removeListener(() {}); // Remove listener before disposing
    _filterState.dispose(); // Dispose the ChangeNotifier
    super.dispose();
  }

  void _toggleView() {
    setState(() {
      _isMapView = !_isMapView;
      _showFilters = false; // Close filters when switching views
    });
  }

  void _toggleFilters() {
    setState(() {
      _showFilters = !_showFilters;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () {
          if (_showFilters) {
            setState(() {
              _showFilters = false;
            });
          }
        },
        child: Stack(
          children: [
            // Use FutureBuilder to wait for jobs to load
            FutureBuilder<List<Job>>(
              future: _jobsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  print('JobsMainScreen: FutureBuilder error: ${snapshot.error}');
                  return Center(child: Text('Error loading jobs: ${snapshot.error}'));
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  print('JobsMainScreen: No job data found in snapshot.');
                  return const Center(child: Text('No job listings available.'));
                } else {
                  // Data is available, pass it to both screens
                  final List<Job> availableJobs = snapshot.data!;
                  print('JobsMainScreen: Rendering view with ${availableJobs.length} jobs.');
                  return _isMapView
                      ? MapFilterScreen(
                    initialJobs: availableJobs, // Pass the fetched jobs here
                    filterState: _filterState,
                  )
                      : JobsScreen(
                    initialJobs: availableJobs, // Also pass to JobsScreen if it needs it
                    filterState: _filterState,
                  );
                }
              },
            ),

            // Filter button in top left - only visible in map view
            if (_isMapView)
              Positioned(
                top: MediaQuery.of(context).padding.top + 60,
                left: 16,
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
                      onTap: _toggleFilters,
                      customBorder: const CircleBorder(),
                      child: Center(
                        child: Stack(
                          children: [
                            Icon(
                              Icons.filter_list,
                              color: _showFilters ? Colors.blue : Colors.grey[700],
                              size: 24,
                            ),
                            if (_filterState.activeFilterCount > 0)
                              Positioned(
                                right: -2,
                                top: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    '${_filterState.activeFilterCount}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Filter panel - transparent dropdown style
            if (_isMapView && _showFilters)
              Positioned(
                top: MediaQuery.of(context).padding.top + 130,
                left: 16,
                right: MediaQuery.of(context).size.width * 0.3, // Takes 70% of width
                child: GestureDetector(
                  onTap: () {}, // Prevent closing when tapping inside
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Filters',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_filterState.activeFilterCount > 0)
                                TextButton(
                                  onPressed: () {
                                    _filterState.clearAll();
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(50, 30),
                                  ),
                                  child: const Text(
                                    'Clear',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Job Specifications
                          const Text(
                            'Job Type',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildJobFilterItem(Icons.room_service, 'Service', _filterState.showService),
                          _buildJobFilterItem(Icons.manage_accounts, 'Manager', _filterState.showManager),
                          _buildJobFilterItem(Icons.restaurant, 'Cook', _filterState.showCook),
                          _buildJobFilterItem(Icons.cleaning_services, 'Cleaning', _filterState.showCleaning),
                          _buildJobFilterItem(Icons.delivery_dining, 'Delivery', _filterState.showDelivery),
                          _buildJobFilterItem(Icons.local_bar, 'Bar', _filterState.showBar),
                          _buildJobFilterItem(Icons.wine_bar, 'Sommelier', _filterState.showSommelier),

                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 16),

                          // Contract Time
                          const Text(
                            'Contract Time',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildContractFilterItem(Icons.work, 'Full Time', _filterState.showFullTime),
                          _buildContractFilterItem(Icons.work_outline, 'Part Time', _filterState.showPartTime),
                          _buildContractFilterItem(Icons.date_range, 'Season', _filterState.showSeason),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // View toggle button in top right - circular with icon only
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
      ),
    );
  }

  Widget _buildJobFilterItem(IconData icon, String label, bool isSelected) {
    return InkWell(
      onTap: () => _filterState.toggleJobSpec(label),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.blue : Colors.grey[600],
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isSelected ? Colors.blue : Colors.grey[800],
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(
                Icons.check,
                size: 18,
                color: Colors.blue,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContractFilterItem(IconData icon, String label, bool isSelected) {
    return InkWell(
      onTap: () => _filterState.toggleContractType(label),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.green : Colors.grey[600],
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isSelected ? Colors.green : Colors.grey[800],
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(
                Icons.check,
                size: 18,
                color: Colors.green,
              ),
          ],
        ),
      ),
    );
  }
}