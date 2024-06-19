import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:hive_flutter/models/job.dart'; // Adjust the path as needed
import 'dart:math';
import 'dart:ui' as ui; // Import dart:ui for Path

class MapScreen extends StatelessWidget {
  final List<Job> jobs;

  const MapScreen({super.key, required this.jobs});

  // Function to generate random coordinates within Greece
  LatLng getRandomCoordinates() {
    final random = Random();
    // Latitude and longitude ranges for Greece
    double minLat = 34.802075;
    double maxLat = 41.748833;
    double minLng = 19.64761;
    double maxLng = 29.62912;

    double latitude = minLat + (maxLat - minLat) * random.nextDouble();
    double longitude = minLng + (maxLng - minLng) * random.nextDouble();

    return LatLng(latitude, longitude);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map'),
      ),
      body: FlutterMap(
        options: MapOptions(
          center: LatLng(37.9838, 23.7275), // Centered on Greece
          zoom: 6.0,
        ),
        children: [
          TileLayer(
            urlTemplate: "https://api.mapbox.com/styles/v1/{id}/tiles/{z}/{x}/{y}?access_token={accessToken}",
            additionalOptions: const {
              'accessToken': 'pk.eyJ1IjoiYW5hbmlhczEzIiwiYSI6ImNseDliMjJvYTJoYWcyanF1ZHoybGViYzMifQ.nJ8im-LnmEld5GrEDBaeUQ', // Replace with your Mapbox access token
              'id': 'mapbox/streets-v11',
            },
          ),
          MarkerLayer(
            markers: jobs.map((job) {
              // Use random coordinates for each job
              LatLng randomCoordinates = getRandomCoordinates();
              print("Creating marker for job: ${job.title} at (${randomCoordinates.latitude}, ${randomCoordinates.longitude})");

              return Marker(
                width: 150.0,  // Adjusted width for the marker to fit text
                height: 50.0,  // Adjusted height for the marker to fit text
                point: randomCoordinates,
                builder: (ctx) => GestureDetector(
                  onTap: () {
                    // Display job details or navigate to a detailed view
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(job.title),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(job.restaurant),
                            Text(job.description),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                // Navigate to detailed view or other actions
                              },
                              child: const Text('Details'),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Close'),
                          ),
                        ],
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
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
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
                            child: Text(
                              job.title,
                              style: const TextStyle(
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
