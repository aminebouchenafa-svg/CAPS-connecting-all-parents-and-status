import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/calendar_remote_datasource.dart';
import '../../data/repositories/calendar_repository_impl.dart';
import '../../domain/entities/calendar_event.dart';
import '../../domain/repositories/calendar_repository.dart';

final calendarDatasourceProvider = Provider<CalendarRemoteDatasource>((ref) {
  return CalendarRemoteDatasource(firestore: FirebaseFirestore.instance);
});

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  return CalendarRepositoryImpl(ref.read(calendarDatasourceProvider));
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
    final eventDay = DateTime(
        event.startDate.year, event.startDate.month, event.startDate.day);
    final selected = DateTime(
        selectedDate.year, selectedDate.month, selectedDate.day);
    return eventDay == selected ||
        (event.startDate.isBefore(selected.add(const Duration(days: 1))) &&
            event.endDate.isAfter(selected));
  }).toList();
});
