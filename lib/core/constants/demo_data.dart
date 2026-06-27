import '../../features/auth/domain/entities/app_user.dart';
import '../../features/calendar/domain/entities/calendar_event.dart';
import '../../features/dashboard/domain/entities/flight_status.dart';
import '../../features/roster/domain/entities/roster_duty.dart';

abstract final class DemoData {
  static const String householdId = 'famille-bouchenafa';

  static final AppUser pilot = AppUser(
    uid: 'demo-amine',
    email: 'amine@caps.app',
    displayName: 'Amine',
    role: UserRole.pilot,
    householdId: householdId,
    createdAt: DateTime(2024, 1, 1),
  );

  static final AppUser spouse = AppUser(
    uid: 'demo-amina',
    email: 'amina@caps.app',
    displayName: 'Amina',
    role: UserRole.spouse,
    householdId: householdId,
    createdAt: DateTime(2024, 1, 1),
  );

  static final FlightStatus currentStatus = FlightStatus(
    id: 'demo-status-1',
    pilotUid: 'demo-amine',
    householdId: householdId,
    phase: FlightPhase.escale,
    startTime: DateTime.now().subtract(const Duration(hours: 3)),
    estimatedEndTime: DateTime.now().add(const Duration(hours: 8)),
    currentLocation: 'Istanbul (IST)',
    flightNumber: 'AH 1070',
    destination: 'Alger (ALG)',
    notes: 'Vol retour demain matin inchallah. Je vous appelle ce soir !',
    updatedAt: DateTime.now(),
  );

