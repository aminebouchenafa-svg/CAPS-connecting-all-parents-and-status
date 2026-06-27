import '../../../../core/utils/result.dart';
import '../entities/flight_status.dart';
import '../repositories/flight_status_repository.dart';

class UpdateFlightStatusUseCase {
  final FlightStatusRepository _repository;

  UpdateFlightStatusUseCase(this._repository);

  Future<Result<void>> call(FlightStatus status) {
    return _repository.updateStatus(status);
  }
}
