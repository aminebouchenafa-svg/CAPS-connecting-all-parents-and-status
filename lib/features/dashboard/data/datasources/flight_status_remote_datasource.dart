import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firestore_paths.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/flight_status_model.dart';

class FlightStatusRemoteDatasource {
  final FirebaseFirestore _firestore;

  FlightStatusRemoteDatasource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<FlightStatusModel?> watchCurrentStatus(String householdId) {
    return _firestore
        .collection(FirestorePaths.flightStatuses(householdId))
        .orderBy('updatedAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      return FlightStatusModel.fromFirestore(snapshot.docs.first);
    });
  }

  Future<FlightStatusModel?> getCurrentStatus(String householdId) async {
    final snapshot = await _firestore
        .collection(FirestorePaths.flightStatuses(householdId))
        .orderBy('updatedAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return FlightStatusModel.fromFirestore(snapshot.docs.first);
  }

  Future<void> updateStatus(FlightStatusModel status) async {
    try {
      await _firestore
          .doc(FirestorePaths.flightStatus(status.householdId, status.id))
          .set(status.toFirestore(), SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur Firestore');
    }
  }

  Future<List<FlightStatusModel>> getStatusHistory(
    String householdId, {
    int limit = 20,
  }) async {
    final snapshot = await _firestore
        .collection(FirestorePaths.flightStatuses(householdId))
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => FlightStatusModel.fromFirestore(doc))
        .toList();
  }
}
