class Application {
  final String id;
  final String name;
  final String email;
  final String phoneNumber;
  final String message;
  final String cvUrl;
  final String status;

  Application({
    required this.id,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.message,
    required this.cvUrl,
    required this.status,
  });

  factory Application.fromFirestore(Map<String, dynamic> firestore, String id) {
    return Application(
      id: id,
      name: firestore['name'] ?? '',
      email: firestore['email'] ?? '',
      phoneNumber: firestore['phoneNumber'] ?? '',
      message: firestore['message'] ?? '',
      cvUrl: firestore['cvUrl'] ?? '',
      status: firestore['status'] ?? 'pending',
    );
  }
}
