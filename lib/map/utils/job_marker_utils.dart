import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' show pi, sin, cos, atan2, sqrt;

class JobMarkerUtils {
  static IconData getJobIcon(List<String> categories) {
    if (categories.contains('Cook')) return Icons.restaurant;
    if (categories.contains('Bar')) return Icons.local_bar;
    if (categories.contains('Service')) return Icons.room_service;
    if (categories.contains('Manager')) return Icons.manage_accounts;
    if (categories.contains('Delivery')) return Icons.delivery_dining;
    if (categories.contains('Cleaning')) return Icons.cleaning_services;
    if (categories.contains('Sommelier')) return Icons.wine_bar;
    return Icons.work;
  }

  static Color getJobColor(List<String> categories) {
    if (categories.contains('Cook')) return Colors.orange;
    if (categories.contains('Bar')) return Colors.purple;
    if (categories.contains('Service')) return Colors.blue;
    if (categories.contains('Manager')) return Colors.green;
    if (categories.contains('Delivery')) return Colors.red;
    if (categories.contains('Cleaning')) return Colors.teal;
    if (categories.contains('Sommelier')) return Colors.deepPurple;
    return Colors.grey;
  }

  static double calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371;
    final lat1 = point1.latitude * pi / 180;
    final lat2 = point2.latitude * pi / 180;
    final dLat = (point2.latitude - point1.latitude) * pi / 180;
    final dLon = (point2.longitude - point1.longitude) * pi / 180;

    final a = sin(dLat/2) * sin(dLat/2) +
        cos(lat1) * cos(lat2) *
            sin(dLon/2) * sin(dLon/2);
    final c = 2 * atan2(sqrt(a), sqrt(1-a));

    return earthRadius * c;
  }

  static Widget buildLegendItem(IconData icon, String label, Color color) {
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