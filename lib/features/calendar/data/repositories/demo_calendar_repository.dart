import '../../../../core/constants/demo_data.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/calendar_event.dart';
import '../../domain/repositories/calendar_repository.dart';

class DemoCalendarRepository implements CalendarRepository {
  final List<CalendarEvent> _events = List.from(DemoData.events);

  @override
  Stream<List<CalendarEvent>> watchEvents(
    String householdId, {
    DateTime? from,
    DateTime? to,
  }) {
    return Stream.value(_filteredEvents(from, to)).asBroadcastStream();
  }

  @override
  Future<Result<void>> addEvent(CalendarEvent event) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _events.add(event);
    return const Success(null);
  }

  @override
  Future<Result<void>> updateEvent(CalendarEvent event) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _events.indexWhere((e) => e.id == event.id);
    if (index != -1) _events[index] = event;
    return const Success(null);
  }

  @override
  Future<Result<void>> deleteEvent(String householdId, String eventId) async {
    _events.removeWhere((e) => e.id == eventId);
    return const Success(null);
  }

  @override
  Future<Result<List<CalendarEvent>>> getEventsForDate(
    String householdId,
    DateTime date,
  ) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return Success(_filteredEvents(start, end));
  }

  List<CalendarEvent> _filteredEvents(DateTime? from, DateTime? to) {
    return _events.where((e) {
      if (from != null && e.endDate.isBefore(from)) return false;
      if (to != null && e.startDate.isAfter(to)) return false;
      return true;
    }).toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
  }
}
