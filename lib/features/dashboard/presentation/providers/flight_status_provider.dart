import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/demo_flight_status_repository.dart';
import '../../domain/entities/flight_status.dart';
import '../../domain/repositories/flight_status_repository.dart';

final flightStatusRepositoryProvider =
    Provider<FlightStatusRepository>((ref) {
  return DemoFlightStatusRepository();
});

final currentFlightStatusProvider =
    StreamProvider.family<FlightStatus?, String>((ref, householdId) {
  return ref
      .watch(flightStatusRepositoryProvider)
      .watchCurrentStatus(householdId);
});

final flightStatusHistoryProvider = FutureProvider.family<List<FlightStatus>,
    ({String householdId, int limit})>((ref, params) async {
  final result = await ref
      .read(flightStatusRepositoryProvider)
      .getStatusHistory(params.householdId, limit: params.limit);
  return result.when(
    success: (data) => data,
    failure: (failure) => throw Exception(failure.message),
  );
});
