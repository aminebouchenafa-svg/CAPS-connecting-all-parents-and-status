import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/roster_duty.dart';

final rosterHistoryProvider =
    StateNotifierProvider<RosterHistoryNotifier, List<Roster>>((ref) {
  return RosterHistoryNotifier();
});

/// Manages an in-memory list of parsed rosters, keyed by their period.
///
/// When a roster for the same period is added again it replaces the
/// previous one (latest import wins). Rosters are stored most-recent first.
class RosterHistoryNotifier extends StateNotifier<List<Roster>> {
  RosterHistoryNotifier() : super([]);

  /// Adds a [roster] to the history.
  ///
  /// If a roster with the same [periodStart] and [periodEnd] already exists,
  /// it is replaced. The new roster is always placed at the front of the list.
  void addRoster(Roster roster) {
    state = [
      roster,
      ...state.where((r) =>
          r.periodStart != roster.periodStart ||
          r.periodEnd != roster.periodEnd),
    ];
  }

  /// Removes the roster at the given [index].
  void removeRoster(int index) {
    if (index < 0 || index >= state.length) return;
    state = [...state]..removeAt(index);
  }

  /// Clears all stored rosters.
  void clearAll() {
    state = [];
  }

  /// Returns the first roster whose period starts in the given [year]/[month],
  /// or `null` if none matches.
  Roster? getRosterForMonth(int year, int month) {
    for (final r in state) {
      if (r.periodStart.year == year && r.periodStart.month == month) {
        return r;
      }
    }
    return null;
  }

  /// Returns the roster that covers a specific [date], i.e. the date falls
  /// between [periodStart] and [periodEnd] (inclusive).
  Roster? getRosterForDate(DateTime date) {
    for (final r in state) {
      final d = DateTime(date.year, date.month, date.day);
      final start = DateTime(
          r.periodStart.year, r.periodStart.month, r.periodStart.day);
      final end =
          DateTime(r.periodEnd.year, r.periodEnd.month, r.periodEnd.day);
      if (!d.isBefore(start) && !d.isAfter(end)) {
        return r;
      }
    }
    return null;
  }

  /// Returns the combined list of all duties across every stored roster,
  /// sorted chronologically.
  List<RosterDuty> get allDuties {
    final duties = <RosterDuty>[];
    for (final r in state) {
      duties.addAll(r.duties);
    }
    duties.sort((a, b) => a.date.compareTo(b.date));
    return duties;
  }

  /// Total block hours across all stored rosters.
  double get totalBlockHours =>
      state.fold(0.0, (sum, r) => sum + r.totalBlockHours);

  /// Total landings across all stored rosters.
  int get totalLandings =>
      state.fold(0, (sum, r) => sum + r.totalLandings);
}
