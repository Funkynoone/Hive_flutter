import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddJobScreen extends StatefulWidget {
  const AddJobScreen({super.key});

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
  final List<String> jobTitles = [
    'Service',
    'Bar',
    'Cook',
    'Cleaning',
    'Manager',
    'Delivery',
    'Sommelier'
  ];
  final List<String> jobTypes = ['Full Time', 'Part Time', 'Season'];
  final List<String> regions = [
    'Attica',
    'Sterea Ellada',
    'Peloponnisus',
    'Epirus',
    'Thessalia',
    'Thraki',
    'Ionian islands',
    'Aegean islands',
    'Creta'
  ];

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
        title: const Text('Add Job Offer'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              DropdownButtonFormField<String>(
                value: _selectedJobTitle,
                decoration: const InputDecoration(
                    labelText: 'Job Title', border: OutlineInputBorder()),
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
                decoration: const InputDecoration(
                    labelText: 'Job Type', border: OutlineInputBorder()),
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
                decoration: const InputDecoration(
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
                decoration: const InputDecoration(
                    labelText: 'Job Description', border: OutlineInputBorder()),
                maxLines: 6,
                validator: (value) =>
                value!.isEmpty
                    ? 'Please enter a job description'
                    : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _addJobOffer,
                style: ElevatedButton.styleFrom(backgroundColor: Theme
                    .of(context)
                    .primaryColor),
                child: const Text('Add Job Offer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addJobOffer() {
    if (_formKey.currentState!.validate()) {
      // Determine the category based on the job title
      List<String> category = [];
      // Add the job title to the category list if not null
      if (_selectedJobTitle != null) {
        category.add(_selectedJobTitle!);
      }

      // Add the job type to the category list if not null
      if (_selectedJobType != null) {
        category.add(_selectedJobType!);
      }

      FirebaseFirestore.instance.collection('JobListings').add({
        'title': _selectedJobTitle,
        'type': _selectedJobType,
        'region': _selectedRegion,
        'description': _jobDescriptionController.text,
        // Save the determined category along with other job details
        'category': category,
      }).then((result) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Job offer added successfully')));
      }).catchError((error) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add job offer: $error')));
      });
    }
  }
}