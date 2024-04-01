import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> migrateAndCleanDatabase() async {
  var collection = FirebaseFirestore.instance.collection('JobListings');
  var snapshot = await collection.get();
  // Define the cutoff date for deleting old documents
  var cutoffDate = DateTime(2021, 1, 1); // Example: January 1, 2021

  for (var doc in snapshot.docs) {
    // Migrate 'category' from string to array if necessary
    var category = doc['category'];
    if (category is String) {
      await doc.reference.update({
        'category': [category]
      });
      print('Migrated category for document ID: ${doc.id}');
    }

    // Check and delete old documents
    var createdAt = doc['created_at'] as Timestamp?;
    if (createdAt != null && createdAt.toDate().isBefore(cutoffDate)) {
      await doc.reference.delete();
      print('Deleted old document with ID: ${doc.id}');
    }
  }
}

void main() async {
  // Make sure to initialize Firebase here if needed
  await migrateAndCleanDatabase();
}
