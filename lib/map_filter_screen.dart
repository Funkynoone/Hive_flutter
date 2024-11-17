import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:hive_flutter/models/job.dart';
import 'map/utils/job_marker_utils.dart';
import 'map/widgets/job_details_sheet.dart';
import 'map/widgets/cluster_details_sheet.dart';
import 'map/controllers/map_controller_helper.dart';

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

  void _handleMarkerTap(Job job) {
    setState(() {
      selectedJob = job;
      selectedClusterJobs = null;
      showClusterDetails = false;
      isFullDetails = false;
      _animationController.forward(from: 0.0);
    });
  }

  void _handleClusterTap(List<Marker> markers, LatLng center) {
    if (markers.length == 1) {
      final job = widget.initialJobs?.firstWhere(
            (job) => job.latitude == markers[0].point.latitude &&
            job.longitude == markers[0].point.longitude,
      );
      if (job != null) {
        _handleMarkerTap(job);
      }
    } else {
      final newZoom = MapControllerHelper.calculateOptimalZoom(
        markers,
        mapController.zoom,
      );

      if ((newZoom - mapController.zoom).abs() < 0.5) {
        final jobs = markers.map((m) => widget.initialJobs!.firstWhere(
              (job) =>
          job.latitude == m.point.latitude &&
              job.longitude == m.point.longitude,
        )).toList();

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
  }

  void _handleMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      selectedJob = null;
      selectedClusterJobs = null;
      showClusterDetails = false;
      isFullDetails = false;
      _animationController.reverse();
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (details.primaryVelocity! < -500) {
      setState(() {
        isFullDetails = true;
      });
    } else if (details.primaryVelocity! > 500) {
      setState(() {
        isFullDetails = false;
      });
    }
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
          if (selectedJob != null) _buildJobDetailsSheet(),
          if (showClusterDetails) _buildClusterDetailsSheet(),
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
              // Get the center point of the cluster using its bounds
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
      child: _buildClusterContent(markers, categories, color),
    );
  }

  Widget _buildClusterContent(
      List<Marker> markers, Set<dynamic> categories, Color color) {
    return Stack(
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
    );
  }

  Widget _buildJobDetailsSheet() {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return JobDetailsSheet(
          job: selectedJob!,
          isFullDetails: isFullDetails,
          isUploading: _isUploading,
          isSending: _isSending,
          onVerticalDragEnd: _handleDragEnd,
          setUploading: (value) => setState(() => _isUploading = value),
          setSending: (value) => setState(() => _isSending = value),
          animationValue: _animation.value,
        );
      },
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
            JobMarkerUtils.buildLegendItem(
                Icons.restaurant, 'Cook', Colors.orange),
            JobMarkerUtils.buildLegendItem(Icons.local_bar, 'Bar', Colors.purple),
            JobMarkerUtils.buildLegendItem(
                Icons.room_service, 'Service', Colors.blue),
            JobMarkerUtils.buildLegendItem(
                Icons.manage_accounts, 'Manager', Colors.green),
            JobMarkerUtils.buildLegendItem(
                Icons.delivery_dining, 'Delivery', Colors.red),
            JobMarkerUtils.buildLegendItem(
                Icons.cleaning_services, 'Cleaning', Colors.teal),
            JobMarkerUtils.buildLegendItem(
                Icons.wine_bar, 'Sommelier', Colors.deepPurple),
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