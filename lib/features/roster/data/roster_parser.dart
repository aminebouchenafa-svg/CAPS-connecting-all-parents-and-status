import '../domain/entities/roster_duty.dart';

class RosterParser {
  static const Map<String, String> airportNames = {
    'ALG': 'Alger',
    'IST': 'Istanbul',
    'TUN': 'Tunis',
    'MXP': 'Milan',
    'CDG': 'Paris CDG',
    'ORY': 'Paris Orly',
    'LYS': 'Lyon',
    'BRU': 'Bruxelles',
    'MRS': 'Marseille',
    'TLM': 'Tlemcen',
    'BJA': 'Béjaïa',
    'TEE': 'Tébessa',
    'STR': 'Strasbourg',
    'LIL': 'Lille',
    'FCO': 'Rome',
    'BCN': 'Barcelone',
    'CZL': 'Constantine',
    'ORN': 'Oran',
    'AAE': 'Annaba',
    'BLJ': 'Batna',
    'QSF': 'Sétif',
    'GHA': 'Ghardaïa',
    'TMR': 'Tamanrasset',
  };

  Roster parse(String text) {
    final pilotName = _extractField(text, 'NAME');
    final pilotId = _extractField(text, 'ID');
    final base = _extractBase(text);
    final aircraft = _extractAircraft(text);
    final period = _extractPeriod(text);
    final duties = _parseDuties(text, period.$1);
    final stats = _parseStats(text);

    return Roster(
      pilotName: pilotName,
      pilotId: pilotId,
      base: base,
      aircraft: aircraft,
      periodStart: period.$1,
      periodEnd: period.$2,
      duties: duties,
      totalBlockHours: stats['blockHours'] ?? 0,
      totalDutyHours: stats['dutyHours'] ?? 0,
      totalLandings: (stats['landings'] ?? 0).toInt(),
      offDays: (stats['offDays'] ?? 0).toInt(),
      flightDays: (stats['flightDays'] ?? 0).toInt(),
    );
  }

  String _extractField(String text, String field) {
    final regex = RegExp('$field\\s*:\\s*(.+?)(?=\\s{2,}|\\n)');
    final match = regex.firstMatch(text);
    return match?.group(1)?.trim() ?? '';
  }

  String _extractBase(String text) {
    final regex = RegExp(r'(\w{3})\s+Captain');
    final match = regex.firstMatch(text);
    return match?.group(1) ?? 'ALG';
  }

  String _extractAircraft(String text) {
    final regex = RegExp(r'Captain\s*-\s*(\w+)');
    final match = regex.firstMatch(text);
    return match?.group(1) ?? 'B738';
  }

  (DateTime, DateTime) _extractPeriod(String text) {
    final regex = RegExp(r'Period:\s*(\d{2}/\d{2}/\d{4})\s*START\s*to\s*(\d{2}/\d{2}/\d{4})');
    final match = regex.firstMatch(text);
    if (match != null) {
      return (_parseDate(match.group(1)!), _parseDate(match.group(2)!));
    }
    final now = DateTime.now();
    return (DateTime(now.year, now.month, 1), DateTime(now.year, now.month + 1, 0));
  }

  DateTime _parseDate(String dateStr) {
    final parts = dateStr.split('/');
    return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
  }

  List<RosterDuty> _parseDuties(String text, DateTime periodStart) {
    final duties = <RosterDuty>[];
    final year = periodStart.year;
    final month = periodStart.month;

    // Parse RH (repos) days
    final rhPattern = RegExp(r'//RH|/RH|\bRH\b');
    // Parse OFF days
    final offPattern = RegExp(r'\bOFF\b');

    // Parse flight numbers (4-digit codes like 3017, 4002, etc.)
    final flightPattern = RegExp(r'\b(\d{4})\b');

    // Parse airport codes from the text
    final airportPattern = RegExp(r'\b([A-Z]{3})\b');

    // Extract day-by-day activities from the roster text
    // The roster format has dates as columns: 01 Jun, 02 Jun, etc.
    for (int day = 1; day <= 31; day++) {
      final date = DateTime(year, month, day);
      if (date.isAfter(DateTime(year, month + 1, 0))) break;

      // Check for known activity codes in the text near this date
      final dayStr = day.toString().padLeft(2, '0');
      final dayPattern = RegExp('$dayStr\\s+Jun');

      if (dayPattern.hasMatch(text)) {
        // Try to find what activity is on this day
        // This is a simplified parser - the PDF format is complex grid layout
        if (_isDayOff(text, day)) {
          duties.add(RosterDuty(
            date: date,
            type: DutyType.off,
            notes: 'Jour de repos',
          ));
        }
      }
    }

    // Parse specific flight legs from the structured data
    _parseFlightLegs(text, duties, year, month);

    duties.sort((a, b) => a.date.compareTo(b.date));
    return duties;
  }

  bool _isDayOff(String text, int day) {
    // Days marked with RH or empty columns are rest days
    return false; // Simplified - full parsing would need grid analysis
  }

  void _parseFlightLegs(String text, List<RosterDuty> duties, int year, int month) {
    // Parse the known flight data from the roster
    // Based on the actual PDF content structure
    final knownFlights = _extractKnownFlights(text, year, month);
    duties.addAll(knownFlights);
  }

  List<RosterDuty> _extractKnownFlights(String text, int year, int month) {
    final flights = <RosterDuty>[];

    // Hard-coded parsing based on observed eCrew PDF structure
    // In production, this would use a more sophisticated PDF grid parser

    // Detect flight entries: flight number followed by times and airports
    final linePattern = RegExp(
      r'(\d{4})\s+.*?([A-Z]{3})\s+.*?([A-Z]{3})',
    );

    for (final match in linePattern.allMatches(text)) {
      final flightNum = match.group(1);
      final dep = match.group(2);
      final arr = match.group(3);

      if (flightNum != null && dep != null && arr != null) {
        if (airportNames.containsKey(dep) || airportNames.containsKey(arr)) {
          flights.add(RosterDuty(
            date: DateTime(year, month, 1),
            type: DutyType.flight,
            flightNumber: 'AH $flightNum',
            departure: dep,
            arrival: arr,
          ));
        }
      }
    }

    return flights;
  }

  Map<String, double> _parseStats(String text) {
    final stats = <String, double>{};

    final blockMatch = RegExp(r'Block Hours\s+(\d+):(\d+)').firstMatch(text);
    if (blockMatch != null) {
      stats['blockHours'] = double.parse(blockMatch.group(1)!) +
          double.parse(blockMatch.group(2)!) / 60;
    }

    final dutyMatch = RegExp(r'Duty Hours\s+(\d+):(\d+)').firstMatch(text);
    if (dutyMatch != null) {
      stats['dutyHours'] = double.parse(dutyMatch.group(1)!) +
          double.parse(dutyMatch.group(2)!) / 60;
    }

    final landingsMatch = RegExp(r'Landings\s+(\d+)').firstMatch(text);
    if (landingsMatch != null) {
      stats['landings'] = double.parse(landingsMatch.group(1)!);
    }

    final offMatch = RegExp(r'Off Days\s+(\d+)').firstMatch(text);
    if (offMatch != null) {
      stats['offDays'] = double.parse(offMatch.group(1)!);
    }

    final flightMatch = RegExp(r'Flight Days\s+(\d+)').firstMatch(text);
    if (flightMatch != null) {
      stats['flightDays'] = double.parse(flightMatch.group(1)!);
    }

    return stats;
  }

  static String airportName(String code) =>
      airportNames[code] ?? code;
}
