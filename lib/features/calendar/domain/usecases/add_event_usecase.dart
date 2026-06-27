import '../../../../core/utils/result.dart';
import '../entities/calendar_event.dart';
import '../repositories/calendar_repository.dart';

class AddEventUseCase {
  final CalendarRepository _repository;

  AddEventUseCase(this._repository);

  Future<Result<void>> call(CalendarEvent event) {
    return _repository.addEvent(event);
  }
}
