import '../entities/flight_status.dart';
import '../repositories/flight_status_repository.dart';

class WatchFlightStatusUseCase {
  final FlightStatusRepository _repository;

  WatchFlightStatusUseCase(this._repository);

  Stream<FlightStatus?> call(String householdId) {
    return _repository.watchCurrentStatus(householdId);
  }
}
