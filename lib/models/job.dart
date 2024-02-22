class Job {
  final String title;
  final String restaurant;
  final String type;
  final String description;
  final String postedBy;
  final double latitude;
  final double longitude;

  Job({
    required this.title,
    required this.restaurant,
    required this.type,
    required this.description,
    required this.postedBy,
    required this.latitude,
    required this.longitude,
  });

  factory Job.fromFirestore(Map<String, dynamic> doc) {
    return Job(
      title: doc['title'] ?? '',
      restaurant: doc['restaurant'] ?? '',
      type: doc['type'] ?? '',
      description: doc['description'] ?? '',
      postedBy: doc['postedBy'] ?? '',
      latitude: doc['latitude'].toDouble(),
      longitude: doc['longitude'].toDouble(),
    );
  }
}
