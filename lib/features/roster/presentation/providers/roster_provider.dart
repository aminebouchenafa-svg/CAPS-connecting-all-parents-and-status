import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/storage_service.dart';
import '../../data/roster_parser.dart';
import '../../domain/entities/roster_duty.dart';

// ── Roster (parsed from raw text) ──

final rosterProvider =
    StateNotifierProvider<RosterNotifier, Roster?>((ref) {
  return RosterNotifier();
});

class RosterNotifier extends StateNotifier<Roster?> {
  RosterNotifier() : super(null) {
    _loadFromStorage();
  }

  void _loadFromStorage() {
    final rawText = StorageService.getRosterRawText();
    if (rawText != null && rawText.isNotEmpty) {
      final parser = RosterParser();
      state = parser.parse(rawText);
    }
  }

  void update(Roster? value) {
    state = value;
    // When clearing the roster, also clear persisted raw text
    if (value == null) {
      StorageService.saveRosterRawText(null);
    }
  }
}

// ── Raw text ──

final rosterRawTextProvider =
    StateNotifierProvider<RosterRawTextNotifier, String?>((ref) {
  return RosterRawTextNotifier();
});

class RosterRawTextNotifier extends StateNotifier<String?> {
  RosterRawTextNotifier() : super(StorageService.getRosterRawText());

  void update(String? value) {
    state = value;
    StorageService.saveRosterRawText(value);
  }
}

final rosterParserProvider = Provider<RosterParser>((ref) => RosterParser());

// ── Duty notes ──

final dutyNotesProvider =
    StateNotifierProvider<DutyNotesNotifier, Map<String, String>>((ref) {
  return DutyNotesNotifier();
});

class DutyNotesNotifier extends StateNotifier<Map<String, String>> {
  DutyNotesNotifier() : super(StorageService.getDutyNotes());

  void update(Map<String, String> value) {
    state = value;
    StorageService.saveDutyNotes(value);
  }
}

// ── Duty tasks ──

final dutyTasksProvider = StateNotifierProvider<DutyTasksNotifier,
    Map<String, List<Map<String, dynamic>>>>((ref) {
  return DutyTasksNotifier();
});

class DutyTasksNotifier
    extends StateNotifier<Map<String, List<Map<String, dynamic>>>> {
  DutyTasksNotifier() : super(StorageService.getDutyTasks());

  void update(Map<String, List<Map<String, dynamic>>> value) {
    state = value;
    StorageService.saveDutyTasks(value);
  }
}

// ── Duty colors ──

final dutyColorsProvider =
    StateNotifierProvider<DutyColorsNotifier, Map<String, int>>((ref) {
  return DutyColorsNotifier();
});

class DutyColorsNotifier extends StateNotifier<Map<String, int>> {
  DutyColorsNotifier() : super(StorageService.getDutyColors());

  void update(Map<String, int> value) {
    state = value;
    StorageService.saveDutyColors(value);
  }
}

final rosterDebugProvider = StateProvider<String?>((ref) => null);
