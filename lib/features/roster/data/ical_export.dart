import '../domain/entities/roster_duty.dart';
import 'roster_parser.dart';

class ICalExport {
  /// Generates a complete iCalendar (.ics) string from a [Roster].
  ///
  /// Each duty becomes a VEVENT. Flights with checkIn/checkOut are timed events;
  /// all-day duties (off, rest, etc.) use VALUE=DATE format per RFC 5545.
  static String generateICalString(Roster roster) {
    final buffer = StringBuffer();
    buffer.writeln('BEGIN:VCALENDAR');
    buffer.writeln('VERSION:2.0');
    buffer.writeln('PRODID:-//CAPS//Roster Export//FR');
    buffer.writeln('CALSCALE:GREGORIAN');
    buffer.writeln('METHOD:PUBLISH');
    buffer.writeln('X-WR-CALNAME:Roster ${_escapeText(roster.pilotName)}');

    for (int i = 0; i < roster.duties.length; i++) {
      final duty = roster.duties[i];
      buffer.write(_buildEvent(duty, i, roster));
    }

    buffer.writeln('END:VCALENDAR');
    return buffer.toString();
  }

  static String _buildEvent(RosterDuty duty, int index, Roster roster) {
    final buffer = StringBuffer();
    buffer.writeln('BEGIN:VEVENT');

    // UID: unique identifier based on date, type, and index
    final dateStr = _formatDate(duty.date);
    final uid = 'caps-${dateStr}-${duty.type.name}-$index@caps-roster';
    buffer.writeln('UID:$uid');

    // DTSTAMP: creation timestamp (now)
    final now = DateTime.now().toUtc();
    buffer.writeln('DTSTAMP:${_formatDateTime(now)}');

    // DTSTART / DTEND
    if (duty.checkIn != null && duty.checkOut != null) {
      // Timed event
      buffer.writeln('DTSTART:${_formatDateTime(duty.checkIn!)}');
      buffer.writeln('DTEND:${_formatDateTime(duty.checkOut!)}');
    } else if (duty.checkIn != null) {
      // Has start but no end - default to 2 hours for non-flight, 4 hours for flight
      buffer.writeln('DTSTART:${_formatDateTime(duty.checkIn!)}');
      final duration = duty.isFlight ? 4 : 2;
      final end = duty.checkIn!.add(Duration(hours: duration));
      buffer.writeln('DTEND:${_formatDateTime(end)}');
    } else {
      // All-day event
      buffer.writeln('DTSTART;VALUE=DATE:${_formatDate(duty.date)}');
      final nextDay = duty.date.add(const Duration(days: 1));
      buffer.writeln('DTEND;VALUE=DATE:${_formatDate(nextDay)}');
    }

    // SUMMARY
    final summary = _buildSummary(duty);
    buffer.writeln('SUMMARY:${_escapeText(summary)}');

    // DESCRIPTION
    final description = _buildDescription(duty, roster);
    buffer.writeln('DESCRIPTION:${_escapeText(description)}');

    // CATEGORIES
    buffer.writeln('CATEGORIES:${duty.type.label}');

    // STATUS
    buffer.writeln('STATUS:CONFIRMED');

    // LOCATION for flights
    if (duty.isFlight && duty.departure != null) {
      final depName = RosterParser.airportName(duty.departure!);
      final arrName = duty.arrival != null
          ? RosterParser.airportName(duty.arrival!)
          : '';
      if (arrName.isNotEmpty) {
        buffer.writeln('LOCATION:${_escapeText('$depName ($depName) -> $arrName')}');
      } else {
        buffer.writeln('LOCATION:${_escapeText(depName)}');
      }
    }

    buffer.writeln('END:VEVENT');
    return buffer.toString();
  }

  static String _buildSummary(RosterDuty duty) {
    if (duty.isFlight) {
      final fn = duty.flightNumber ?? '';
      final dep = duty.departure ?? '';
      final arr = duty.arrival ?? '';
      if (dep.isNotEmpty && arr.isNotEmpty) {
        return 'Vol $fn: $dep → $arr';
      }
      if (fn.isNotEmpty) {
        return 'Vol $fn';
      }
      return 'Vol';
    }

    final label = duty.type.label;
    final code = duty.activityCode;
    if (code != null && code.isNotEmpty && code != label) {
      return '$label ($code)';
    }
    return label;
  }

  static String _buildDescription(RosterDuty duty, Roster roster) {
    final parts = <String>[];

    parts.add('Pilote: ${roster.pilotName}');
    parts.add('Date: ${_formatDateReadable(duty.date)}');
    parts.add('Type: ${duty.type.label}');

    if (duty.isFlight) {
      if (duty.flightNumber != null) {
        parts.add('Vol: ${duty.flightNumber}');
      }
      if (duty.departure != null) {
        final depName = RosterParser.airportName(duty.departure!);
        parts.add('Départ: ${duty.departure} ($depName)');
      }
      if (duty.arrival != null) {
        final arrName = RosterParser.airportName(duty.arrival!);
        parts.add('Arrivée: ${duty.arrival} ($arrName)');
      }
    }

    if (duty.checkIn != null) {
      parts.add('Check-in: ${_formatTimeReadable(duty.checkIn!)}');
    }
    if (duty.checkOut != null) {
      parts.add('Check-out: ${_formatTimeReadable(duty.checkOut!)}');
    }

    if (duty.activityCode != null && duty.activityCode!.isNotEmpty) {
      parts.add('Code: ${duty.activityCode}');
    }
    if (duty.notes != null && duty.notes!.isNotEmpty) {
      parts.add('Notes: ${duty.notes}');
    }

    parts.add('');
    parts.add('Base: ${roster.base} | Avion: ${roster.aircraft}');

    return parts.join('\\n');
  }

  /// Formats a DateTime as iCal datetime: 20260701T070000Z
  static String _formatDateTime(DateTime dt) {
    return '${dt.year}${_pad(dt.month)}${_pad(dt.day)}'
        'T${_pad(dt.hour)}${_pad(dt.minute)}${_pad(dt.second)}Z';
  }

  /// Formats a DateTime as iCal date: 20260701
  static String _formatDate(DateTime dt) {
    return '${dt.year}${_pad(dt.month)}${_pad(dt.day)}';
  }

  /// Human-readable date: 01/07/2026
  static String _formatDateReadable(DateTime dt) {
    return '${_pad(dt.day)}/${_pad(dt.month)}/${dt.year}';
  }

  /// Human-readable time: 07:00
  static String _formatTimeReadable(DateTime dt) {
    return '${_pad(dt.hour)}:${_pad(dt.minute)}';
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');

  /// Escapes special characters in iCalendar text values per RFC 5545.
  /// Backslash, semicolons, commas, and newlines must be escaped.
  static String _escapeText(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll(';', '\\;')
        .replaceAll(',', '\\,')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '');
  }
}
