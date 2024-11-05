import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddJobScreen extends StatefulWidget {
  const AddJobScreen({super.key});

  @override
  _AddJobScreenState createState() => _AddJobScreenState();
}

class _AddJobScreenState extends State<AddJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _jobDescriptionController = TextEditingController();
  String? _selectedJobTitle;
  String? _selectedJobType;
  String? _selectedRegion;

  String? _businessName;
  double? _businessLatitude;
  double? _businessLongitude;
  bool _isLoading = true;
  bool _isSaving = false;

  final List<String> jobTitles = [
    'Service', 'Bar', 'Cook', 'Cleaning', 'Manager', 'Delivery', 'Sommelier'
  ];
  final List<String> jobTypes = ['Full Time', 'Part Time', 'Season'];
  final List<String> regions = [
    'Attica', 'Sterea Ellada', 'Peloponnisus', 'Epirus', 'Thessalia',
    'Thraki', 'Ionian islands', 'Aegean islands', 'Creta'
  ];

  @override
  void initState() {
    super.initState();
    _loadBusinessDetails();
  }

  Future<void> _loadBusinessDetails() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userData = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userData.exists) {
          setState(() {
            _businessName = userData.data()?['businessName'];
            _businessLatitude = userData.data()?['businessLocation']?.latitude;
            _businessLongitude =
                userData.data()?['businessLocation']?.longitude;
          });

          if (_businessName == null || _businessLatitude == null ||
              _businessLongitude == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text(
                  'Business location not found. Please update your profile.')),
            );
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading business details: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _jobDescriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Job Offer'),
      ),
      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Business: $_businessName',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Location: ${_businessLatitude?.toStringAsFixed(
                                  6)}, ${_businessLongitude?.toStringAsFixed(
                                  6)}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      value: _selectedJobTitle,
                      decoration: const InputDecoration(
                        labelText: 'Job Title',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() => _selectedJobTitle = value);
                      },
                      items: jobTitles.map((title) {
                        return DropdownMenuItem(value: title,
                            child: Text(title));
                      }).toList(),
                      validator: (value) =>
                      value == null
                          ? 'Please select a job title'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      value: _selectedJobType,
                      decoration: const InputDecoration(
                        labelText: 'Job Type',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() => _selectedJobType = value);
                      },
                      items: jobTypes.map((type) {
                        return DropdownMenuItem(value: type, child: Text(type));
                      }).toList(),
                      validator: (value) =>
                      value == null
                          ? 'Please select a job type'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      value: _selectedRegion,
                      decoration: const InputDecoration(
                        labelText: "Region (Optional)",
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (String? newValue) {
                        setState(() => _selectedRegion = newValue);
                      },
                      items: regions.map<DropdownMenuItem<String>>((
                          String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _jobDescriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Job Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 6,
                      validator: (value) =>
                      value!.isEmpty
                          ? 'Please enter a job description'
                          : null,
                    ),
                    const SizedBox(height: 20),

                    ElevatedButton(
                      onPressed: (_businessLatitude != null && !_isSaving)
                          ? _addJobOffer
                          : null,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors
                              .white),
                          strokeWidth: 2,
                        ),
                      )
                          : const Text(
                        'Add Job Offer',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_isSaving)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  void _addJobOffer() async {
    if (_formKey.currentState!.validate()) {
      try {
        // Disable the button while saving
        setState(() => _isSaving = true);

        // Create the job listing
        await FirebaseFirestore.instance.collection('JobListings').add({
          'title': _selectedJobTitle,
          'type': _selectedJobType,
          'region': _selectedRegion ?? '',
          'description': _jobDescriptionController.text,
          'category': [
            if (_selectedJobTitle != null) _selectedJobTitle!,
            if (_selectedJobType != null) _selectedJobType!,
          ],
          'restaurant': _businessName,
          'latitude': _businessLatitude,
          'longitude': _businessLongitude,
          'createdAt': FieldValue.serverTimestamp(),
          'imageUrl': 'https://via.placeholder.com/50',
        });

        if (!mounted) return;

        // Show success message before navigation
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job offer added successfully')),
        );

        // Wait a moment for the SnackBar to appear, then navigate
        await Future.delayed(const Duration(milliseconds: 500));

        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);

      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add job offer: $e')),
        );
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
        }
      }
    }
  }
}