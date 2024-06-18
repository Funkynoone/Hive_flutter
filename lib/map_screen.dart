import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:hive_flutter/models/job.dart'; // Adjust the path as needed
import 'dart:math';

class MapScreen extends StatelessWidget {
  final List<Job> jobs;

  MapScreen({required this.jobs});

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
        title: Text('Map'),
      ),
      body: FlutterMap(
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
            markers: jobs.map((job) {
              // Use random coordinates for each job
              LatLng randomCoordinates = getRandomCoordinates();
              print("Creating marker for job: ${job.title} at (${randomCoordinates.latitude}, ${randomCoordinates.longitude})");

              return Marker(
                width: 80.0,
                height: 80.0,
                point: randomCoordinates,
                builder: (ctx) => GestureDetector(
                  onTap: () {
                    // Display job details or navigate to a detailed view
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(job.title),
                        content: Text('${job.restaurant}\n${job.description}'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Icon(
                    Icons.location_on,
                    color: Colors.red,
                    size: 40.0,
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
