import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/demo_calendar_repository.dart';
import '../../domain/entities/calendar_event.dart';
import '../../domain/repositories/calendar_repository.dart';

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  return DemoCalendarRepository();
});

final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final calendarEventsProvider =
    StreamProvider.family<List<CalendarEvent>, String>((ref, householdId) {
  final selectedDate = ref.watch(selectedDateProvider);
  final startOfMonth =
      DateTime(selectedDate.year, selectedDate.month, 1);
  final endOfMonth =
      DateTime(selectedDate.year, selectedDate.month + 1, 0, 23, 59, 59);

  return ref
      .watch(calendarRepositoryProvider)
      .watchEvents(householdId, from: startOfMonth, to: endOfMonth);
});

final eventsForSelectedDateProvider =
    Provider.family<List<CalendarEvent>, List<CalendarEvent>>((ref, allEvents) {
  final selectedDate = ref.watch(selectedDateProvider);
  return allEvents.where((event) {
    final eventStart = DateTime(
        event.startDate.year, event.startDate.month, event.startDate.day);
    final selected =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    return eventStart == selected ||
        (event.startDate.isBefore(selected.add(const Duration(days: 1))) &&
            event.endDate.isAfter(selected));
  }).toList();
});
