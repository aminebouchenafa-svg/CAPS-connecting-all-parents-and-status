import '../../features/auth/domain/entities/app_user.dart';
import '../../features/calendar/domain/entities/calendar_event.dart';
import '../../features/dashboard/domain/entities/flight_status.dart';

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
    currentLocation: 'Dubai (DXB)',
    flightNumber: 'AF 662',
    destination: 'Paris CDG',
    notes: 'Vol retour demain matin. Je vous appelle ce soir !',
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
          flightNumber: 'AF 661',
          destination: 'Dubai DXB',
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
          currentLocation: 'Maison',
          updatedAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
      ];

  static List<CalendarEvent> get events => [
        CalendarEvent(
          id: 'evt-1',
          householdId: householdId,
          createdByUid: 'demo-amine',
          title: 'Rotation Dubai',
          type: EventType.rotation,
          startDate: DateTime.now().subtract(const Duration(hours: 10)),
          endDate: DateTime.now().add(const Duration(hours: 14)),
          createdAt: DateTime.now().subtract(const Duration(days: 7)),
        ),
        CalendarEvent(
          id: 'evt-2',
          householdId: householdId,
          createdByUid: 'demo-amina',
          title: 'Spectacle Ilyane',
          description: 'Spectacle de fin d\'année à l\'école',
          type: EventType.school,
          startDate: DateTime.now().add(const Duration(days: 3, hours: 14)),
          endDate: DateTime.now().add(const Duration(days: 3, hours: 16)),
          createdAt: DateTime.now().subtract(const Duration(days: 5)),
        ),
        CalendarEvent(
          id: 'evt-3',
          householdId: householdId,
          createdByUid: 'demo-amina',
          title: 'RDV pédiatre Sisso',
          description: 'Visite des 6 mois',
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
          title: 'Rotation New York',
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
          description: 'Préparer le gâteau et les décos',
          type: EventType.family,
          startDate: DateTime.now().add(const Duration(days: 12, hours: 14)),
          endDate: DateTime.now().add(const Duration(days: 12, hours: 18)),
          isAllDay: false,
          createdAt: DateTime.now(),
        ),
      ];
}