  static List<FlightStatus> get statusHistory => [
        currentStatus,
        FlightStatus(
          id: 'demo-status-2',
          pilotUid: 'demo-amine',
          householdId: householdId,
          phase: FlightPhase.enVol,
          startTime: DateTime.now().subtract(const Duration(hours: 10)),
          estimatedEndTime:
              DateTime.now().subtract(const Duration(hours: 3)),
          currentLocation: 'En route',
          flightNumber: 'AH 1069',
          destination: 'Istanbul (IST)',
          updatedAt: DateTime.now().subtract(const Duration(hours: 10)),
        ),
        FlightStatus(
          id: 'demo-status-3',
          pilotUid: 'demo-amine',
          householdId: householdId,
          phase: FlightPhase.repos,
          startTime: DateTime.now().subtract(const Duration(days: 2)),
          estimatedEndTime:
              DateTime.now().subtract(const Duration(hours: 14)),
          currentLocation: 'Alger - Maison',
          updatedAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
      ];

  static List<CalendarEvent> get events => [
        CalendarEvent(
          id: 'evt-1',
          householdId: householdId,
          createdByUid: 'demo-amine',
          title: 'Rotation Istanbul',
          type: EventType.rotation,
          startDate: DateTime.now().subtract(const Duration(hours: 10)),
          endDate: DateTime.now().add(const Duration(hours: 14)),
          createdAt: DateTime.now().subtract(const Duration(days: 7)),
        ),
        CalendarEvent(
          id: 'evt-2',
          householdId: householdId,
          createdByUid: 'demo-amina',
          title: 'Fête de l\'école Ilyane',
          description: 'Spectacle de fin d\'année',
          type: EventType.school,
          startDate: DateTime.now().add(const Duration(days: 3, hours: 14)),
          endDate: DateTime.now().add(const Duration(days: 3, hours: 16)),
          createdAt: DateTime.now().subtract(const Duration(days: 5)),
        ),
        CalendarEvent(
          id: 'evt-3',
          householdId: householdId,
          createdByUid: 'demo-amina',
          title: 'RDV pédiatre Yanis',
          description: 'Contrôle de routine',
          type: EventType.medical,
          startDate: DateTime.now().add(const Duration(days: 5, hours: 10)),
          endDate:
              DateTime.now().add(const Duration(days: 5, hours: 10, minutes: 30)),
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
        CalendarEvent(
          id: 'evt-4',
          householdId: householdId,
          createdByUid: 'demo-amine',
          title: 'Rotation Paris CDG',
          type: EventType.rotation,
          startDate: DateTime.now().add(const Duration(days: 7)),
          endDate: DateTime.now().add(const Duration(days: 10)),
          createdAt: DateTime.now(),
        ),
        CalendarEvent(
          id: 'evt-5',
          householdId: householdId,
          createdByUid: 'demo-amina',
          title: 'Anniversaire Ilyane',
          description: 'Préparer le gâteau et les décos !',
          type: EventType.family,
          startDate: DateTime.now().add(const Duration(days: 12, hours: 14)),
          endDate: DateTime.now().add(const Duration(days: 12, hours: 18)),
          isAllDay: false,
          createdAt: DateTime.now(),
        ),
      ];

  static Roster get demoRoster => Roster(
        pilotName: 'BOUCHENAFA Mohamed Amine',
        pilotId: '30048',
        base: 'ALG',
        aircraft: 'B738',
        periodStart: DateTime(2026, 6, 1),
        periodEnd: DateTime(2026, 6, 30),
        totalBlockHours: 53.73,
        totalDutyHours: 97.47,
        totalLandings: 21,
        offDays: 13,
        flightDays: 10,
        duties: [
          RosterDuty(date: DateTime(2026, 6, 1), type: DutyType.flight, flightNumber: 'AH 1069', departure: 'ALG', arrival: 'IST', checkIn: DateTime(2026, 6, 1, 5, 30), checkOut: DateTime(2026, 6, 1, 10, 15)),
          RosterDuty(date: DateTime(2026, 6, 2), type: DutyType.flight, flightNumber: 'AH 1070', departure: 'IST', arrival: 'ALG', checkIn: DateTime(2026, 6, 2, 11, 0), checkOut: DateTime(2026, 6, 2, 15, 45)),
          RosterDuty(date: DateTime(2026, 6, 3), type: DutyType.off, notes: 'Repos'),
          RosterDuty(date: DateTime(2026, 6, 4), type: DutyType.off, notes: 'Repos'),
          RosterDuty(date: DateTime(2026, 6, 5), type: DutyType.flight, flightNumber: 'AH 3017', departure: 'ALG', arrival: 'CDG', checkIn: DateTime(2026, 6, 5, 6, 0), checkOut: DateTime(2026, 6, 5, 9, 30)),
          RosterDuty(date: DateTime(2026, 6, 6), type: DutyType.flight, flightNumber: 'AH 3018', departure: 'CDG', arrival: 'ALG', checkIn: DateTime(2026, 6, 6, 10, 30), checkOut: DateTime(2026, 6, 6, 14, 0)),
          RosterDuty(date: DateTime(2026, 6, 7), type: DutyType.off, notes: 'Repos'),
          RosterDuty(date: DateTime(2026, 6, 8), type: DutyType.off, notes: 'Repos'),
          RosterDuty(date: DateTime(2026, 6, 9), type: DutyType.flight, flightNumber: 'AH 4002', departure: 'ALG', arrival: 'MXP', checkIn: DateTime(2026, 6, 9, 7, 0), checkOut: DateTime(2026, 6, 9, 10, 0)),
          RosterDuty(date: DateTime(2026, 6, 9), type: DutyType.flight, flightNumber: 'AH 4003', departure: 'MXP', arrival: 'ALG', checkIn: DateTime(2026, 6, 9, 11, 30), checkOut: DateTime(2026, 6, 9, 14, 30)),
          RosterDuty(date: DateTime(2026, 6, 10), type: DutyType.off, notes: 'Repos'),
          RosterDuty(date: DateTime(2026, 6, 11), type: DutyType.flight, flightNumber: 'AH 1069', departure: 'ALG', arrival: 'IST', checkIn: DateTime(2026, 6, 11, 5, 30), checkOut: DateTime(2026, 6, 11, 10, 15)),
          RosterDuty(date: DateTime(2026, 6, 12), type: DutyType.flight, flightNumber: 'AH 1070', departure: 'IST', arrival: 'ALG', checkIn: DateTime(2026, 6, 12, 11, 0), checkOut: DateTime(2026, 6, 12, 15, 45)),
          RosterDuty(date: DateTime(2026, 6, 13), type: DutyType.off, notes: 'Repos'),
          RosterDuty(date: DateTime(2026, 6, 14), type: DutyType.off, notes: 'Repos'),
          RosterDuty(date: DateTime(2026, 6, 15), type: DutyType.flight, flightNumber: 'AH 6120', departure: 'ALG', arrival: 'ORY', checkIn: DateTime(2026, 6, 15, 6, 30), checkOut: DateTime(2026, 6, 15, 10, 0)),
          RosterDuty(date: DateTime(2026, 6, 16), type: DutyType.flight, flightNumber: 'AH 6121', departure: 'ORY', arrival: 'ALG', checkIn: DateTime(2026, 6, 16, 11, 0), checkOut: DateTime(2026, 6, 16, 14, 30)),
          RosterDuty(date: DateTime(2026, 6, 17), type: DutyType.off, notes: 'Repos'),
          RosterDuty(date: DateTime(2026, 6, 18), type: DutyType.off, notes: 'Repos'),
          RosterDuty(date: DateTime(2026, 6, 19), type: DutyType.off, notes: 'Repos'),
          RosterDuty(date: DateTime(2026, 6, 20), type: DutyType.flight, flightNumber: 'AH 2014', departure: 'ALG', arrival: 'TUN', checkIn: DateTime(2026, 6, 20, 8, 0), checkOut: DateTime(2026, 6, 20, 10, 0)),
          RosterDuty(date: DateTime(2026, 6, 20), type: DutyType.flight, flightNumber: 'AH 2015', departure: 'TUN', arrival: 'ALG', checkIn: DateTime(2026, 6, 20, 11, 30), checkOut: DateTime(2026, 6, 20, 13, 30)),
          RosterDuty(date: DateTime(2026, 6, 21), type: DutyType.off, notes: 'Repos'),
          RosterDuty(date: DateTime(2026, 6, 22), type: DutyType.flight, flightNumber: 'AH 3017', departure: 'ALG', arrival: 'CDG', checkIn: DateTime(2026, 6, 22, 6, 0), checkOut: DateTime(2026, 6, 22, 9, 30)),
          RosterDuty(date: DateTime(2026, 6, 23), type: DutyType.flight, flightNumber: 'AH 3018', departure: 'CDG', arrival: 'ALG', checkIn: DateTime(2026, 6, 23, 10, 30), checkOut: DateTime(2026, 6, 23, 14, 0)),
          RosterDuty(date: DateTime(2026, 6, 24), type: DutyType.off, notes: 'Repos'),
          RosterDuty(date: DateTime(2026, 6, 25), type: DutyType.off, notes: 'Repos'),
          RosterDuty(date: DateTime(2026, 6, 26), type: DutyType.flight, flightNumber: 'AH 1069', departure: 'ALG', arrival: 'IST', checkIn: DateTime(2026, 6, 26, 5, 30), checkOut: DateTime(2026, 6, 26, 10, 15)),
          RosterDuty(date: DateTime(2026, 6, 27), type: DutyType.flight, flightNumber: 'AH 1070', departure: 'IST', arrival: 'ALG', checkIn: DateTime(2026, 6, 27, 11, 0), checkOut: DateTime(2026, 6, 27, 15, 45)),
          RosterDuty(date: DateTime(2026, 6, 28), type: DutyType.off, notes: 'Repos'),
          RosterDuty(date: DateTime(2026, 6, 29), type: DutyType.standby, notes: 'Standby'),
          RosterDuty(date: DateTime(2026, 6, 30), type: DutyType.standby, notes: 'Standby'),
        ],
      );
}
