import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/flight_status.dart';
import '../../domain/repositories/flight_status_repository.dart';
import '../datasources/flight_status_remote_datasource.dart';
import '../models/flight_status_model.dart';

class FlightStatusRepositoryImpl implements FlightStatusRepository {
  final FlightStatusRemoteDatasource _datasource;

  FlightStatusRepositoryImpl(this._datasource);

  @override
  Stream<FlightStatus?> watchCurrentStatus(String householdId) {
    return _datasource.watchCurrentStatus(householdId);
  }

  @override
  Future<Result<FlightStatus>> getCurrentStatus(String householdId) async {
    try {
      final status = await _datasource.getCurrentStatus(householdId);
      if (status == null) {
        return const Error(ServerFailure('Aucun statut trouvé.'));
      }
      return Success(status);
    } on ServerException catch (e) {
      return Error(ServerFailure(e.message));
    } catch (e) {
      return Error(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> updateStatus(FlightStatus status) async {
    try {
      final model = FlightStatusModel.fromEntity(status);
      await _datasource.updateStatus(model);
      return const Success(null);
    } on ServerException catch (e) {
      return Error(ServerFailure(e.message));
    } catch (e) {
      return Error(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<FlightStatus>>> getStatusHistory(
    String householdId, {
    int limit = 20,
  }) async {
    try {
      final statuses =
          await _datasource.getStatusHistory(householdId, limit: limit);
      return Success(statuses);
    } on ServerException catch (e) {
      return Error(ServerFailure(e.message));
    } catch (e) {
      return Error(ServerFailure(e.toString()));
    }
  }
}
