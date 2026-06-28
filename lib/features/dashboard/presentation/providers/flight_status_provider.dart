import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../roster/data/roster_parser.dart';
import '../../../roster/domain/entities/roster_duty.dart';
import '../../../roster/presentation/providers/roster_provider.dart';
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

final rosterFlightStatusProvider = Provider<FlightStatus?>((ref) {
  final roster = ref.watch(rosterProvider);
  if (roster == null) return null;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final todayDuties = roster.dutiesForDate(today);
  if (todayDuties.isEmpty) return null;

  final flights = todayDuties.where((d) => d.isFlight).toList();

  if (flights.isNotEmpty) {
    RosterDuty activeFlight = flights.first;
    FlightPhase phase = FlightPhase.enVol;

    for (final flight in flights) {
      if (flight.checkIn != null && flight.checkOut != null) {
        if (now.isBefore(flight.checkIn!)) {
          phase = FlightPhase.retour;
          activeFlight = flight;
          break;
        } else if (now.isBefore(flight.checkOut!)) {
          phase = FlightPhase.enVol;
          activeFlight = flight;
          break;
        } else {
          phase = FlightPhase.retour;
          activeFlight = flight;
        }
      }
    }

    if (flights.length > 1 && flights.first.checkOut != null && now.isAfter(flights.first.checkOut!) &&
        flights.last.checkIn != null && now.isBefore(flights.last.checkIn!)) {
      phase = FlightPhase.escale;
      activeFlight = flights.last;
    }

    final dep = activeFlight.departure ?? '';
    final arr = activeFlight.arrival ?? '';
    final depName = RosterParser.airportName(dep);
    final arrName = RosterParser.airportName(arr);

    String? location;
    if (phase == FlightPhase.enVol) {
      location = '$depName ($dep)';
    } else if (phase == FlightPhase.escale) {
      final prevFlight = flights.first;
      final escaleCode = prevFlight.arrival ?? '';
      location = '${RosterParser.airportName(escaleCode)} ($escaleCode)';
    } else {
      location = '$arrName ($arr)';
    }

    final lastFlightEnd = flights.last.checkOut ?? DateTime(today.year, today.month, today.day, 18, 0);

    return FlightStatus(
      id: 'roster-status',
      pilotUid: 'demo-amine',
      householdId: 'famille-bouchenafa',
      phase: phase,
      startTime: activeFlight.checkIn ?? today,
      estimatedEndTime: lastFlightEnd,
      currentLocation: location,
      flightNumber: activeFlight.flightNumber,
      destination: '$arrName ($arr)',
      notes: _buildFlightNotes(activeFlight),
      updatedAt: now,
    );
  }

  final duty = todayDuties.first;
  if (duty.type == DutyType.off || duty.type == DutyType.rest) {
    final nextFlightDay = _findNextFlightDay(roster, today);
    String? notes;
    if (nextFlightDay != null) {
      final arrName = RosterParser.airportName(nextFlightDay.arrival ?? '');
      notes = 'Prochain vol : ${nextFlightDay.flightNumber} '
          'vers $arrName le ${nextFlightDay.date.day}/${nextFlightDay.date.month}';
    }

    return FlightStatus(
      id: 'roster-status',
      pilotUid: 'demo-amine',
      householdId: 'famille-bouchenafa',
      phase: FlightPhase.repos,
      startTime: today,
      estimatedEndTime: nextFlightDay?.checkIn,
      currentLocation: 'Alger - Maison',
      notes: notes,
      updatedAt: now,
    );
  }

  if (duty.type == DutyType.standby) {
    return FlightStatus(
      id: 'roster-status',
      pilotUid: 'demo-amine',
      householdId: 'famille-bouchenafa',
      phase: FlightPhase.repos,
      startTime: today,
      currentLocation: 'Alger - Standby',
      notes: 'En attente d\'affectation',
      updatedAt: now,
    );
  }

  return null;
});

String _buildFlightNotes(RosterDuty flight) {
  final dep = RosterParser.airportName(flight.departure ?? '');
  final arr = RosterParser.airportName(flight.arrival ?? '');
  final buf = StringBuffer('$dep → $arr');

  if (flight.checkIn != null) {
    buf.write('\nDépart prévu : ${_formatTime(flight.checkIn!)}');
  }
  if (flight.checkOut != null) {
    buf.write('\nArrivée prévue : ${_formatTime(flight.checkOut!)}');
  }
  return buf.toString();
}

String _formatTime(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}h${dt.minute.toString().padLeft(2, '0')}';

RosterDuty? _findNextFlightDay(Roster roster, DateTime fromDate) {
  for (final duty in roster.duties) {
    if (duty.date.isAfter(fromDate) && duty.isFlight) {
      return duty;
    }
  }
  return null;
}
