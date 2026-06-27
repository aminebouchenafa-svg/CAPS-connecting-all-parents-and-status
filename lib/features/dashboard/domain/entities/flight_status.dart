import 'package:equatable/equatable.dart';

enum FlightPhase {
  enVol,
  escale,
  repos,
  retour;

  String get label => switch (this) {
        FlightPhase.enVol => 'En Vol',
        FlightPhase.escale => 'Escale',
        FlightPhase.repos => 'Repos',
        FlightPhase.retour => 'Retour',
      };

  String get emoji => switch (this) {
        FlightPhase.enVol => '✈️',
        FlightPhase.escale => '🏨',
        FlightPhase.repos => '🏠',
        FlightPhase.retour => '🚗',
      };
}

class FlightStatus extends Equatable {
  final String id;
  final String pilotUid;
  final String householdId;
  final FlightPhase phase;
  final DateTime startTime;
  final DateTime? estimatedEndTime;
  final String? currentLocation;
  final String? flightNumber;
  final String? destination;
  final String? notes;
  final DateTime updatedAt;

  const FlightStatus({
    required this.id,
    required this.pilotUid,
    required this.householdId,
    required this.phase,
    required this.startTime,
    this.estimatedEndTime,
    this.currentLocation,
    this.flightNumber,
    this.destination,
    this.notes,
    required this.updatedAt,
  });

  bool get isAvailable => phase == FlightPhase.repos;

  Duration? get timeUntilAvailable {
    if (isAvailable) return Duration.zero;
    if (estimatedEndTime == null) return null;
    final remaining = estimatedEndTime!.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Duration get elapsed => DateTime.now().difference(startTime);

  @override
  List<Object?> get props => [
        id,
        pilotUid,
        householdId,
        phase,
        startTime,
        estimatedEndTime,
        currentLocation,
        flightNumber,
        destination,
        notes,
        updatedAt,
      ];
}
