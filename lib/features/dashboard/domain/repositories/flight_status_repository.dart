import '../../../../core/utils/result.dart';
import '../entities/flight_status.dart';

abstract interface class FlightStatusRepository {
  Stream<FlightStatus?> watchCurrentStatus(String householdId);
  Future<Result<FlightStatus>> getCurrentStatus(String householdId);
  Future<Result<void>> updateStatus(FlightStatus status);
  Future<Result<List<FlightStatus>>> getStatusHistory(
    String householdId, {
    int limit = 20,
  });
}
