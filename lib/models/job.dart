class Job {
  final String id;
  final String ownerId;  // Add this field
  final String title;
  final String restaurant;
  final String type;
  final String description;
  double latitude;
  double longitude;
  final List<String> category;
  final String imageUrl;

  Job({
    required this.id,
    required this.ownerId,  // Add this
    required this.title,
    required this.restaurant,
    required this.type,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.imageUrl,
  });

  factory Job.fromFirestore(Map<String, dynamic> firestore, String id) {
    return Job(
      id: id,
      ownerId: firestore['ownerId'] ?? '',  // Add this
      title: firestore['title'] ?? '',
      restaurant: firestore['restaurant'] ?? '',
      type: firestore['type'] ?? '',
      description: firestore['description'] ?? '',
      latitude: firestore['latitude'] ?? 0.0,
      longitude: firestore['longitude'] ?? 0.0,
      category: List<String>.from(firestore['category'] ?? []),
      imageUrl: firestore['imageUrl'] ?? 'https://via.placeholder.com/50',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,  // Add this
      'title': title,
      'restaurant': restaurant,
      'type': type,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'category': category,
      'imageUrl': imageUrl,
    };
  }
}