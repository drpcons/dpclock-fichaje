import 'package:cloud_firestore/cloud_firestore.dart';

class TimeTrackingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Clock in
  Future<void> clockIn(String userId) async {
    final now = DateTime.now();
    await _firestore.collection('time_records').add({
      'userId': userId,
      'clockIn': now,
      'clockOut': null,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Clock out
  Future<void> clockOut(String recordId) async {
    final now = DateTime.now();
    await _firestore.collection('time_records').doc(recordId).update({
      'clockOut': now,
      'status': 'completed',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Get active time record
  Future<DocumentSnapshot?> getActiveTimeRecord(String userId) async {
    final querySnapshot = await _firestore
        .collection('time_records')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      return null;
    }
    return querySnapshot.docs.first;
  }

  // Get time records for user
  Stream<QuerySnapshot> getUserTimeRecords(String userId) {
    return _firestore
        .collection('time_records')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
} 