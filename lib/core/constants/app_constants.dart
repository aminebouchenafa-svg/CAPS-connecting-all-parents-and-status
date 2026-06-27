abstract final class AppConstants {
  static const String appName = 'C.A.P.S.';
  static const String appTagline = 'Connecting All Parents & Status';

  // TSV (Temps de Service de Vol) rules
  static const int maxFlightHoursPerDay = 10;
  static const int minRestHoursAfterFlight = 11;
  static const int minRestHoursAfterLongHaul = 14;

  // Firestore collections
  static const String usersCollection = 'users';
  static const String flightStatusCollection = 'flight_status';
  static const String calendarEventsCollection = 'calendar_events';
  static const String householdCollection = 'households';
}
