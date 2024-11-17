import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' show log, ln2, min;

class MapControllerHelper {
  static const double MIN_ZOOM = 5.0;
  static const double MAX_ZOOM = 18.0;
  static const double INITIAL_ZOOM = 6.0;
  static const double CLUSTER_ZOOM_INCREMENT = 1.5;
  static final LatLng DEFAULT_CENTER = LatLng(37.9838, 23.7275);

  static double calculateOptimalZoom(List<Marker> markers, double currentZoom) {
    if (markers.length <= 1) return currentZoom;

    final points = markers.map((m) => m.point).toList();
    final bounds = LatLngBounds.fromPoints(points);

    final ne = bounds.northEast;
    final sw = bounds.southWest;

    final latDiff = (ne.latitude - sw.latitude).abs();
    final lngDiff = (ne.longitude - sw.longitude).abs();

    final latZoom = log(360 / latDiff) / ln2;
    final lngZoom = log(360 / lngDiff) / ln2;

    final optimalZoom = min(latZoom, lngZoom) - 0.5;

    return min(
      optimalZoom,
      currentZoom + CLUSTER_ZOOM_INCREMENT,
    );
  }
}