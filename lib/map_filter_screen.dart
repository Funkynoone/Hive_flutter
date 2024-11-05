import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/models/job.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:ui' as ui;
import 'package:hive_flutter/job_detail_screen.dart'; // Adjust import path as needed

class MapFilterScreen extends StatefulWidget {
  final List<Job>? initialJobs;

  const MapFilterScreen({super.key, this.initialJobs});

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
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _jobs = widget.initialJobs ?? [];
    if (_jobs.isEmpty) {
      _fetchJobs();
    }
  }

  Future<void> _fetchJobs() async {
    setState(() => _isLoading = true);

    try {
      Query query = FirebaseFirestore.instance.collection('JobListings');
      List<String> titleFilters = [];
      List<String> typeFilters = [];

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

      if (titleFilters.isNotEmpty) {
        query = query.where('category', arrayContainsAny: titleFilters);
      }

      final QuerySnapshot querySnapshot = await query.get();
      List<Job> jobs = querySnapshot.docs
          .map((doc) => Job.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      if (typeFilters.isNotEmpty) {
        jobs = jobs.where((job) => typeFilters.contains(job.type)).toList();
      }

      setState(() => _jobs = jobs);
    } catch (e) {
      debugPrint('Error fetching jobs: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading jobs: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Map'),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(8.0),
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                filterChip('Service', showService),
                filterChip('Manager', showManager),
                filterChip('Cook', showCook),
                filterChip('Cleaning', showCleaning),
                filterChip('Delivery', showDelivery),
                filterChip('Bar', showBar),
                filterChip('Sommelier', showSommelier),
                filterChip('Full Time', showFullTime),
                filterChip('Part Time', showPartTime),
                filterChip('Season', showSeason),
                const SizedBox(width: 8),
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
                    _fetchJobs();
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
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    center: LatLng(37.9838, 23.7275),
                    zoom: 6.0,
                    minZoom: 5.0,
                    maxZoom: 18.0,
                    interactiveFlags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: "https://api.mapbox.com/styles/v1/{id}/tiles/{z}/{x}/{y}?access_token={accessToken}",
                      additionalOptions: const {
                        'accessToken': 'pk.eyJ1IjoiYW5hbmlhczEzIiwiYSI6ImNseDliMjJvYTJoYWcyanF1ZHoybGViYzMifQ.nJ8im-LnmEld5GrEDBaeUQ',
                        'id': 'mapbox/streets-v11',
                      },
                    ),
                    MarkerLayer(
                      markers: _jobs.map((job) {
                        return Marker(
                          width: 150.0,
                          height: 50.0,
                          point: LatLng(job.latitude, job.longitude),
                          rotate: true,
                          builder: (ctx) => GestureDetector(
                            onTap: () {
                              showDialog(
                                context: context,
                                barrierDismissible: true,
                                builder: (context) => Dialog(
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          job.title,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(job.restaurant),
                                        Text(job.type),
                                        const SizedBox(height: 16),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                          children: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: const Text('Close'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () {
                                                Navigator.pop(context); // Close dialog
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => JobDetailScreen(job: job),
                                                  ),
                                                );
                                              },
                                              child: const Text('View Details'),
                                            ),
                                          ],
                                        ),
                                      ],
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
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8.0,
                                          vertical: 4.0
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(15.0),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 3.0,
                                            spreadRadius: 1.0,
                                            offset: Offset(2.0, 2.0),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            job.restaurant,
                                            style: const TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            job.title,
                                            style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
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
                if (_isLoading)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget filterChip(String label, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: FilterChip(
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
          _fetchJobs();
        },
        backgroundColor: Colors.blue.shade100,
        selectedColor: Colors.blue.shade400,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black,
        ),
        shape: const StadiumBorder(
          side: BorderSide(color: Colors.blue),
        ),
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}