import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/models/job.dart'; // Adjust the path as needed

class JobsScreen extends StatefulWidget {
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
  final List<String> regions = ['Attica', 'Sterea Ellada', 'Peloponnisus', 'Epirus', 'Thessalia', 'Thraki', 'Ionian islands', 'Aegean islands', 'Creta'];
  List<Job> _jobs = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Jobs'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: ElevatedButton(
              onPressed: _launchMapsUrl,
              child: Text('MAP'),
              style: ElevatedButton.styleFrom(
                primary: Colors.purple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18.0),
                ),
              ),
            ),
          ),
        ],
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Job Specifications', style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold)),
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
            SizedBox(height: 20),
            Text('Contract Time', style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8.0,
              children: [
                filterChip('Full Time', showFullTime),
                filterChip('Part Time', showPartTime),
                filterChip('Season', showSeason),
              ],
            ),
            SizedBox(height: 20),
            Text('Region Filter', style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              isExpanded: true,
              value: selectedRegion,
              hint: Text('Select Region'),
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
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _searchJobs,
              child: Text('SEARCH'),
              style: ElevatedButton.styleFrom(
                primary: Colors.purple,
                minimumSize: Size(double.infinity, 36),
              ),
            ),
            ElevatedButton(
              onPressed: _clearFilters,
              child: Text('CLEAR FILTERS'),
              style: ElevatedButton.styleFrom(
                primary: Colors.grey,
                minimumSize: Size(double.infinity, 36),
              ),
            ),
            _jobs.isNotEmpty
                ? ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _jobs.length,
              itemBuilder: (context, index) {
                final job = _jobs[index];
                return ListTile(
                  title: Text(job.title),
                  subtitle: Text('${job.restaurant} - ${job.type} - ${job.category}'),
                  onTap: () {/* Navigate to job detail */},
                );
              },
            )
                : Center(child: Text("No jobs found")),
          ],
        ),
      ),
    );
  }

  void _launchMapsUrl() async {
    const googleMapsUrl = "https://www.google.com/maps/search/?api=1&query=Greece";
    if (await canLaunch(googleMapsUrl)) {
      await launch(googleMapsUrl);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open Google Maps.')));
    }
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
  }
  void _searchJobs() async {
    Query query = FirebaseFirestore.instance.collection('JobListings');

    List<String> activeFilters = [];

    if (showService) activeFilters.add('Service');
    if (showManager) activeFilters.add('Manager');
    if (showCook) activeFilters.add('Cook');
    if (showCleaning) activeFilters.add('Cleaning');
    if (showDelivery) activeFilters.add('Delivery');
    if (showBar) activeFilters.add('Bar');
    if (showSommelier) activeFilters.add('Sommelier');
    if (showFullTime) activeFilters.add('FullTime');
    if (showPartTime) activeFilters.add('PartTime');
    if (showSeason) activeFilters.add('Season');

    // Filter by region if selected
    if (selectedRegion != null) query = query.where('region', isEqualTo: selectedRegion);
    print("Active filters: $activeFilters");
    print("Querying with region: $selectedRegion");

    // Apply job title filters if any are active
    if (activeFilters.isNotEmpty) {
      query = query.where('category', arrayContainsAny: activeFilters);
    }

    final QuerySnapshot querySnapshot = await query.get();
    final List<QueryDocumentSnapshot> documents = querySnapshot.docs;

    setState(() {
      _jobs = documents.map((doc) => Job.fromFirestore(doc.data() as Map<String, dynamic>)).toList();
    });
  }


  Widget filterChip(String label, bool isSelected) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool value) {
        setState(() {
          if (label == 'Service') showService = value;
          else if (label == 'Manager') showManager = value;
          else if (label == 'Cook') showCook = value;
          else if (label == 'Cleaning') showCleaning = value;
          else if (label == 'Delivery') showDelivery = value;
          else if (label == 'Bar') showBar = value;
          else if (label == 'Sommelier') showSommelier = value;
          else if (label == 'Full Time') showFullTime = value;
          else if (label == 'Part Time') showPartTime = value;
          else if (label == 'Season') showSeason = value;
          // Add more conditions for other filters if needed
        });
      },
      backgroundColor: Colors.blue.shade100,
      selectedColor: Colors.blue.shade400,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
      shape: StadiumBorder(side: BorderSide(color: Colors.blue)),
    );
  }
}
