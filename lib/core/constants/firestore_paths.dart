abstract final class FirestorePaths {
  static const String households = 'households';
  static String household(String id) => 'households/$id';
  static String householdMembers(String householdId) =>
      'households/$householdId/members';

  static const String users = 'users';
  static String user(String uid) => 'users/$uid';

  static String flightStatuses(String householdId) =>
      'households/$householdId/flight_statuses';
  static String flightStatus(String householdId, String statusId) =>
      'households/$householdId/flight_statuses/$statusId';

  static String calendarEvents(String householdId) =>
      'households/$householdId/calendar_events';
  static String calendarEvent(String householdId, String eventId) =>
      'households/$householdId/calendar_events/$eventId';
}
