import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/flight_status_remote_datasource.dart';
import '../../data/repositories/flight_status_repository_impl.dart';
import '../../domain/entities/flight_status.dart';
import '../../domain/repositories/flight_status_repository.dart';

final flightStatusDatasourceProvider =
    Provider<FlightStatusRemoteDatasource>((ref) {
  return FlightStatusRemoteDatasource(firestore: FirebaseFirestore.instance);
});

final flightStatusRepositoryProvider =
    Provider<FlightStatusRepository>((ref) {
  return FlightStatusRepositoryImpl(
      ref.read(flightStatusDatasourceProvider));
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
