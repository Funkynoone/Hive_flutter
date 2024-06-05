import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_google_places/flutter_google_places.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _locationController = TextEditingController();

  bool isBusinessOwner = false;
  LatLng? selectedPlaceLatLng;
  final places = GoogleMapsPlaces(apiKey: "AIzaSyAL3YGfLOU2Ihv0i26NK41MQTFfUJ_l_TY"); // Ensure you replace YOUR_API_KEY with your actual Google Maps API key

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SwitchListTile(
                title: Text(isBusinessOwner ? 'Business Owner' : 'Job Seeker'),
                value: isBusinessOwner,
                onChanged: (bool value) {
                  setState(() {
                    isBusinessOwner = value;
                    _locationController.clear();
                    selectedPlaceLatLng = null;
                  });
                },
              ),
              if (isBusinessOwner)
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Restaurant Location',
                    suffixIcon: Icon(Icons.search),
                  ),
                  readOnly: true,
                  onTap: () async {
                    Prediction? p = await PlacesAutocomplete.show(
                      context: context,
                      apiKey: "YOUR_API_KEY",
                      mode: Mode.overlay,
                      types: [],
                      strictbounds: false,
                      components: [Component(Component.country, "us")],
                    );

                    if (p != null) {
                      displayPrediction(p);
                    }
                  },
                ),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(labelText: 'Confirm Password'),
                obscureText: true,
              ),
              ElevatedButton(
                child: const Text('Register'),
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    // Registration logic
                    try {
                      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
                        email: _emailController.text.trim(),
                        password: _passwordController.text.trim(),
                      );
                      // On successful registration, save user data
                      if (userCredential.user != null) {
                        saveUserData(
                          userCredential.user!.uid,
                          _emailController.text.trim(),
                          _usernameController.text.trim(),
                          isBusinessOwner,
                          selectedPlaceLatLng?.latitude,
                          selectedPlaceLatLng?.longitude,
                        );
                      }
                    } on FirebaseAuthException catch (e) {
                      Fluttertoast.showToast(msg: "Failed to register: ${e.message}");
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> displayPrediction(Prediction p) async {
    if (p.placeId == null) {
      Fluttertoast.showToast(msg: "No place selected");
      return;
    }

    GoogleMapsPlaces places = GoogleMapsPlaces(apiKey: "AIzaSyAL3YGfLOU2Ihv0i26NK41MQTFfUJ_l_TY"); // Use your actual API key
    PlacesDetailsResponse detail = await places.getDetailsByPlaceId(p.placeId!);

    if (detail.status == "OK") {
      final lat = detail.result.geometry!.location.lat;
      final lng = detail.result.geometry!.location.lng;

      setState(() {
        _locationController.text = detail.result.name;
        selectedPlaceLatLng = LatLng(lat, lng);
      });
    } else {
      Fluttertoast.showToast(msg: "Failed to fetch location details");
    }
  }


  void saveUserData(String userId, String email, String username, bool isBusinessOwner, double? latitude, double? longitude) {
    FirebaseFirestore.instance.collection('users').doc(userId).set({
      'username': username,
      'email': email,
      'isBusinessOwner': isBusinessOwner,
      'location': GeoPoint(latitude ?? 0, longitude ?? 0),
    }).then((_) {
      Fluttertoast.showToast(msg: "Registration successful");
    }).catchError((error) {
      Fluttertoast.showToast(msg: "Failed to save user data: $error");
    });
  }
}
