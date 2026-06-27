import 'package:equatable/equatable.dart';

enum EventType {
  rotation,
  family,
  school,
  medical,
  activity;

  String get label => switch (this) {
        EventType.rotation => 'Rotation',
        EventType.family => 'Famille',
        EventType.school => 'École',
        EventType.medical => 'Médical',
        EventType.activity => 'Activité',
      };
}

class CalendarEvent extends Equatable {
  final String id;
  final String householdId;
  final String createdByUid;
  final String title;
  final String? description;
  final EventType type;
  final DateTime startDate;
  final DateTime endDate;
  final bool isAllDay;
  final List<String> participantUids;
  final DateTime createdAt;

  const CalendarEvent({
    required this.id,
    required this.householdId,
    required this.createdByUid,
    required this.title,
    this.description,
    required this.type,
    required this.startDate,
    required this.endDate,
    this.isAllDay = false,
    this.participantUids = const [],
    required this.createdAt,
  });

  bool get isRotation => type == EventType.rotation;

  bool get isOngoing {
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate);
  }

  Duration get duration => endDate.difference(startDate);

  @override
  List<Object?> get props => [
        id,
        householdId,
        createdByUid,
        title,
        description,
        type,
        startDate,
        endDate,
        isAllDay,
        participantUids,
        createdAt,
      ];
}
