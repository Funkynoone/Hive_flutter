import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/models/job.dart'; // Adjust the path as needed

class JobsScreen extends StatefulWidget {
  @override
  _JobsScreenState createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  // Define filter states
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
  // ... add more for each job specification and contract time

  String? selectedRegion;
  final List<String> regions = ['Attica', 'Sterea Ellada', 'Peloponnisus','Epirus','Thessalia','Thraki','Ionian islands','Aegean islands','Creta']; // Example regions list

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
            // Job Specifications Section
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
                filterChip('Sommelier', showSommelier)
                // ... more job specification chips
              ],
            ),
            SizedBox(height: 20),
            // Contract Time Section
            Text('Contract Time', style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold)),
            Wrap(
              spacing: 8.0,
              children: [
                filterChip('Full Time', showFullTime),
                filterChip('Part Time', showPartTime),
                filterChip('Season', showSeason),
                // ... more contract time chips
              ],
            ),
            SizedBox(height: 20),
            // Region Filter Dropdown
            Text('Region Filter', style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold)),
            DropdownButton<String>(
              isExpanded: true,
              value: selectedRegion,
              hint: Text('All Regions'),
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
              onPressed: () {
                // TODO: Implement search functionality
              },
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
            // ... your job listing ListView.builder here ...
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open Google Maps.')),
      );
    }
  }

  void _clearFilters() {
    setState(() {
      showFullTime = false;
      showPartTime = false;
      showSeason = false;
      showService = false;
      showManager = false;
      // ... set all other job specification and contract time booleans to false
      selectedRegion = null;
    });
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
          // ... handle other cases for each job specification and contract time
          }
        });
      },
      backgroundColor: Colors.blue.shade100,
      selectedColor: Colors.blue.shade400,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
      shape: StadiumBorder(),
    );
  }

// ... add your filterJobs method and other methods as needed ...
}
