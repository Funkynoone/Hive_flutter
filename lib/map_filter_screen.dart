import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/models/job.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:hive_flutter/job_detail_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'dart:math' show min, max, pi, cos, sin;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/services/notification_service.dart';

class MapFilterScreen extends StatefulWidget {
  final List<Job>? initialJobs;

  const MapFilterScreen({super.key, this.initialJobs});

  @override
  _MapFilterScreenState createState() => _MapFilterScreenState();
}

class _MapFilterScreenState extends State<MapFilterScreen> {
  Job? selectedJob;
  bool isFullDetails = false;
  bool _isSending = false;
  bool _isUploading = false;
  final MapController mapController = MapController();
  Set<LatLng> expandedClusters = {};

  IconData getJobIcon(List<String> categories) {
    if (categories.contains('Cook')) return Icons.restaurant;
    if (categories.contains('Bar')) return Icons.local_bar;
    if (categories.contains('Service')) return Icons.room_service;
    if (categories.contains('Manager')) return Icons.manage_accounts;
    if (categories.contains('Delivery')) return Icons.delivery_dining;
    if (categories.contains('Cleaning')) return Icons.cleaning_services;
    if (categories.contains('Sommelier')) return Icons.wine_bar;
    return Icons.work;
  }

  Color getJobColor(List<String> categories) {
    if (categories.contains('Cook')) return Colors.orange;
    if (categories.contains('Bar')) return Colors.purple;
    if (categories.contains('Service')) return Colors.blue;
    if (categories.contains('Manager')) return Colors.green;
    if (categories.contains('Delivery')) return Colors.red;
    if (categories.contains('Cleaning')) return Colors.teal;
    if (categories.contains('Sommelier')) return Colors.deepPurple;
    return Colors.grey;
  }

