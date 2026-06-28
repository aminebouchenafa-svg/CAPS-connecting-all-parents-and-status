import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static late SharedPreferences _prefs;

  // Keys
  static const _keyRosterRawText = 'roster_raw_text';
  static const _keyDutyNotes = 'duty_notes';
  static const _keyDutyTasks = 'duty_tasks';
  static const _keyDutyColors = 'duty_colors';
  static const _keyThemeMode = 'theme_mode';
  static const _keyCalendarEvents = 'calendar_events';
  static const _keyOnboardingSeen = 'onboarding_seen';

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── Roster raw text ──

  static String? getRosterRawText() {
    return _prefs.getString(_keyRosterRawText);
  }

  static Future<void> saveRosterRawText(String? text) async {
    if (text == null) {
      await _prefs.remove(_keyRosterRawText);
    } else {
      await _prefs.setString(_keyRosterRawText, text);
    }
  }

  // ── Duty notes ──

  static Map<String, String> getDutyNotes() {
    final json = _prefs.getString(_keyDutyNotes);
    if (json == null) return {};
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, v as String));
  }

  static Future<void> saveDutyNotes(Map<String, String> notes) async {
    await _prefs.setString(_keyDutyNotes, jsonEncode(notes));
  }

  // ── Duty tasks ──

  static Map<String, List<Map<String, dynamic>>> getDutyTasks() {
    final json = _prefs.getString(_keyDutyTasks);
    if (json == null) return {};
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(
      k,
      (v as List<dynamic>)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
    ));
  }

  static Future<void> saveDutyTasks(
      Map<String, List<Map<String, dynamic>>> tasks) async {
    await _prefs.setString(_keyDutyTasks, jsonEncode(tasks));
  }

  // ── Duty colors ──

  static Map<String, int> getDutyColors() {
    final json = _prefs.getString(_keyDutyColors);
    if (json == null) return {};
    final decoded = jsonDecode(json) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, v as int));
  }

  static Future<void> saveDutyColors(Map<String, int> colors) async {
    await _prefs.setString(_keyDutyColors, jsonEncode(colors));
  }

  // ── Theme mode ──

  static String getThemeMode() {
    return _prefs.getString(_keyThemeMode) ?? 'light';
  }

  static Future<void> saveThemeMode(String mode) async {
    await _prefs.setString(_keyThemeMode, mode);
  }

  // ── Family calendar events ──

  static List<Map<String, dynamic>> getCalendarEvents() {
    final json = _prefs.getString(_keyCalendarEvents);
    if (json == null) return [];
    final decoded = jsonDecode(json) as List<dynamic>;
    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static Future<void> saveCalendarEvents(
      List<Map<String, dynamic>> events) async {
    await _prefs.setString(_keyCalendarEvents, jsonEncode(events));
  }

  // ── Onboarding seen ──

  static bool getOnboardingSeen() {
    return _prefs.getBool(_keyOnboardingSeen) ?? false;
  }

  static Future<void> saveOnboardingSeen(bool seen) async {
    await _prefs.setBool(_keyOnboardingSeen, seen);
  }
}
