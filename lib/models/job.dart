class Job {
  final String title;
  final String restaurant;
  final String type;
  final String description;
  final double latitude;
  final double longitude;
  final List<String> category;
  final String imageUrl; // Add this line

  Job({
    required this.title,
    required this.restaurant,
    required this.type,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.imageUrl, // Add this line
  });

  factory Job.fromFirestore(Map<String, dynamic> firestore) {
    return Job(
      title: firestore['title'] ?? '',
      restaurant: firestore['restaurant'] ?? '',
      type: firestore['type'] ?? '',
      description: firestore['description'] ?? '',
      latitude: firestore['latitude'] ?? 0.0,
      longitude: firestore['longitude'] ?? 0.0,
      category: List<String>.from(firestore['category'] ?? []),
      imageUrl: firestore['imageUrl'] ?? 'https://via.placeholder.com/50', // Add this line
    );
  }
}
