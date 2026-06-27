import 'dart:async';

import '../../../../core/constants/demo_data.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/flight_status.dart';
import '../../domain/repositories/flight_status_repository.dart';

class DemoFlightStatusRepository implements FlightStatusRepository {
  FlightStatus _current = DemoData.currentStatus;
  final _controller = StreamController<FlightStatus?>.broadcast();

  @override
  Stream<FlightStatus?> watchCurrentStatus(String householdId) {
    return Stream.value(_current).asBroadcastStream();
  }

  @override
  Future<Result<FlightStatus>> getCurrentStatus(String householdId) async {
    return Success(_current);
  }

  @override
  Future<Result<void>> updateStatus(FlightStatus status) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _current = status;
    _controller.add(_current);
    return const Success(null);
  }

  @override
  Future<Result<List<FlightStatus>>> getStatusHistory(
    String householdId, {
    int limit = 20,
  }) async {
    return Success(DemoData.statusHistory);
  }
}
