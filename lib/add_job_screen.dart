import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddJobScreen extends StatefulWidget {
  @override
  _AddJobScreenState createState() => _AddJobScreenState();
}

class _AddJobScreenState extends State<AddJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _restaurantController = TextEditingController();
  final TextEditingController _regionController = TextEditingController(); // This might be redundant now
  final TextEditingController _jobDescriptionController = TextEditingController();
  String? _selectedJobTitle;
  String? _selectedJobType;
  String? _selectedRegion;
  final List<String> jobTitles = ['Service', 'Bar', 'Cook', 'Cleaning', 'Manager', 'Delivery', 'Sommelier'];
  final List<String> jobTypes = ['Full-time', 'Part-time', 'Season'];
  final List<String> regions = ['Attica', 'Sterea Ellada', 'Peloponnisus', 'Epirus', 'Thessalia', 'Thraki', 'Ionian islands', 'Aegean islands', 'Creta'];

  @override
  void dispose() {
    _restaurantController.dispose();
    _regionController.dispose(); // Consider removing if not used
    _jobDescriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Job Offer'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              DropdownButtonFormField<String>(
                value: _selectedJobTitle,
                decoration: InputDecoration(labelText: 'Job Title', border: OutlineInputBorder()),
                onChanged: (value) {
                  setState(() {
                    _selectedJobTitle = value;
                  });
                },
                items: jobTitles.map((title) {
                  return DropdownMenuItem(
                    value: title,
                    child: Text(title),
                  );
                }).toList(),
              ),
              DropdownButtonFormField<String>(
                value: _selectedJobType,
                decoration: InputDecoration(labelText: 'Job Type', border: OutlineInputBorder()),
                onChanged: (value) {
                  setState(() {
                    _selectedJobType = value;
                  });
                },
                items: jobTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
              ),
              DropdownButtonFormField<String>(
                value: _selectedRegion,
                decoration: InputDecoration(
                  labelText: "Region",
                  border: OutlineInputBorder(),
                ),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedRegion = newValue!;
                  });
                },
                items: regions.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
              TextFormField(
                controller: _jobDescriptionController,
                decoration: InputDecoration(labelText: 'Job Description', border: OutlineInputBorder()),
                maxLines: 6,
                validator: (value) => value!.isEmpty ? 'Please enter a job description' : null,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _addJobOffer,
                child: Text('Add Job Offer'),
                style: ElevatedButton.styleFrom(primary: Theme.of(context).primaryColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addJobOffer() {
    if (_formKey.currentState!.validate()) {
      FirebaseFirestore.instance.collection('JobListings').add({
        'title': _selectedJobTitle,
        'type': _selectedJobType,
        'region': _selectedRegion,
        'description': _jobDescriptionController.text,
      }).then((result) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Job offer added successfully')));
        // Optionally, clear the form here
      }).catchError((error) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add job offer: $error')));
      });
    }
  }
}
