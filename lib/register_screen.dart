import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_google_places/flutter_google_places.dart';
import 'package:google_maps_webservice/places.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  GoogleMapController? _mapController;
  LatLng _selectedLocation = const LatLng(37.7749, -122.4194); // Default to San Francisco
  String _googleMapsApiKey = 'YOUR_API_KEY'; // We'll get this from build config
  String? _businessName;

  @override
  void initState() {
    super.initState();
    // The API key is now managed through local.properties and build.gradle
    _googleMapsApiKey = const String.fromEnvironment('MAPS_API_KEY',
        defaultValue: 'AIzaSyBPNJFcuQXSg1m2NU_NWl02SJ15ZOXRJYI');
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _onTap(LatLng position) {
    setState(() {
      _selectedLocation = position;
      _businessName = null; // Clear business name if user taps on the map
    });
  }

  // Method to handle the business search
  Future<void> _handlePressButton() async {
    if (_googleMapsApiKey.isEmpty) {
      Fluttertoast.showToast(msg: "Google Maps API key is missing!");
      return;
    }

    try {
      // Show the Google Places Autocomplete widget
      Prediction? p = await PlacesAutocomplete.show(
        context: context,
        apiKey: _googleMapsApiKey,
        mode: Mode.overlay,
        language: 'en',
        components: [Component(Component.country, 'us')],
        types: ['establishment'],
      );

      await _displayPrediction(p);
    } catch (e) {
      Fluttertoast.showToast(msg: "Error: ${e.toString()}");
    }
  }

  // Method to handle the selected prediction
  Future<void> _displayPrediction(Prediction? p) async {
    if (p != null) {
      // Initialize Places API
      GoogleMapsPlaces places = GoogleMapsPlaces(apiKey: _googleMapsApiKey);

      try {
        // Get details of the selected place
        PlacesDetailsResponse detail = await places.getDetailsByPlaceId(p.placeId!);

        if (detail.status == "OK") {
          final lat = detail.result.geometry!.location.lat;
          final lng = detail.result.geometry!.location.lng;

          setState(() {
            _selectedLocation = LatLng(lat, lng);
            _businessName = detail.result.name;
          });

          // Move the map camera to the selected location
          _mapController?.animateCamera(CameraUpdate.newLatLng(_selectedLocation));
        } else {
          Fluttertoast.showToast(msg: "Error fetching place details: ${detail.errorMessage}");
        }
      } catch (e) {
        Fluttertoast.showToast(msg: "Error: ${e.toString()}");
      }
    }
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
            child: GoogleMap(
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
                  infoWindow: _businessName != null
                      ? InfoWindow(title: _businessName)
                      : const InfoWindow(title: 'Selected Location'),
                ),
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: _handlePressButton,
                  child: const Text('Search Your Business'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // Implement registration logic here
                    print("Selected Business: $_businessName at $_selectedLocation");
                  },
                  child: const Text('Register'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}