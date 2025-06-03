import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/models/job.dart';
import 'package:hive_flutter/models/job_filter_state.dart';
import 'job_card.dart';

class JobsScreen extends StatefulWidget {
  final JobFilterState? filterState;
  final List<Job>? initialJobs; // <--- ADDED THIS PARAMETER

  const JobsScreen({
    super.key,
    this.filterState,
    this.initialJobs, // <--- ADDED THIS TO THE CONSTRUCTOR
  });

  @override
  _JobsScreenState createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  // Removed _firestore here, as data will now come from initialJobs
  // final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _showFilters = false;

  // Internal list to hold jobs, either initial or filtered
  List<Job> _jobs = [];

  @override
  void initState() {
    super.initState();
    // Initialize _jobs with initialJobs provided
    _jobs = widget.initialJobs ?? [];
    _applyFilters(); // Apply filters initially if any are active

    // Listen to filter changes
    widget.filterState?.addListener(_onFiltersChanged);
  }

  @override
  void didUpdateWidget(covariant JobsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If initialJobs changes (e.g., parent fetches new data), update our internal list
    if (widget.initialJobs != oldWidget.initialJobs) {
      _jobs = widget.initialJobs ?? [];
      _applyFilters(); // Re-apply filters with new initial data
    }
    // If filterState changes, or its listener wasn't set up correctly before
    if (widget.filterState != oldWidget.filterState) {
      oldWidget.filterState?.removeListener(_onFiltersChanged);
      widget.filterState?.addListener(_onFiltersChanged);
    }
  }


  @override
  void dispose() {
    widget.filterState?.removeListener(_onFiltersChanged);
    super.dispose();
  }

  void _onFiltersChanged() {
    setState(() {
      _applyFilters(); // Re-apply filters when filter state changes
    });
  }

  void _toggleFilters() {
    setState(() {
      _showFilters = !_showFilters;
    });
  }

  // Moved filtering logic into a separate method
  void _applyFilters() {
    List<Job> tempJobs = widget.initialJobs ?? []; // Start with the raw initial jobs

    if (widget.filterState == null) {
      _jobs = tempJobs; // No filters, show all initial jobs
      return;
    }

    // Apply job spec filters
    final activeSpecs = widget.filterState!.activeJobSpecs;
    if (activeSpecs.isNotEmpty) {
      tempJobs = tempJobs.where((job) {
        return job.category.any((cat) => activeSpecs.contains(cat));
      }).toList();
    }

    // Apply contract type filters
    final activeTypes = widget.filterState!.activeContractTypes;
    if (activeTypes.isNotEmpty) {
      tempJobs = tempJobs.where((job) {
        return activeTypes.contains(job.type);
      }).toList();
    }

    _jobs = tempJobs; // Update the internal list with filtered results
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const SizedBox(), // Remove default back button
        title: const Text(
          'Jobs',
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
      ),
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
            // Main job list
            Container(
              color: Colors.grey[100],
              // StreamBuilder is no longer needed here as data comes from initialJobs
              // StreamBuilder<QuerySnapshot>(
              //   stream: _firestore.collection('JobListings').snapshots(), // Changed to JobListings
              //   builder: (context, snapshot) {
              //     if (snapshot.connectionState == ConnectionState.waiting) {
              //       return const Center(child: CircularProgressIndicator());
              //     }

              //     if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              //       return const Center(child: Text('No jobs available'));
              //     }

              //     List<Job> jobs = snapshot.data!.docs
              //         .map((doc) => Job.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
              //         .toList();

              //     // Apply filters if they exist
              //     if (widget.filterState != null) {
              //       jobs = _applyFilters(jobs);
              //     }

              //     if (jobs.isEmpty) {
              //       return const Center(
              //         child: Text('No jobs match your filters'),
              //       );
              //     }

              //     return ListView.builder(
              //       padding: const EdgeInsets.all(16),
              //       itemCount: jobs.length,
              //       itemBuilder: (context, index) {
              //         return Padding(
              //           padding: const EdgeInsets.only(bottom: 16),
              //           child: JobCard(job: jobs[index]),
              //         );
              //       },
              //     );
              //   },
              // ),
              child: _jobs.isEmpty
                  ? const Center(child: Text('No jobs match your filters or no jobs available.'))
                  : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _jobs.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: JobCard(job: _jobs[index]),
                  );
                },
              ),
            ),

            // Filter button
            Positioned(
              top: 16,
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
                          if (widget.filterState != null && widget.filterState!.activeFilterCount > 0)
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
                                  '${widget.filterState!.activeFilterCount}',
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

            // Filter panel
            if (_showFilters && widget.filterState != null)
              Positioned(
                top: 88,
                left: 16,
                right: MediaQuery.of(context).size.width * 0.3,
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
                              if (widget.filterState!.activeFilterCount > 0)
                                TextButton(
                                  onPressed: () {
                                    widget.filterState!.clearAll();
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
                          _buildJobFilterItem(Icons.room_service, 'Service', widget.filterState!.showService),
                          _buildJobFilterItem(Icons.manage_accounts, 'Manager', widget.filterState!.showManager),
                          _buildJobFilterItem(Icons.restaurant, 'Cook', widget.filterState!.showCook),
                          _buildJobFilterItem(Icons.cleaning_services, 'Cleaning', widget.filterState!.showCleaning),
                          _buildJobFilterItem(Icons.delivery_dining, 'Delivery', widget.filterState!.showDelivery),
                          _buildJobFilterItem(Icons.local_bar, 'Bar', widget.filterState!.showBar),
                          _buildJobFilterItem(Icons.wine_bar, 'Sommelier', widget.filterState!.showSommelier),

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
                          _buildContractFilterItem(Icons.work, 'Full Time', widget.filterState!.showFullTime),
                          _buildContractFilterItem(Icons.work_outline, 'Part Time', widget.filterState!.showPartTime),
                          _buildContractFilterItem(Icons.date_range, 'Season', widget.filterState!.showSeason),
                        ],
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

  // This method is now internal to JobsScreen and updates _jobs
  // List<Job> _applyFilters(List<Job> jobs) { // Old signature
  //   ...
  // }

  Widget _buildJobFilterItem(IconData icon, String label, bool isSelected) {
    return InkWell(
      onTap: () => widget.filterState!.toggleJobSpec(label),
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
      onTap: () => widget.filterState!.toggleContractType(label),
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