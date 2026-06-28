import 'package:equatable/equatable.dart';

enum DutyType {
  flight,
  standby,
  rest,
  training,
  off,
  simulator,
  deadhead;

  String get label => switch (this) {
        DutyType.flight => 'Vol',
        DutyType.standby => 'Standby',
        DutyType.rest => 'Repos',
        DutyType.training => 'Formation',
        DutyType.off => 'OFF',
        DutyType.simulator => 'Simulateur',
        DutyType.deadhead => 'Déplacement',
      };
}

class RosterDuty extends Equatable {
  final DateTime date;
  final DutyType type;
  final String? flightNumber;
  final String? departure;
  final String? arrival;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final String? notes;
  final String? activityCode;

  const RosterDuty({
    required this.date,
    required this.type,
    this.flightNumber,
    this.departure,
    this.arrival,
    this.checkIn,
    this.checkOut,
    this.notes,
    this.activityCode,
  });

  bool get isFlight => type == DutyType.flight;
  bool get isOff => type == DutyType.off || type == DutyType.rest;

  @override
  List<Object?> get props =>
      [date, type, flightNumber, departure, arrival, checkIn, checkOut, notes, activityCode];
}

class Roster extends Equatable {
  final String pilotName;
  final String pilotId;
  final String base;
  final String aircraft;
  final DateTime periodStart;
  final DateTime periodEnd;
  final List<RosterDuty> duties;
  final double totalBlockHours;
  final double totalDutyHours;
  final int totalLandings;
  final int offDays;
  final int flightDays;
  final Map<String, String> allStats;
  final Map<String, String> codeExplanations;

  const Roster({
    required this.pilotName,
    required this.pilotId,
    required this.base,
    required this.aircraft,
    required this.periodStart,
    required this.periodEnd,
    required this.duties,
    this.totalBlockHours = 0,
    this.totalDutyHours = 0,
    this.totalLandings = 0,
    this.offDays = 0,
    this.flightDays = 0,
    this.allStats = const {},
    this.codeExplanations = const {},
  });

  List<RosterDuty> get flights =>
      duties.where((d) => d.isFlight).toList();

  List<RosterDuty> get offDuties =>
      duties.where((d) => d.isOff).toList();

  List<RosterDuty> dutiesForDate(DateTime date) =>
      duties.where((d) =>
          d.date.year == date.year &&
          d.date.month == date.month &&
          d.date.day == date.day).toList();

  @override
  List<Object?> get props => [pilotName, pilotId, periodStart, periodEnd, duties];
}
