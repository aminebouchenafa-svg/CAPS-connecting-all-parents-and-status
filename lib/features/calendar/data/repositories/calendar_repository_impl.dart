import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/calendar_event.dart';
import '../../domain/repositories/calendar_repository.dart';
import '../datasources/calendar_remote_datasource.dart';
import '../models/calendar_event_model.dart';

class CalendarRepositoryImpl implements CalendarRepository {
  final CalendarRemoteDatasource _datasource;

  CalendarRepositoryImpl(this._datasource);

  @override
  Stream<List<CalendarEvent>> watchEvents(
    String householdId, {
    DateTime? from,
    DateTime? to,
  }) {
    return _datasource.watchEvents(householdId, from: from, to: to);
  }

  @override
  Future<Result<void>> addEvent(CalendarEvent event) async {
    try {
      final model = CalendarEventModel.fromEntity(event);
      await _datasource.addEvent(model);
      return const Success(null);
    } on ServerException catch (e) {
      return Error(ServerFailure(e.message));
    } catch (e) {
      return Error(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> updateEvent(CalendarEvent event) async {
    try {
      final model = CalendarEventModel.fromEntity(event);
      await _datasource.updateEvent(model);
      return const Success(null);
    } on ServerException catch (e) {
      return Error(ServerFailure(e.message));
    } catch (e) {
      return Error(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> deleteEvent(String householdId, String eventId) async {
    try {
      await _datasource.deleteEvent(householdId, eventId);
      return const Success(null);
    } on ServerException catch (e) {
      return Error(ServerFailure(e.message));
    } catch (e) {
      return Error(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<CalendarEvent>>> getEventsForDate(
    String householdId,
    DateTime date,
  ) async {
    try {
      final events = await _datasource.getEventsForDate(householdId, date);
      return Success(events);
    } on ServerException catch (e) {
      return Error(ServerFailure(e.message));
    } catch (e) {
      return Error(ServerFailure(e.toString()));
    }
  }
}
