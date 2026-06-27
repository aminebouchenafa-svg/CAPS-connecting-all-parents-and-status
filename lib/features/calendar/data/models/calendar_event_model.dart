import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/calendar_event.dart';

class CalendarEventModel extends CalendarEvent {
  const CalendarEventModel({
    required super.id,
    required super.householdId,
    required super.createdByUid,
    required super.title,
    super.description,
    required super.type,
    required super.startDate,
    required super.endDate,
    super.isAllDay,
    super.participantUids,
    required super.createdAt,
  });

  factory CalendarEventModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
    return CalendarEventModel(
      id: doc.id,
      householdId: data['householdId'] as String,
      createdByUid: data['createdByUid'] as String,
      title: data['title'] as String,
      description: data['description'] as String?,
      type: EventType.values.byName(data['type'] as String),
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
      isAllDay: data['isAllDay'] as bool? ?? false,
      participantUids:
          List<String>.from(data['participantUids'] as List? ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'householdId': householdId,
        'createdByUid': createdByUid,
        'title': title,
        'description': description,
        'type': type.name,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'isAllDay': isAllDay,
        'participantUids': participantUids,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory CalendarEventModel.fromEntity(CalendarEvent event) =>
      CalendarEventModel(
        id: event.id,
        householdId: event.householdId,
        createdByUid: event.createdByUid,
        title: event.title,
        description: event.description,
        type: event.type,
        startDate: event.startDate,
        endDate: event.endDate,
        isAllDay: event.isAllDay,
        participantUids: event.participantUids,
        createdAt: event.createdAt,
      );
}
