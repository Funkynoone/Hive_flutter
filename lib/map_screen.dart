import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:hive_flutter/models/job.dart'; // Adjust the path as needed

class MapScreen extends StatelessWidget {
  final List<Job> jobs;

  MapScreen({required this.jobs});

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
              return Marker(
                width: 80.0,
                height: 80.0,
                point: LatLng(job.latitude, job.longitude),
                builder: (ctx) => Container(
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
