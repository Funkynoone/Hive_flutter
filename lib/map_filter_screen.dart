import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:hive_flutter/models/job.dart';
import 'map/utils/job_marker_utils.dart';
import 'map/widgets/job_details_sheet.dart';
import 'map/widgets/cluster_details_sheet.dart';
import 'map/controllers/map_controller_helper.dart';
import 'map/widgets/radial_job_menu.dart';

class MapFilterScreen extends StatefulWidget {
  final List<Job>? initialJobs;

  const MapFilterScreen({super.key, this.initialJobs});

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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleMarkerTap(Job job, {bool showSheet = true}) {
    print("Selected job details - Title: ${job.title}, Restaurant: ${job.restaurant}");
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
    print("Raw markers: ${markers.length}");

    final Map<String, Job> uniqueJobs = {};
    for (var marker in markers) {
      print("Checking marker at: ${marker.point}");
      final jobsAtLocation = widget.initialJobs!.where(
              (job) => job.latitude == marker.point.latitude &&
              job.longitude == marker.point.longitude
      ).toList();
      print("Found ${jobsAtLocation.length} jobs at location");

      for (var job in jobsAtLocation) {
        uniqueJobs[job.id] = job;
      }
    }

    final jobs = uniqueJobs.values.toList();
    print("Total unique jobs: ${jobs.length}");

    final sameOwner = jobs.every((job) => job.restaurant == jobs.first.restaurant);
    if (sameOwner) {
      print("Jobs in cluster: ${jobs.length}");
      print("Unique jobs restaurant: ${uniqueJobs.values.first.restaurant}");
      print("All job titles: ${uniqueJobs.values.map((j) => j.title).join(', ')}");
      if (jobs.length != uniqueJobs.length) {  // Fixed here
        print("Mismatch in job count vs unique jobs");
      }
      final screenPoint = mapController.latLngToScreenPoint(center);
      if (screenPoint != null) {
        setState(() {
          selectedClusterJobs = uniqueJobs.values.toList(); // Use unique jobs only
          _radialMenuPosition = Offset(screenPoint.x.toDouble(), screenPoint.y.toDouble());
          selectedJob = null;
          showClusterDetails = false;
        });
      }
      return;
    }

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
            'accessToken':
            'pk.eyJ1IjoiYW5hbmlhczEzIiwiYSI6ImNseDliMjJvYTJoYWcyanF1ZHoybGViYzMifQ.nJ8im-LnmEld5GrEDBaeUQ',
            'id': 'mapbox/streets-v11',
          },
        ),
        MarkerClusterLayerWidget(
          options: MarkerClusterLayerOptions(
            maxClusterRadius: 45,
            size: const Size(40, 40),
            markers: _buildMarkers(),
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
          ),
        ),
      ],
    );
  }

  List<Marker> _buildMarkers() {
    return widget.initialJobs?.map((job) {
      return Marker(
        point: LatLng(job.latitude, job.longitude),
        width: 40,
        height: 40,
        builder: (context) => GestureDetector(
          onTap: () => _handleMarkerTap(job),
          child: _buildMarkerIcon(job),
        ),
      );
    }).toList() ??
        [];
  }

  Widget _buildMarkerIcon(Job job) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: JobMarkerUtils.getJobColor(job.category),
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
        JobMarkerUtils.getJobIcon(job.category),
        color: JobMarkerUtils.getJobColor(job.category),
        size: 24,
      ),
    );
  }

  Widget _buildCluster(BuildContext context, List<Marker> markers) {
    final categories = markers
        .map((m) => widget.initialJobs!.firstWhere(
          (job) =>
      job.latitude == m.point.latitude &&
          job.longitude == m.point.longitude,
    ))
        .expand((job) => job.category)
        .toSet();

    final color = categories.length == 1
        ? JobMarkerUtils.getJobColor(categories.first as List<String>)
        : Colors.blue;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
          ),
        ],
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              markers.length.toString(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (categories.length > 1)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color,
                    width: 1,
                  ),
                ),
                child: Text(
                  '${categories.length}',
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                  ),
                ),
              ),
            ),
        ],
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