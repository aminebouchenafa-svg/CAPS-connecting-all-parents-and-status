import '../entities/calendar_event.dart';
import '../repositories/calendar_repository.dart';

class WatchEventsUseCase {
  final CalendarRepository _repository;

  WatchEventsUseCase(this._repository);

  Stream<List<CalendarEvent>> call(
    String householdId, {
    DateTime? from,
    DateTime? to,
  }) {
    return _repository.watchEvents(householdId, from: from, to: to);
  }
}