  Future<void> _uploadCV() async {
    try {
      setState(() => _isUploading = true);

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
      );

      if (result == null) {
        setState(() => _isUploading = false);
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isUploading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please login to apply')),
          );
        }
        return;
      }

      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final file = File(result.files.single.path!);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${result.files.single.name}';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('cvs')
          .child(selectedJob!.id)
          .child(fileName);

      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('JobListings')
          .doc(selectedJob!.id)
          .collection('Applications')
          .add({
        'userId': user.uid,
        'name': userData['username'] ?? 'Anonymous',
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
        'cvUrl': downloadUrl,
        'fileName': result.files.single.name,
        'type': 'cv',
      });

      await NotificationService().createNotification(
        userId: selectedJob!.ownerId,
        senderId: user.uid,
        title: 'New CV Application',
        message: '${userData['username'] ?? 'Anonymous'} submitted a CV application',
        type: 'cv',
        data: {
          'jobId': selectedJob!.id,
          'jobTitle': selectedJob!.title,
          'businessName': selectedJob!.restaurant,
          'applicantName': userData['username'] ?? 'Anonymous',
          'cvUrl': downloadUrl,
          'timestamp': FieldValue.serverTimestamp(),
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CV uploaded successfully!')),
        );
      }
    } catch (e) {
      print('Error uploading CV: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading CV: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _sendApplication(String message) async {
    setState(() => _isSending = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login to apply')),
        );
        return;
      }

      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      await FirebaseFirestore.instance
          .collection('JobListings')
          .doc(selectedJob!.id)
          .collection('Applications')
          .add({
        'userId': user.uid,
        'name': userData['username'] ?? 'Anonymous',
        'message': message,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'message',
      });

      await NotificationService().createNotification(
        userId: selectedJob!.ownerId,
        senderId: user.uid,
        title: 'New Message',
        message: message,
        type: 'message',
        data: {
          'jobId': selectedJob!.id,
          'jobTitle': selectedJob!.title,
          'businessName': selectedJob!.restaurant,
          'applicantName': userData['username'] ?? 'Anonymous',
          'timestamp': FieldValue.serverTimestamp(),
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message sent successfully!')),
        );
      }
    } catch (e) {
      print('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _showMessageDialog() {
    final messageController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Message to Owner'),
        content: TextField(
          controller: messageController,
          decoration: const InputDecoration(
            hintText: 'Write your message...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (messageController.text.isNotEmpty) {
                Navigator.pop(context);
                _sendApplication(messageController.text);
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final defaultCenter = LatLng(37.9838, 23.7275);

    return Scaffold(
        appBar: AppBar(
          title: const Text('Job Map'),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Job Categories'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildLegendItem(Icons.restaurant, 'Cook', Colors.orange),
                        _buildLegendItem(Icons.local_bar, 'Bar', Colors.purple),
                        _buildLegendItem(Icons.room_service, 'Service', Colors.blue),
                        _buildLegendItem(Icons.manage_accounts, 'Manager', Colors.green),
                        _buildLegendItem(Icons.delivery_dining, 'Delivery', Colors.red),
                        _buildLegendItem(Icons.cleaning_services, 'Cleaning', Colors.teal),
                        _buildLegendItem(Icons.wine_bar, 'Sommelier', Colors.deepPurple),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        body: Stack(
          children: [
          FlutterMap(
          mapController: mapController,
          options: MapOptions(
            center: defaultCenter,
            zoom: 6.0,
            minZoom: 5.0,
            maxZoom: 18.0,
            interactiveFlags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            onTap: (_, __) {
              setState(() {
                selectedJob = null;
                isFullDetails = false;
                expandedClusters.clear();
              });
            },
          ),
          children: [
            TileLayer(
              urlTemplate: "https://api.mapbox.com/styles/v1/{id}/tiles/{z}/{x}/{y}?access_token={accessToken}",
              additionalOptions: const {
                'accessToken': 'pk.eyJ1IjoiYW5hbmlhczEzIiwiYSI6ImNseDliMjJvYTJoYWcyanF1ZHoybGViYzMifQ.nJ8im-LnmEld5GrEDBaeUQ',
                'id': 'mapbox/streets-v11',
              },
              maxZoom: 18,
              minZoom: 4,
              tileSize: 512,
              zoomOffset: -1,
            ),
            MarkerClusterLayerWidget(
              options: MarkerClusterLayerOptions(
                maxClusterRadius: 45,
                size: const Size(40, 40),
                anchor: AnchorPos.align(AnchorAlign.center),
                markers: widget.initialJobs?.map((job) {
                  return Marker(
                    point: LatLng(job.latitude, job.longitude),
                    width: 40,
                    height: 40,
                    builder: (context) => GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedJob = job;
                          isFullDetails = false;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: getJobColor(job.category),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              spreadRadius: 2,
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          getJobIcon(job.category),
                          color: getJobColor(job.category),
                          size: 24,
                        ),
                      ),
                    ),
                  );
                }).toList() ?? [],
                builder: (context, markers) {
                  return GestureDetector(
                    onTap: () {
                      if (markers.length > 1) {
                        // Calculate bounds for the cluster
                        final points = markers.map((m) => m.point).toList();
                        final bounds = LatLngBounds.fromPoints(points);

                        // Calculate the zoom level needed to see all markers
                        final double newZoom = mapController.zoom + 1.5;

                        // Get the center point of the cluster
                        final center = markers.map((m) => m.point).reduce(
                              (value, element) => LatLng(
                            (value.latitude + element.latitude) / 2,
                            (value.longitude + element.longitude) / 2,
                          ),
                        );

                        // Animate to new position
                        mapController.move(center, newZoom);
                      } else if (markers.length == 1) {
                        // If there's only one marker in the cluster, show its details
                        final job = widget.initialJobs?.firstWhere(
                              (job) => job.latitude == markers[0].point.latitude &&
                              job.longitude == markers[0].point.longitude,
                        );
                        if (job != null) {
                          setState(() {
                            selectedJob = job;
                            isFullDetails = false;
                          });
                        }
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blue, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            spreadRadius: 2,
                            blurRadius: 5,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          markers.length.toString(),
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
            if (selectedJob != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onVerticalDragEnd: (details) {
                    if (details.primaryVelocity! < -500) {
                      setState(() {
                        isFullDetails = true;
                      });
                    } else if (details.primaryVelocity! > 500) {
                      setState(() {
                        isFullDetails = false;
                      });
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: isFullDetails ? MediaQuery.of(context).size.height * 0.8 : 140,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          spreadRadius: 2,
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: getJobColor(selectedJob!.category).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        getJobIcon(selectedJob!.category),
                                        color: getJobColor(selectedJob!.category),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            selectedJob!.restaurant,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            selectedJob!.title,
                                            style: const TextStyle(fontSize: 16),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.work_outline, size: 16, color: Colors.blue.shade700),
                                          const SizedBox(width: 4),
                                          Text(
                                            selectedJob!.type,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.blue.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.green.shade100),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.euro, size: 16, color: Colors.green.shade700),
                                          const SizedBox(width: 4),
                                          Text(
                                            selectedJob!.salaryNotGiven
                                                ? 'Not Given'
                                                : '${selectedJob!.salary} ${selectedJob!.salaryType}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.green.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (!isFullDetails) ...[
                                  Text(
                                    selectedJob!.description.length > 100
                                        ? '${selectedJob!.description.substring(0, 100)}...'
                                        : selectedJob!.description,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Center(
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        'Swipe up for more details',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[400],
                                        ),
                                      ),
                                    ),
                                  ),
                                ] else ...[
                                  const SizedBox(height: 16),
                                  Text(
                                    'Job Description',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    selectedJob!.description,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'Requirements',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    selectedJob!.requirements,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: _isUploading ? null : _uploadCV,
                                        icon: const Icon(Icons.upload_file),
                                        label: Text(_isUploading ? 'Uploading...' : 'Upload CV'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Theme.of(context).primaryColor,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        ),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: _isSending ? null : _showMessageDialog,
                                        icon: const Icon(Icons.message),
                                        label: Text(_isSending ? 'Sending...' : 'Send Message'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
    );
  }

  Widget _buildLegendItem(IconData icon, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }
}