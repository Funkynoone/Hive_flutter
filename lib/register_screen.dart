// register_screen.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fluttertoast/fluttertoast.dart';

// Import the required packages
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
  late String _googleMapsApiKey;
  String? _businessName;

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
      _businessName = null; // Clear business name if user taps on the map
    });
  }

  // Method to handle the business search
  Future<void> _handlePressButton() async {
    if (_googleMapsApiKey.isEmpty) {
      Fluttertoast.showToast(msg: "Google Maps API key is missing!");
      return;
    }

    // Show the Google Places Autocomplete widget
    Prediction? p = await PlacesAutocomplete.show(
      context: context,
      apiKey: _googleMapsApiKey,
      mode: Mode.overlay, // or Mode.fullscreen
      language: 'en',
      components: [Component(Component.country, 'us')], // Adjust country code as needed
      types: ['establishment'],
    );

    await _displayPrediction(p);
  }

  // Method to handle the selected prediction
  Future<void> _displayPrediction(Prediction? p) async {
    if (p != null) {
      // Initialize Places API
      GoogleMapsPlaces places = GoogleMapsPlaces(apiKey: _googleMapsApiKey);

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
                    infoWindow: _businessName != null
                        ? InfoWindow(title: _businessName)
                        : const InfoWindow(title: 'Selected Location'),
                  ),
                },
              )
                  : const Center(child: Text("Google Maps API key is missing")),
            ),
            // Add other registration form fields here (e.g., TextFields for username, email, password)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Business search button
                  ElevatedButton(
                    onPressed: _googleMapsApiKey.isNotEmpty ? _handlePressButton : null,
                    child: const Text('Search Your Business'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Implement registration logic here
                      // You can use _selectedLocation and _businessName
                      print("Selected Business: $_businessName at $_selectedLocation");
                      // TODO: Proceed with the registration process using the collected data
                    },
                    child: const Text('Register'),
                  ),
                ],
              ),
            ),
          ],
        ));
  }
}
