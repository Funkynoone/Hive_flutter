import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/models/job.dart'; // Adjust the path as needed
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math';
import 'dart:ui' as ui; // Import dart:ui for Path
import 'job_detail_screen.dart'; // Import the JobDetailScreen widget

class MapFilterScreen extends StatefulWidget {
  const MapFilterScreen({super.key});

  @override
  _MapFilterScreenState createState() => _MapFilterScreenState();
}

class _MapFilterScreenState extends State<MapFilterScreen> {
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
  List<Job> _jobs = [];

  @override
  void initState() {
    super.initState();
    _fetchJobs();
  }

  void _fetchJobs() async {
    Query query = FirebaseFirestore.instance.collection('JobListings');

    List<String> titleFilters = [];
    List<String> typeFilters = [];

    // Adding title filters based on selected options
    if (showService) titleFilters.add('Service');
    if (showManager) titleFilters.add('Manager');
    if (showBar) titleFilters.add('Bar');
    if (showDelivery) titleFilters.add('Delivery');
    if (showSommelier) titleFilters.add('Sommelier');
    if (showCleaning) titleFilters.add('Cleaning');
    if (showCook) titleFilters.add('Cook');

    // Adding type filters based on selected options
    if (showFullTime) typeFilters.add('Full Time');
    if (showPartTime) typeFilters.add('Part Time');
    if (showSeason) typeFilters.add('Season');

    // Apply title filters if any are active using 'category' field
    if (titleFilters.isNotEmpty) {
      query = query.where('category', arrayContainsAny: titleFilters);
    }

    // Execute the query
    final QuerySnapshot querySnapshot = await query.get();
    List<Job> jobs = querySnapshot.docs.map((doc) => Job.fromFirestore(doc.data() as Map<String, dynamic>, doc.id)).toList();

    // Assign random coordinates within Greece for testing purposes
    final random = Random();
    for (var job in jobs) {
      job.latitude = 35.0 + random.nextDouble() * (42.0 - 35.0); // Latitude range for Greece
      job.longitude = 19.0 + random.nextDouble() * (28.0 - 19.0); // Longitude range for Greece
    }

    setState(() {
      _jobs = jobs;
    });

    // Debugging output
    print("Filters Applied: ${titleFilters.isNotEmpty || typeFilters.isNotEmpty}");
    print("Jobs Found: ${jobs.length}");
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
          _fetchJobs(); // Refresh jobs when filters change
        });
      },
      backgroundColor: Colors.blue.shade100,
      selectedColor: Colors.blue.shade400,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
      shape: const StadiumBorder(side: BorderSide(color: Colors.blue)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('Job Map', style: TextStyle(color: Colors.black)),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text('Job Specifications', style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold)),
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
                const Text('Contract Time', style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold)),
                Wrap(
                  spacing: 8.0,
                  children: [
                    filterChip('Full Time', showFullTime),
                    filterChip('Part Time', showPartTime),
                    filterChip('Season', showSeason),
                  ],
                ),
                ElevatedButton(
                  onPressed: () {
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
                    });
                    _fetchJobs(); // Refresh jobs when filters are cleared
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                  ),
                  child: const Text('Clear Filters'),
                ),
              ],
            ),
          ),
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                center: LatLng(37.9838, 23.7275), // Centered on Greece
                zoom: 6.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: "https://api.mapbox.com/styles/v1/{id}/tiles/{z}/{x}/{y}?access_token={accessToken}",
                  additionalOptions: {
                    'accessToken': 'pk.eyJ1IjoiYW5hbmlhczEzIiwiYSI6ImNseDliMjJvYTJoYWcyanF1ZHoybGViYzMifQ.nJ8im-LnmEld5GrEDBaeUQ', // Replace with your Mapbox access token
                    'id': 'mapbox/streets-v11',
                  },
                ),
                MarkerLayer(
                  markers: _jobs.map((job) {
                    return Marker(
                      width: 150.0,  // Adjusted width for the marker to fit text
                      height: 50.0,  // Adjusted height for the marker to fit text
                      point: LatLng(job.latitude, job.longitude),
                      builder: (ctx) => GestureDetector(
                        onTap: () {
                          // Display job details or navigate to a detailed view
                          showDialog(
                            context: context,
                            builder: (context) => GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
                              child: Dialog(
                                insetPadding: EdgeInsets.all(10),
                                backgroundColor: Colors.transparent,
                                child: GestureDetector(
                                  onTap: () {},
                                  child: Container(
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          job.title,
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                        ),
                                        Text('${job.restaurant}'),
                                        Text('${job.description}'),
                                        ElevatedButton(
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => JobDetailScreen(job: job),
                                              ),
                                            );
                                          },
                                          child: Text('Details'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        child: Stack(
                          children: [
                            Positioned(
                              bottom: 0,
                              child: CustomPaint(
                                painter: BubblePainter(),
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(15.0),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 3.0,
                                        spreadRadius: 1.0,
                                        offset: Offset(2.0, 2.0),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    job.title,
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BubblePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = ui.Path()
      ..moveTo(size.width / 2 - 5, size.height)
      ..lineTo(size.width / 2, size.height + 10)
      ..lineTo(size.width / 2 + 5, size.height)
      ..close();

    canvas.drawPath(path, paint);

    final borderPaint = Paint()
      ..color = Colors.black26
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
