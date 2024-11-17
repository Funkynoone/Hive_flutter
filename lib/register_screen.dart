import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_google_places/flutter_google_places.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool isBusinessOwner = false;
  bool isLoading = false;
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  GoogleMapController? _mapController;
  LatLng _selectedLocation = const LatLng(37.9838, 23.7275); // Athens coordinates
  String _googleMapsApiKey = 'YOUR_API_KEY';
  String? _businessName;

  @override
  void initState() {
    super.initState();
    _googleMapsApiKey = const String.fromEnvironment('MAPS_API_KEY',
        defaultValue: 'AIzaSyBPNJFcuQXSg1m2NU_NWl02SJ15ZOXRJYI');
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _onTap(LatLng position) {
    setState(() {
      _selectedLocation = position;
      _businessName = null;
    });
  }

  Future<void> _handlePressButton() async {
    print('Starting place search...');

    if (_googleMapsApiKey.isEmpty) {
      print('API key is empty!');
      Fluttertoast.showToast(msg: "Google Maps API key is missing!");
      return;
    }

    try {
      setState(() => isLoading = true);

      Prediction? p = await PlacesAutocomplete.show(
        context: context,
        apiKey: _googleMapsApiKey,
        mode: Mode.overlay,
        language: 'el', // Greek language
        components: [Component(Component.country, 'gr')], // Greece
        types: ['establishment'],
        strictbounds: false,
        location: Location(lat: 37.9838, lng: 23.7275), // Athens coordinates
      );

      if (p != null) {
        await _displayPrediction(p);
      }
    } catch (e) {
      print('Error in place search: $e');
      Fluttertoast.showToast(msg: "Error searching: ${e.toString()}");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _displayPrediction(Prediction p) async {
    print('Processing prediction: ${p.description}');

    if (p.placeId == null) {
      print('No place ID found');
      return;
    }

    try {
      final places = GoogleMapsPlaces(apiKey: _googleMapsApiKey);
      final PlacesDetailsResponse detail = await places.getDetailsByPlaceId(p.placeId!);

      if (detail.status == "OK") {
        final lat = detail.result.geometry!.location.lat;
        final lng = detail.result.geometry!.location.lng;
        final name = detail.result.name;

        print('Place details found: $name at $lat,$lng');

        setState(() {
          _selectedLocation = LatLng(lat, lng);
          _businessName = name;
        });

        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(
          _selectedLocation,
          15.0,
        ));

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Selected: $name')),
        );
      } else {
        print('Place details error: ${detail.errorMessage}');
        Fluttertoast.showToast(msg: "Error: ${detail.errorMessage}");
      }
    } catch (e) {
      print('Error getting place details: $e');
      Fluttertoast.showToast(msg: "Error: ${e.toString()}");
    }
  }

  Future<void> _register() async {
    print('Starting registration process');

    if (_emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        (!isBusinessOwner && _usernameController.text.isEmpty) ||
        (isBusinessOwner && _businessName == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all required fields")),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords don't match")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      print('Creating user in Firebase Auth');
      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      print('User created, saving additional data');

      final userData = {
        'username': isBusinessOwner ? _businessName : _usernameController.text,
        'email': _emailController.text.trim(),
        'isBusinessOwner': isBusinessOwner,
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (isBusinessOwner && _businessName != null) {
        userData.addAll({
          'businessName': _businessName,
          'businessLocation': GeoPoint(
            _selectedLocation.latitude,
            _selectedLocation.longitude,
          ),
        });
      }

      print('Saving to Firestore: $userData');

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set(userData);

      print('Data saved successfully');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Registration successful!")),
      );

      Navigator.pop(context);

    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: ${e.code} - ${e.message}');
      String message;
      switch (e.code) {
        case 'weak-password':
          message = 'The password provided is too weak.';
          break;
        case 'email-already-in-use':
          message = 'An account already exists for that email.';
          break;
        case 'invalid-email':
          message = 'The email address is badly formatted.';
          break;
        default:
          message = e.message ?? 'An error occurred';
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      print('General Error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('User'),
                Switch(
                  value: isBusinessOwner,
                  onChanged: (value) {
                    setState(() {
                      isBusinessOwner = value;
                    });
                  },
                ),
                const Text('Business Owner'),
              ],
            ),

            if (!isBusinessOwner) ...[
              const SizedBox(height: 20),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ],

            if (isBusinessOwner) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: isLoading ? null : _handlePressButton,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: isLoading
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                    : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search),
                    SizedBox(width: 8),
                    Text('Find Your Business'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              if (_businessName != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Selected Business: $_businessName',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: GoogleMap(
                    onMapCreated: _onMapCreated,
                    initialCameraPosition: CameraPosition(
                      target: _selectedLocation,
                      zoom: 15,
                    ),
                    markers: {
                      Marker(
                        markerId: const MarkerId('selected-location'),
                        position: _selectedLocation,
                        infoWindow: InfoWindow(title: _businessName),
                      ),
                    },
                  ),
                ),
              ],
            ],

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: isLoading ? null : _register,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: isLoading
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : const Text(
                'Register',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}