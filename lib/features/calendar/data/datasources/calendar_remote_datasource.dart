import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firestore_paths.dart';
import '../../../../core/errors/exceptions.dart';
import '../models/calendar_event_model.dart';

class CalendarRemoteDatasource {
  final FirebaseFirestore _firestore;

  CalendarRemoteDatasource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Stream<List<CalendarEventModel>> watchEvents(
    String householdId, {
    DateTime? from,
    DateTime? to,
  }) {
    Query query = _firestore
        .collection(FirestorePaths.calendarEvents(householdId))
        .orderBy('startDate');

    if (from != null) {
      query = query.where('startDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(from));
    }
    if (to != null) {
      query =
          query.where('startDate', isLessThanOrEqualTo: Timestamp.fromDate(to));
    }

    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => CalendarEventModel.fromFirestore(doc))
        .toList());
  }

  Future<void> addEvent(CalendarEventModel event) async {
    try {
      await _firestore
          .collection(FirestorePaths.calendarEvents(event.householdId))
          .doc(event.id)
          .set(event.toFirestore());
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur Firestore');
    }
  }

  Future<void> updateEvent(CalendarEventModel event) async {
    try {
      await _firestore
          .doc(FirestorePaths.calendarEvent(event.householdId, event.id))
          .update(event.toFirestore());
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur Firestore');
    }
  }

  Future<void> deleteEvent(String householdId, String eventId) async {
    try {
      await _firestore
          .doc(FirestorePaths.calendarEvent(householdId, eventId))
          .delete();
    } on FirebaseException catch (e) {
      throw ServerException(e.message ?? 'Erreur Firestore');
    }
  }

  Future<List<CalendarEventModel>> getEventsForDate(
    String householdId,
    DateTime date,
  ) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await _firestore
        .collection(FirestorePaths.calendarEvents(householdId))
        .where('startDate',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('startDate', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('startDate')
        .get();

    return snapshot.docs
        .map((doc) => CalendarEventModel.fromFirestore(doc))
        .toList();
  }
}
