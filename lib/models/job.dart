class Job {
  final String title;
  final String restaurant;
  final String type;
  final String description;
  final double latitude;
  final double longitude;
  final String category; // Add this line

  Job({
    required this.title,
    required this.restaurant,
    required this.type,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.category, // Add this line
  });

  // Update your method for creating a Job object from Firestore data to include the 'category'
  factory Job.fromFirestore(Map<String, dynamic> firestore) {
    return Job(
      title: firestore['title'] ?? '',
      restaurant: firestore['restaurant'] ?? '',
      type: firestore['type'] ?? '',
      description: firestore['description'] ?? '',
      latitude: firestore['latitude'] ?? 0.0,
      longitude: firestore['longitude'] ?? 0.0,
      category: firestore['category'] ?? '', // Add this line
    );
  }
}
