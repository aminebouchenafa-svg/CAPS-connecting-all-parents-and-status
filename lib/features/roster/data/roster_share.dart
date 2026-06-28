import '../domain/entities/roster_duty.dart';
import 'roster_parser.dart';

class RosterShare {
  static const _dayNames = [
    '', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim',
  ];

  /// Generates a complete text summary of the [roster] suitable for
  /// copying to clipboard or sharing via messaging.
  static String generateTextSummary(Roster roster) {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('=== ROSTER ${roster.pilotName} ===');
    buffer.writeln(
        'Période: ${_formatDate(roster.periodStart)} → ${_formatDate(roster.periodEnd)}');
    buffer.writeln('Base: ${roster.base}  |  Avion: ${roster.aircraft}');
    if (roster.pilotId.isNotEmpty) {
      buffer.writeln('ID: ${roster.pilotId}');
    }
    buffer.writeln(_separator);

    // Daily duties
    final daysInPeriod = roster.periodEnd.difference(roster.periodStart).inDays + 1;
    for (int i = 0; i < daysInPeriod; i++) {
      final date = roster.periodStart.add(Duration(days: i));
      final dayDuties = roster.dutiesForDate(date);
      final dayNum = date.day.toString().padLeft(2, '0');
      final dayName = _dayNames[date.weekday];

      if (dayDuties.isEmpty) {
        buffer.writeln('$dayNum $dayName: ---');
        continue;
      }

      for (int j = 0; j < dayDuties.length; j++) {
        final duty = dayDuties[j];
        final prefix = j == 0 ? '$dayNum $dayName:' : '       ';
        buffer.writeln('$prefix ${_formatDutyLine(duty)}');
      }
    }

    // Stats footer
    buffer.writeln(_separator);
    buffer.writeln('STATISTIQUES');
    buffer.writeln(
        '  Block Hours : ${_formatHours(roster.totalBlockHours)}');
    buffer.writeln(
        '  Duty Hours  : ${_formatHours(roster.totalDutyHours)}');
    buffer.writeln('  Landings    : ${roster.totalLandings}');
    buffer.writeln('  Flight Days : ${roster.flightDays}');
    buffer.writeln('  Off Days    : ${roster.offDays}');

    if (roster.allStats.isNotEmpty) {
      buffer.writeln('');
      for (final entry in roster.allStats.entries) {
        final label = entry.key.padRight(30);
        buffer.writeln('  $label ${entry.value}');
      }
    }

    buffer.writeln(_separator);
    buffer.writeln('Généré par CAPS');

    return buffer.toString();
  }

  /// Generates a text summary for a single week starting at [weekStart].
  ///
  /// The week runs from [weekStart] (Monday) through the following Sunday.
  /// If [weekStart] is not a Monday, it is adjusted back to the previous Monday.
  static String generateWeekSummary(Roster roster, DateTime weekStart) {
    // Adjust to Monday if needed
    final monday = weekStart.subtract(Duration(days: weekStart.weekday - 1));

    final buffer = StringBuffer();
    buffer.writeln(
        '=== SEMAINE du ${_formatDate(monday)} ===');
    buffer.writeln('${roster.pilotName} | ${roster.aircraft} | ${roster.base}');
    buffer.writeln(_separator);

    int flightCount = 0;
    double blockHours = 0;

    for (int i = 0; i < 7; i++) {
      final date = monday.add(Duration(days: i));
      final dayDuties = roster.dutiesForDate(date);
      final dayNum = date.day.toString().padLeft(2, '0');
      final dayName = _dayNames[date.weekday];

      if (dayDuties.isEmpty) {
        buffer.writeln('$dayNum $dayName: ---');
        continue;
      }

      for (int j = 0; j < dayDuties.length; j++) {
        final duty = dayDuties[j];
        final prefix = j == 0 ? '$dayNum $dayName:' : '       ';
        buffer.writeln('$prefix ${_formatDutyLine(duty)}');

        if (duty.isFlight) {
          flightCount++;
          if (duty.checkIn != null && duty.checkOut != null) {
            blockHours +=
                duty.checkOut!.difference(duty.checkIn!).inMinutes / 60.0;
          }
        }
      }
    }

    buffer.writeln(_separator);
    buffer.writeln('Vols: $flightCount  |  Block: ${_formatHours(blockHours)}');
    buffer.writeln('Généré par CAPS');

    return buffer.toString();
  }

  // ── Private helpers ──

  static String _formatDutyLine(RosterDuty duty) {
    if (duty.isFlight) {
      final fn = duty.flightNumber ?? '';
      final dep = duty.departure ?? '???';
      final arr = duty.arrival ?? '???';
      final depName = RosterParser.airportName(dep);
      final arrName = RosterParser.airportName(arr);
      final route = '$dep($depName)→$arr($arrName)';

      final times = _formatTimeRange(duty.checkIn, duty.checkOut);
      return 'Vol $fn $route $times'.trim();
    }

    final label = duty.type.label;
    final code = duty.activityCode;
    final notes = duty.notes;
    final times = _formatTimeRange(duty.checkIn, duty.checkOut);

    final parts = <String>[label];
    if (code != null && code.isNotEmpty && code != label) {
      parts.add('($code)');
    }
    if (notes != null && notes.isNotEmpty && notes != label && notes != code) {
      parts.add('- $notes');
    }
    if (times.isNotEmpty) {
      parts.add(times);
    }

    return parts.join(' ');
  }

  static String _formatTimeRange(DateTime? start, DateTime? end) {
    if (start == null && end == null) return '';
    final s = start != null
        ? '${_pad(start.hour)}:${_pad(start.minute)}'
        : '??:??';
    final e =
        end != null ? '${_pad(end.hour)}:${_pad(end.minute)}' : '??:??';
    return '$s-$e';
  }

  static String _formatDate(DateTime dt) {
    return '${_pad(dt.day)}/${_pad(dt.month)}/${dt.year}';
  }

  static String _formatHours(double hours) {
    final h = hours.truncate();
    final m = ((hours - h) * 60).round();
    return '${h}h${m.toString().padLeft(2, '0')}';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');

  static const _separator = '--------------------------------';
}
