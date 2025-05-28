import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/models/job.dart';
import 'job_card.dart';
import 'map_filter_screen.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  _JobsScreenState createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  bool showFullTime = false;
  bool showPartTime = false;
  bool showSeason = false;
  bool showService = false;
  bool showManager = false;
  bool showBar = false;
  bool showDelivery = false;
  bool showSommelier = false;
  bool showCleaning = false;
  bool showCook = false;
  String? selectedRegion;
  List<Job> _jobs = [];

  final List<String> regions = [
    'Attica', 'Sterea Ellada', 'Peloponnisus', 'Epirus', 'Thessalia',
    'Thraki', 'Ionian islands', 'Aegean islands', 'Creta'
  ];

  @override
  void initState() {
    super.initState();
    _searchJobs(); // Load jobs initially
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: TextButton(
          onPressed: () async {
            final jobs = await _fetchAllJobs(); // Fetch all jobs for map
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MapFilterScreen(initialJobs: jobs),
                ),
              );
            }
          },
          style: TextButton.styleFrom(
            backgroundColor: const Color(0xFFF4A261),
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 24.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18.0),
            ),
          ),
          child: const Text(
            'MAP',
            style: TextStyle(color: Colors.black),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Job Specifications',
                style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold)
            ),
            Wrap(
              spacing: 8.0,
              children: [
                filterChip('Service', showService),
                filterChip('Manager', showManager),
                filterChip('Cook', showCook),
                filterChip('Cleaning', showCleaning),
                filterChip('Delivery', showDelivery),
                filterChip('Bar', showBar),
                filterChip('Sommelier', showSommelier),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Contract Time',
                style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold)
            ),
            Wrap(
              spacing: 8.0,
              children: [
                filterChip('Full Time', showFullTime),
                filterChip('Part Time', showPartTime),
                filterChip('Season', showSeason),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Region Filter',
                style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold)
            ),
            DropdownButton<String>(
              isExpanded: true,
              value: selectedRegion,
              hint: const Text('Select Region'),
              onChanged: (String? newValue) {
                setState(() {
                  selectedRegion = newValue;
                });
              },
              items: regions.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _searchJobs,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      minimumSize: const Size(double.infinity, 36),
                    ),
                    child: const Text('SEARCH'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _clearFilters,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white54,
                      minimumSize: const Size(double.infinity, 36),
                    ),
                    child: const Text('CLEAR FILTERS'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _jobs.isNotEmpty
                ? ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _jobs.length,
              itemBuilder: (context, index) {
                final job = _jobs[index];
                return JobCard(job: job);
              },
            )
                : const Center(child: Text("No jobs found")),
          ],
        ),
      ),
    );
  }

  Future<List<Job>> _fetchAllJobs() async {
    print("Fetching jobs for map...");
    final QuerySnapshot querySnapshot = await FirebaseFirestore.instance
        .collection('JobListings')
        .get();

    final jobs = querySnapshot.docs
        .map((doc) => Job.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
        .toList();

    print("Total jobs fetched for map: ${jobs.length}");
    // Print each job's location to verify uniqueness
    for (var job in jobs) {
      print("${job.id}: ${job.latitude}, ${job.longitude}");
    }

    return jobs;
  }

  void _clearFilters() {
    setState(() {
      showFullTime = false;
      showPartTime = false;
      showSeason = false;
      showService = false;
      showManager = false;
      showBar = false;
      showDelivery = false;
      showSommelier = false;
      showCleaning = false;
      showCook = false;
      selectedRegion = null;
    });
    _searchJobs(); // Refresh jobs after clearing filters
  }

  void _searchJobs() async {
    Query query = FirebaseFirestore.instance.collection('JobListings');

    List<String> titleFilters = [];
    List<String> typeFilters = [];

    // Build filters
    if (showService) titleFilters.add('Service');
    if (showManager) titleFilters.add('Manager');
    if (showBar) titleFilters.add('Bar');
    if (showDelivery) titleFilters.add('Delivery');
    if (showSommelier) titleFilters.add('Sommelier');
    if (showCleaning) titleFilters.add('Cleaning');
    if (showCook) titleFilters.add('Cook');

    if (showFullTime) typeFilters.add('Full Time');
    if (showPartTime) typeFilters.add('Part Time');
    if (showSeason) typeFilters.add('Season');

    // Apply filters
    if (selectedRegion != null) {
      query = query.where('region', isEqualTo: selectedRegion);
    }

    if (titleFilters.isNotEmpty) {
      query = query.where('category', arrayContainsAny: titleFilters);
    }

    // Execute query
    final QuerySnapshot querySnapshot = await query.get();
    List<Job> jobs = querySnapshot.docs
        .map((doc) => Job.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
        .toList();

    // Apply type filters in memory
    if (typeFilters.isNotEmpty) {
      jobs = jobs.where((job) => typeFilters.contains(job.type)).toList();
    }

    // Debug logs
    debugPrint('===== JOBS SEARCH RESULTS =====');
    debugPrint('Total jobs found: ${jobs.length}');
    for (var job in jobs) {
      debugPrint('Job: ${job.restaurant} - ${job.title}');
      debugPrint('Location: ${job.latitude}, ${job.longitude}');
    }
    debugPrint('=============================');

    setState(() => _jobs = jobs);
  }

  Widget filterChip(String label, bool isSelected) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool value) {
        setState(() {
          switch (label) {
            case 'Service':
              showService = value;
              break;
            case 'Manager':
              showManager = value;
              break;
            case 'Cook':
              showCook = value;
              break;
            case 'Cleaning':
              showCleaning = value;
              break;
            case 'Delivery':
              showDelivery = value;
              break;
            case 'Bar':
              showBar = value;
              break;
            case 'Sommelier':
              showSommelier = value;
              break;
            case 'Full Time':
              showFullTime = value;
              break;
            case 'Part Time':
              showPartTime = value;
              break;
            case 'Season':
              showSeason = value;
              break;
          }
        });
      },
      backgroundColor: Colors.blue.shade100,
      selectedColor: Colors.blue.shade400,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
      shape: const StadiumBorder(side: BorderSide(color: Colors.blue)),
    );
  }
}