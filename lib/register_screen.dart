import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_google_places/flutter_google_places.dart';
import 'package:google_maps_webservice/places.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _locationController = TextEditingController();

  bool isBusinessOwner = false;
  LatLng? selectedPlaceLatLng;
  String? selectedRegion;

  final places = GoogleMapsPlaces(apiKey: "AIzaSyAL3YGfLOU2Ihv0i26NK41MQTFfUJ_l_TY");

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Register'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SwitchListTile(
              title: Text('Register as Business Owner'),
              value: isBusinessOwner,
              onChanged: (bool value) {
                setState(() {
                  isBusinessOwner = value;
                });
                if (!isBusinessOwner) {
                  _locationController.clear();
                }
              },
            ),
            Visibility(
              visible: isBusinessOwner,
              child: TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: 'Restaurant Location',
                ),
                readOnly: true,
                onTap: () async {
                  Prediction? p = await PlacesAutocomplete.show(
                    context: context,
                    apiKey: "AIzaSyAL3YGfLOU2Ihv0i26NK41MQTFfUJ_l_TY",
                    mode: Mode.overlay,
                    types: [],
                    strictbounds: false,
                    components: [Component(Component.country, "us")],
                  );

                  displayPrediction(p);
                },
              ),
            ),
            TextFormField(
              controller: _usernameController,
              decoration: InputDecoration(labelText: 'Username'),
            ),
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            TextFormField(
              controller: _confirmPasswordController,
              decoration: InputDecoration(labelText: 'Confirm Password'),
              obscureText: true,
            ),
            ElevatedButton(
              child: Text('Register'),
              onPressed: () async {
                if (_passwordController.text == _confirmPasswordController.text) {
                  try {
                    UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
                      email: _emailController.text,
                      password: _passwordController.text,
                    );

                    if (userCredential.user != null) {
                      saveUserData(
                        userCredential.user!.uid,
                        _emailController.text,
                        _usernameController.text,
                        isBusinessOwner,
                        selectedPlaceLatLng?.latitude,
                        selectedPlaceLatLng?.longitude,
                        selectedRegion,
                      );
                    }
                  } on FirebaseAuthException catch (e) {
                    // Handle errors
                  }
                } else {
                  // Handle password mismatch
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> displayPrediction(Prediction? p) async {
    if (p != null) {
      PlacesDetailsResponse detail = await places.getDetailsByPlaceId(p.placeId!);
      final lat = detail.result.geometry!.location.lat;
      final lng = detail.result.geometry!.location.lng;

      setState(() {
        _locationController.text = detail.result.name;
        selectedPlaceLatLng = LatLng(lat, lng);
        selectedRegion = detail.result.formattedAddress;
      });
    }
  }

  void saveUserData(String userId, String email, String username, bool isBusinessOwner, double? latitude, double? longitude, String? region) {
    final userData = {
      'username': username,
      'email': email,
      'role': isBusinessOwner ? 'Business Owner' : 'Job Seeker',
      'latitude': latitude,
      'longitude': longitude,
      'region': region,
    };
    FirebaseFirestore.instance.collection('users').doc(userId).set(userData);
  }
}
