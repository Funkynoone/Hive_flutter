import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:hive_flutter/models/job.dart'; // Make sure this path is correct
import 'package:hive_flutter/models/job_filter_state.dart'; // Make sure this path is correct
import 'map/utils/job_marker_utils.dart'; // Make sure this path is correct
import 'map/widgets/job_details_sheet.dart'; // Make sure this path is correct
import 'map/widgets/cluster_details_sheet.dart'; // Make sure this path is correct
import 'map/controllers/map_controller_helper.dart'; // Make sure this path is correct
import 'map/widgets/radial_job_menu.dart'; // Make sure this path is correct

class MapFilterScreen extends StatefulWidget {
  final List<Job>? initialJobs;
  final JobFilterState? filterState;

  const MapFilterScreen({
    super.key,
    this.initialJobs,
    this.filterState,
  });

  @override
  _MapFilterScreenState createState() => _MapFilterScreenState();
}

class _MapFilterScreenState extends State<MapFilterScreen>
    with SingleTickerProviderStateMixin {
  Job? selectedJob;
  List<Job>? selectedClusterJobs;
  bool isFullDetails = false;
  bool _isSending = false;
  bool _isUploading = false;
  bool showClusterDetails = false;
  Offset? _radialMenuPosition;
  final MapController mapController = MapController();
  final PopupController _popupController = PopupController();
  late AnimationController _animationController;
  late Animation<double> _animation;

  // Group jobs by restaurant and location
  Map<String, List<Job>> restaurantGroups = {};
  List<Job> filteredJobs = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    // Initialize with all jobs
    filteredJobs = widget.initialJobs ?? [];

    _groupJobsByRestaurant(filteredJobs);


    // Add filter listener
    widget.filterState?.addListener(_onFiltersChanged);
  }

  @override
  void dispose() {
    widget.filterState?.removeListener(_onFiltersChanged);
    _animationController.dispose();
    super.dispose();
  }

  void _onFiltersChanged() {
    // Apply filters when they change
    _applyFilters();
  }

  void _applyFilters() {
    if (widget.filterState == null || widget.initialJobs == null) return;

    List<Job> newFilteredJobs = widget.initialJobs!;

    // Apply job spec filters
    final activeSpecs = widget.filterState!.activeJobSpecs;
    if (activeSpecs.isNotEmpty) {
      newFilteredJobs = newFilteredJobs.where((job) {
        return job.category.any((cat) => activeSpecs.contains(cat));
      }).toList();
    }

    // Apply contract type filters
    final activeTypes = widget.filterState!.activeContractTypes;
    if (activeTypes.isNotEmpty) {
      newFilteredJobs = newFilteredJobs.where((job) {
        return activeTypes.contains(job.type);
      }).toList();
    }

    // Update the map with filtered jobs
    setState(() {
      filteredJobs = newFilteredJobs;
      _groupJobsByRestaurant(filteredJobs);
    });
  }

  void _groupJobsByRestaurant(List<Job> jobs) {
    restaurantGroups.clear();
    for (var job in jobs) {
      // Ensure latitude and longitude are valid numbers
      if (job.latitude.isNaN || job.longitude.isNaN) {
        continue;
      }
      final key = '${job.restaurant}_${job.latitude}_${job.longitude}';
      restaurantGroups.putIfAbsent(key, () => []).add(job);
    }
  }

  void _handleMarkerTap(Job job, {bool showSheet = true}) {
    setState(() {
      selectedJob = job;
      selectedClusterJobs = null;
      _radialMenuPosition = null;
    });
    if (showSheet) _showJobDetails(job);
  }

  void _showJobDetails(Job job) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => JobDetailsSheet(
        job: job,
        setUploading: (value) => setState(() => _isUploading = value),
        setSending: (value) => setState(() => _isSending = value),
      ),
    );
  }

  void _handleClusterTap(List<Marker> markers, LatLng center) {

    final Map<String, Job> uniqueJobs = {};
    for (var marker in markers) {
      // Find the job associated with this marker point.
      // This part might need refinement if your markers don't directly map to single jobs
      // but are generated from restaurant groups as done in _buildMarkers.
      // A more robust way might be to store job IDs directly in the marker's properties if possible,
      // or to ensure the LatLng lookup is accurate.
      final jobsAtLocation = filteredJobs.where(
              (job) => job.latitude == marker.point.latitude &&
              job.longitude == marker.point.longitude
      ).toList();

      for (var job in jobsAtLocation) {
        uniqueJobs[job.id] = job;
      }
    }

    final jobs = uniqueJobs.values.toList();

    // Check if all jobs are from the same restaurant
    final sameOwner = jobs.isNotEmpty &&
        jobs.every((job) => job.restaurant == jobs.first.restaurant);

    if (sameOwner && jobs.length > 1) {
      // Show radial menu for same restaurant
      // NOTE: _radialMenuPosition calculation here is conceptual and needs to be a screen offset.
      // The current calculation (center.longitude * 1000) is incorrect for screen coordinates.
      // You'll need to use mapController.latLngToScreenPoint for accurate positioning.
      final screenPoint = mapController.latLngToScreenPoint(center);
      setState(() {
        selectedClusterJobs = jobs;
        _radialMenuPosition = Offset(screenPoint.x.toDouble(), screenPoint.y.toDouble());
        selectedJob = null;
        showClusterDetails = false;
      });
      return;
    }

    // Zoom in for different restaurants
    final newZoom = MapControllerHelper.calculateOptimalZoom(
      markers,
      mapController.zoom,
    );

    if ((newZoom - mapController.zoom).abs() < 0.5) {
      setState(() {
        selectedClusterJobs = jobs;
        selectedJob = null;
        showClusterDetails = true;
        isFullDetails = false;
        _animationController.forward(from: 0.0);
      });
    } else {
      mapController.move(center, newZoom);
    }
  }

  void _handleMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      selectedJob = null;
      selectedClusterJobs = null;
      showClusterDetails = false;
      _radialMenuPosition = null;
      isFullDetails = false;
      _animationController.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showLegend,
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildMap(),
          if (showClusterDetails) _buildClusterDetailsSheet(),
          if (_radialMenuPosition != null && selectedClusterJobs != null)
            RadialJobMenu(
              jobs: selectedClusterJobs!,
              // NOTE: This center is a screen coordinate, adjust RadialJobMenu if it expects LatLng
              center: _radialMenuPosition!,
              onJobSelected: (job) => _handleMarkerTap(job, showSheet: true),
              onDismiss: () {
                setState(() {
                  _radialMenuPosition = null;
                  selectedClusterJobs = null;
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        center: MapControllerHelper.DEFAULT_CENTER,
        zoom: MapControllerHelper.INITIAL_ZOOM,
        minZoom: MapControllerHelper.MIN_ZOOM,
        maxZoom: MapControllerHelper.MAX_ZOOM,
        interactiveFlags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        onTap: _handleMapTap,
      ),
      children: [
        TileLayer(
          urlTemplate:
          "https://api.mapbox.com/styles/v1/{id}/tiles/{z}/{x}/{y}?access_token={accessToken}",
          additionalOptions: const {
            // Replace with your actual Mapbox Access Token
            'accessToken':
            'pk.eyJ1IjoiYW5hbmlhczEzIiwiYSI6ImNseDliMjJvYTJoYWcyanF1ZHoybGViYzMifQ.nJ8im-LnmEld5GrEDBaeUQ',
            'id': 'mapbox/streets-v11',
          },
        ),
        MarkerClusterLayerWidget(
          options: MarkerClusterLayerOptions(
            maxClusterRadius: 80,
            size: const Size(40, 40),
            markers: _buildMarkers(), // This calls the marker builder
            builder: _buildCluster,
            onClusterTap: (cluster) {
              final centerPoint = LatLng(
                (cluster.bounds.north + cluster.bounds.south) / 2,
                (cluster.bounds.east + cluster.bounds.west) / 2,
              );
              _handleClusterTap(cluster.markers, centerPoint);
            },
            polygonOptions: const PolygonOptions(
              borderColor: Colors.blueAccent,
              color: Colors.black12,
              borderStrokeWidth: 3,
            ),
            animationsOptions: const AnimationsOptions(
              zoom: Duration(milliseconds: 500),
              centerMarker: Duration(milliseconds: 300),
              spiderfy: Duration(milliseconds: 300),
            ),
          ),
        ),
      ],
    );
  }

  List<Marker> _buildMarkers() {
    final List<Marker> markers = [];


    // Create markers for each restaurant group
    restaurantGroups.forEach((key, jobs) {
      if (jobs.isEmpty) {
        return;
      }

      final firstJob = jobs.first;

      // Ensure valid coordinates before creating LatLng
      if (firstJob.latitude.isNaN || firstJob.longitude.isNaN) {
        return;
      }

      final point = LatLng(firstJob.latitude, firstJob.longitude);

      markers.add(
        Marker(
          point: point,
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () {
              if (jobs.length == 1) {
                _handleMarkerTap(firstJob);
              } else {
                // Show radial menu for multiple jobs at same location
                setState(() {
                  selectedClusterJobs = jobs;
                  // Get the screen point of the tapped marker
                  final screenPoint = mapController.latLngToScreenPoint(point);
                  _radialMenuPosition = Offset(screenPoint.x.toDouble(), screenPoint.y.toDouble());
                  selectedJob = null;
                });
              }
            },
            // Temporary Test for Marker Visibility:
            // Uncomment the block below and comment out `child: _buildMarkerIcon(jobs),`
            /*
            child: Container(
              width: 40,
              height: 40,
              color: Colors.red.withOpacity(0.7), // Make it very obvious
              child: Center(
                child: Text(
                  jobs.length == 1 ? 'S' : '${jobs.length}', // S for single, number for grouped
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            */
            // Original marker icon builder:
            child: _buildMarkerIcon(jobs),
          ),
        ),
      );
    });
    return markers;
  }

  Widget _buildMarkerIcon(List<Job> jobs) {
    if (jobs.length == 1) {
      return _buildSingleJobMarker(jobs.first);
    } else {
      return _buildGroupedJobMarker(jobs);
    }
  }

  Widget _buildSingleJobMarker(Job job) {
    final color = JobMarkerUtils.getJobColor(job.category);
    final icon = JobMarkerUtils.getJobIcon(job.category);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: color,
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
        icon,
        color: color,
        size: 24,
      ),
    );
  }

  Widget _buildGroupedJobMarker(List<Job> jobs) {

    final primaryColor = JobMarkerUtils.getJobColor(jobs.first.category);

    return Stack(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: primaryColor,
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
          child: Center(
            child: Text(
              jobs.length.toString(),
              style: TextStyle(
                color: primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: primaryColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 1,
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.restaurant, // Consider making this dynamic based on primary category
                color: Colors.white,
                size: 10,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCluster(BuildContext context, List<Marker> markers) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade600,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.4),
            spreadRadius: 2,
            blurRadius: 5,
          ),
        ],
      ),
      child: Center(
        child: Text(
          markers.length.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildClusterDetailsSheet() {
    return ClusterDetailsSheet(
      jobs: selectedClusterJobs!,
      onJobSelected: _handleMarkerTap,
    );
  }

  void _showLegend() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Job Categories'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            JobMarkerUtils.buildLegendItem(Icons.restaurant, 'Cook', Colors.orange),
            JobMarkerUtils.buildLegendItem(Icons.local_bar, 'Bar', Colors.purple),
            JobMarkerUtils.buildLegendItem(Icons.room_service, 'Service', Colors.blue),
            JobMarkerUtils.buildLegendItem(Icons.manage_accounts, 'Manager', Colors.green),
            JobMarkerUtils.buildLegendItem(Icons.delivery_dining, 'Delivery', Colors.red),
            JobMarkerUtils.buildLegendItem(Icons.cleaning_services, 'Cleaning', Colors.teal),
            JobMarkerUtils.buildLegendItem(Icons.wine_bar, 'Sommelier', Colors.deepPurple),
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
  }
}