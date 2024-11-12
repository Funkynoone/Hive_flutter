class Job {
  final String id;
  final String ownerId;
  final String title;
  final String restaurant;
  final String type;
  final String description;
  final String requirements;  // Added this
  double latitude;
  double longitude;
  final List<String> category;
  final String imageUrl;
  final String? salary;
  final String? salaryType;
  final bool salaryNotGiven;

  Job({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.restaurant,
    required this.type,
    required this.description,
    required this.requirements,  // Added this
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.imageUrl,
    this.salary,
    this.salaryType,
    this.salaryNotGiven = false,
  });

  factory Job.fromFirestore(Map<String, dynamic> firestore, String id) {
    return Job(
      id: id,
      ownerId: firestore['ownerId'] ?? '',
      title: firestore['title'] ?? '',
      restaurant: firestore['restaurant'] ?? '',
      type: firestore['type'] ?? '',
      description: firestore['description'] ?? '',
      requirements: firestore['requirements'] ?? '',  // Added this
      latitude: firestore['latitude'] ?? 0.0,
      longitude: firestore['longitude'] ?? 0.0,
      category: List<String>.from(firestore['category'] ?? []),
      imageUrl: firestore['imageUrl'] ?? 'https://via.placeholder.com/50',
      salary: firestore['salary'],
      salaryType: firestore['salaryType'],
      salaryNotGiven: firestore['salaryNotGiven'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ownerId': ownerId,
      'title': title,
      'restaurant': restaurant,
      'type': type,
      'description': description,
      'requirements': requirements,  // Added this
      'latitude': latitude,
      'longitude': longitude,
      'category': category,
      'imageUrl': imageUrl,
      'salary': salary,
      'salaryType': salaryType,
      'salaryNotGiven': salaryNotGiven,
    };
  }
}