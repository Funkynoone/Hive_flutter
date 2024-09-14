import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fluttertoast/fluttertoast.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  GoogleMapController? _mapController;
  LatLng _selectedLocation = const LatLng(37.7749, -122.4194); // Default to San Francisco
  late String _googleMapsApiKey;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _googleMapsApiKey = const String.fromEnvironment('GOOGLE_MAPS_API_KEY');
    } else {
      _googleMapsApiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
    }

    if (_googleMapsApiKey.isEmpty) {
      Fluttertoast.showToast(msg: "Google Maps API key is missing!");
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _onTap(LatLng position) {
    setState(() {
      _selectedLocation = position;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
      ),
      body: Column(
        children: [
          Expanded(
            child: _googleMapsApiKey.isNotEmpty
                ? GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: _selectedLocation,
                zoom: 12,
              ),
              onTap: _onTap,
              markers: {
                Marker(
                  markerId: const MarkerId('selected-location'),
                  position: _selectedLocation,
                ),
              },
            )
                : const Center(child: Text("Google Maps API key is missing")),
          ),
          // Add other registration form fields here (e.g., TextFields for username, email, password)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                // Implement registration logic here
                // You can use _selectedLocation as the owner's location
                print("Selected Location: $_selectedLocation");
              },
              child: const Text('Register'),
            ),
          ),
        ],
      ),
    );
  }
}
