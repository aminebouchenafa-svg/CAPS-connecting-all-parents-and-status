import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/calendar_event.dart';
import '../../../roster/presentation/providers/roster_provider.dart';
import '../../../roster/domain/entities/roster_duty.dart';

// ---- Selected date ----
final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

// ---- Local calendar events (family, school, medical, etc.) ----
class CalendarEventsNotifier extends StateNotifier<List<CalendarEvent>> {
  CalendarEventsNotifier() : super([]);

  void addEvent(CalendarEvent event) {
    state = [...state, event];
  }

  void removeEvent(String id) {
    state = state.where((e) => e.id != id).toList();
  }

  void updateEvent(CalendarEvent updated) {
    state = state.map((e) => e.id == updated.id ? updated : e).toList();
  }
}

final calendarEventsNotifierProvider =
    StateNotifierProvider<CalendarEventsNotifier, List<CalendarEvent>>((ref) {
  return CalendarEventsNotifier();
});

// ---- Helper: filter calendar events for a given date ----
List<CalendarEvent> _eventsOnDate(List<CalendarEvent> events, DateTime date) {
  final dayStart = DateTime(date.year, date.month, date.day);
  final dayEnd = dayStart.add(const Duration(days: 1));
  return events.where((event) {
    return event.startDate.isBefore(dayEnd) && event.endDate.isAfter(dayStart);
  }).toList();
}

// ---- Helper: convert roster duties to read-only CalendarEvents ----
List<CalendarEvent> _rosterDutiesToEvents(List<RosterDuty> duties) {
  return duties.map((duty) {
    final title = duty.isFlight
        ? '${duty.flightNumber ?? "Vol"} ${duty.departure ?? ""} -> ${duty.arrival ?? ""}'
        : duty.type.label;
    return CalendarEvent(
      id: 'roster-${duty.date.millisecondsSinceEpoch}-${duty.flightNumber ?? duty.type.name}',
      householdId: '',
      createdByUid: 'roster',
      title: title,
      description: duty.notes,
      type: EventType.rotation,
      startDate: duty.checkIn ?? duty.date,
      endDate: duty.checkOut ?? duty.date.add(const Duration(hours: 12)),
      isAllDay: duty.checkIn == null,
      createdAt: duty.date,
    );
  }).toList();
}

// ---- Combined events for selected date: calendar + roster duties ----
final eventsForDateProvider = Provider<List<CalendarEvent>>((ref) {
  final selectedDate = ref.watch(selectedDateProvider);
  final calendarEvents = ref.watch(calendarEventsNotifierProvider);
  final roster = ref.watch(rosterProvider);

  // Calendar events for the selected date
  final dayCalendarEvents = _eventsOnDate(calendarEvents, selectedDate);

  // Roster duties for the selected date converted to CalendarEvents
  List<CalendarEvent> dayRosterEvents = [];
  if (roster != null) {
    final dutiesForDate = roster.dutiesForDate(selectedDate);
    dayRosterEvents = _rosterDutiesToEvents(dutiesForDate);
  }

  // Roster duties first, then family events
  return [...dayRosterEvents, ...dayCalendarEvents];
});
