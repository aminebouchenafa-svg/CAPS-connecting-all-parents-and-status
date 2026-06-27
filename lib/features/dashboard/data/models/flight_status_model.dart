import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/flight_status.dart';

class FlightStatusModel extends FlightStatus {
  const FlightStatusModel({
    required super.id,
    required super.pilotUid,
    required super.householdId,
    required super.phase,
    required super.startTime,
    super.estimatedEndTime,
    super.currentLocation,
    super.flightNumber,
    super.destination,
    super.notes,
    required super.updatedAt,
  });

  factory FlightStatusModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
    return FlightStatusModel(
      id: doc.id,
      pilotUid: data['pilotUid'] as String,
      householdId: data['householdId'] as String,
      phase: FlightPhase.values.byName(data['phase'] as String),
      startTime: (data['startTime'] as Timestamp).toDate(),
      estimatedEndTime: data['estimatedEndTime'] != null
          ? (data['estimatedEndTime'] as Timestamp).toDate()
          : null,
      currentLocation: data['currentLocation'] as String?,
      flightNumber: data['flightNumber'] as String?,
      destination: data['destination'] as String?,
      notes: data['notes'] as String?,
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'pilotUid': pilotUid,
        'householdId': householdId,
        'phase': phase.name,
        'startTime': Timestamp.fromDate(startTime),
        'estimatedEndTime': estimatedEndTime != null
            ? Timestamp.fromDate(estimatedEndTime!)
            : null,
        'currentLocation': currentLocation,
        'flightNumber': flightNumber,
        'destination': destination,
        'notes': notes,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory FlightStatusModel.fromEntity(FlightStatus status) =>
      FlightStatusModel(
        id: status.id,
        pilotUid: status.pilotUid,
        householdId: status.householdId,
        phase: status.phase,
        startTime: status.startTime,
        estimatedEndTime: status.estimatedEndTime,
        currentLocation: status.currentLocation,
        flightNumber: status.flightNumber,
        destination: status.destination,
        notes: status.notes,
        updatedAt: status.updatedAt,
      );
}
