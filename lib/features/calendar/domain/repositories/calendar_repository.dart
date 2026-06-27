import '../../../../core/utils/result.dart';
import '../entities/calendar_event.dart';

abstract interface class CalendarRepository {
  Stream<List<CalendarEvent>> watchEvents(
    String householdId, {
    DateTime? from,
    DateTime? to,
  });
  Future<Result<void>> addEvent(CalendarEvent event);
  Future<Result<void>> updateEvent(CalendarEvent event);
  Future<Result<void>> deleteEvent(String householdId, String eventId);
  Future<Result<List<CalendarEvent>>> getEventsForDate(
    String householdId,
    DateTime date,
  );
}
