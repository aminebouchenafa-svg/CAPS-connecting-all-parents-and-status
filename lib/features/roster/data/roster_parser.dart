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
    'JFK': 'New York JFK',
    'LHR': 'Londres',
    'FRA': 'Francfort',
    'MAD': 'Madrid',
    'AMS': 'Amsterdam',
    'GVA': 'Genève',
    'PMI': 'Palma',
    'CAI': 'Le Caire',
    'CMN': 'Casablanca',
    'DXB': 'Dubaï',
    'DOH': 'Doha',
    'JED': 'Djeddah',
    'MED': 'Médine',
  };

  static const _monthAbbr = {
    'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4, 'MAY': 5, 'JUN': 6,
    'JUL': 7, 'AUG': 8, 'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12,
    'JANV': 1, 'FEVR': 2, 'MARS': 3, 'AVR': 4, 'MAI': 5, 'JUIN': 6,
    'JUIL': 7, 'AOUT': 8, 'SEPT': 9, 'OCTO': 10, 'NOVE': 11, 'DECE': 12,
  };

  String? lastExtractedText;

  Roster parse(String text) {
    lastExtractedText = text;

    final pilotName = _extractField(text, 'NAME');
    final pilotId = _extractField(text, 'ID');
    final base = _extractBase(text);
    final aircraft = _extractAircraft(text);
    final period = _extractPeriod(text);
    final stats = _parseStats(text);
    final duties = _parseDuties(text, period.$1);

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

  // --- Duty parsing: tries multiple strategies ---

  List<RosterDuty> _parseDuties(String text, DateTime periodStart) {
    final year = periodStart.year;
    final month = periodStart.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;

    // Strategy 1: AvioDev tabular format (each flight leg is a row)
    var duties = _tryAvioDevParse(text, year, month, daysInMonth);

    // Strategy 2: grid-based (tab-separated columns from PDF layout)
    if (duties.isEmpty) {
      duties = _tryGridParse(text, year, month, daysInMonth);
    }

    // Strategy 3: row-based (one duty per line with day number)
    if (duties.isEmpty) {
      duties = _tryRowParse(text, year, month, daysInMonth);
    }

    // Strategy 4: token-based (find day+flight+airport sequences)
    if (duties.isEmpty) {
      duties = _tryTokenParse(text, year, month, daysInMonth);
    }

    // Strategy 5: find flights by proximity to day numbers
    if (duties.isEmpty) {
      duties = _tryProximityParse(text, year, month, daysInMonth);
    }

    // Fill in rest/off/standby days from text
    final coveredDays = duties.map((d) => d.date.day).toSet();
    _fillActivityDays(text, duties, year, month, daysInMonth, coveredDays);

    duties.sort((a, b) {
      final cmp = a.date.compareTo(b.date);
      if (cmp != 0) return cmp;
      if (a.checkIn != null && b.checkIn != null) {
        return a.checkIn!.compareTo(b.checkIn!);
      }
      return 0;
    });

    return duties;
  }

  // Strategy: AvioDev Personal Crew Schedule Report format
  List<RosterDuty> _tryAvioDevParse(String text, int year, int month, int daysInMonth) {
    final duties = <RosterDuty>[];
    final lines = text.split('\n');

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // AvioDev format: tab or multi-space separated fields
      // Pattern: "DD Mon FLT AH1069 ALG IST 0530 1015 ..."
      // or: "DD	AH1069	ALG	IST	0530	1015"
      // or: "01 Jun Mon	1069	ALG	IST	05:30	10:15	..."
      final cells = trimmed.split(RegExp(r'\t+'));

      // Try tab-separated first
      if (cells.length >= 3) {
        final parsed = _parseAvioDevCells(cells, year, month, daysInMonth);
        if (parsed != null) {
          duties.addAll(parsed);
          continue;
        }
      }

      // Try space-separated with flexible patterns
      // Pattern: DD [Mon] [Jun] flight_or_activity [DEP] [ARR] [time] [time]
      final spaceMatch = RegExp(
        r'(\d{1,2})\s+'
        r'(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun|Lu|Ma|Me|Je|Ve|Sa|Di)\w*\s+'
        r'(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\w*\s+'
        r'(.+)',
        caseSensitive: false,
      ).firstMatch(trimmed);

      if (spaceMatch != null) {
        final day = int.tryParse(spaceMatch.group(1)!);
        final rest = spaceMatch.group(2)!.trim();
        if (day != null && day >= 1 && day <= daysInMonth) {
          final parsed = _parseActivityString(rest, year, month, day);
          if (parsed != null) duties.addAll(parsed);
        }
        continue;
      }

      // Pattern without month: "DD Mon activity..."
      final shortMatch = RegExp(
        r'^(\d{1,2})\s+'
        r'(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun|Lu|Ma|Me|Je|Ve|Sa|Di)\w*\s+'
        r'(.+)',
        caseSensitive: false,
      ).firstMatch(trimmed);

      if (shortMatch != null) {
        final day = int.tryParse(shortMatch.group(1)!);
        final rest = shortMatch.group(2)!.trim();
        if (day != null && day >= 1 && day <= daysInMonth) {
          final parsed = _parseActivityString(rest, year, month, day);
          if (parsed != null) duties.addAll(parsed);
        }
      }
    }

    return duties;
  }

  List<RosterDuty>? _parseAvioDevCells(List<String> cells, int year, int month, int daysInMonth) {
    // Find day number in first few cells
    int? day;
    int startIdx = 0;

    for (int i = 0; i < cells.length && i < 3; i++) {
      final cleaned = cells[i].replaceAll(RegExp(r'[A-Za-z\s]'), '').trim();
      final num = int.tryParse(cleaned);
      if (num != null && num >= 1 && num <= daysInMonth) {
        day = num;
        startIdx = i + 1;
        break;
      }
    }

    if (day == null) return null;

    // Remaining cells contain activity data
    final remaining = cells.sublist(startIdx).map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
    if (remaining.isEmpty) return null;

    return _parseActivityString(remaining.join(' '), year, month, day);
  }

  List<RosterDuty>? _parseActivityString(String activity, int year, int month, int day) {
    final upper = activity.toUpperCase().trim();
    final duties = <RosterDuty>[];

    // Check for activity codes
    if (_isActivityCode(upper) || upper.startsWith('RH') || upper.startsWith('OFF') || upper == 'DO' || upper == 'JA') {
      duties.add(RosterDuty(
        date: DateTime(year, month, day),
        type: _codeToType(upper.split(RegExp(r'\s')).first),
      ));
      return duties;
    }

    // Parse flight data from the activity string
    // Find flight numbers, airports, times
    final tokens = activity.split(RegExp(r'[\s\t]+'));
    final flightNums = <String>[];
    final airports = <String>[];
    final times = <DateTime>[];

    for (final token in tokens) {
      final t = token.toUpperCase().trim();
      if (t.isEmpty) continue;

      // Flight number: AH1069, AH 1069, 1069
      final fn = _extractFlightNum(t);
      if (fn != null) {
        flightNums.add(fn);
        continue;
      }

      // Airport code (3 uppercase letters, not an activity code)
      if (RegExp(r'^[A-Z]{3}$').hasMatch(t) && !_isActivityCode(t)) {
        airports.add(t);
        continue;
      }

      // Time: various formats
      final time = _timeFromStr(year, month, day, token);
      if (time != null) {
        times.add(time);
        continue;
      }
    }

    if (flightNums.isEmpty) return null;

    for (int i = 0; i < flightNums.length; i++) {
      final dep = (i * 2) < airports.length ? airports[i * 2] : null;
      final arr = (i * 2 + 1) < airports.length ? airports[i * 2 + 1] : null;
      final checkIn = (i * 2) < times.length ? times[i * 2] : null;
      final checkOut = (i * 2 + 1) < times.length ? times[i * 2 + 1] : null;

      duties.add(RosterDuty(
        date: DateTime(year, month, day),
        type: DutyType.flight,
        flightNumber: flightNums[i],
        departure: dep,
        arrival: arr,
        checkIn: checkIn,
        checkOut: checkOut,
      ));
    }

    return duties.isEmpty ? null : duties;
  }

  // Strategy: Grid-based parsing from tab-separated PDF extraction
  List<RosterDuty> _tryGridParse(String text, int year, int month, int daysInMonth) {
    final duties = <RosterDuty>[];
    final lines = text.split('\n');

    // Find the row containing day numbers (1, 2, 3, ... or 01, 02, 03, ...)
    int? dayRowIdx;
    List<int> dayNumbers = [];
    Map<int, int> dayToCol = {};

    for (int i = 0; i < lines.length; i++) {
      final cells = lines[i].split('\t').map((c) => c.trim()).toList();
      if (cells.length < 5) continue;

      int consecutiveCount = 0;
      int? prevDay;
      final tempDayToCol = <int, int>{};

      for (int j = 0; j < cells.length; j++) {
        final num = int.tryParse(cells[j]);
        if (num != null && num >= 1 && num <= 31) {
          if (prevDay == null || num == prevDay + 1) {
            consecutiveCount++;
          }
          prevDay = num;
          tempDayToCol[num] = j;
        }
      }

      if (consecutiveCount >= 5 && tempDayToCol.length >= 5) {
        dayRowIdx = i;
        dayToCol = tempDayToCol;
        dayNumbers = tempDayToCol.keys.toList()..sort();
        break;
      }
    }

    if (dayRowIdx == null) return duties;

    // Collect data from rows below the day row for each column
    final dayData = <int, List<String>>{};
    for (final day in dayNumbers) {
      dayData[day] = [];
    }

    for (int i = dayRowIdx + 1; i < lines.length; i++) {
      final cells = lines[i].split('\t').map((c) => c.trim()).toList();
      if (cells.isEmpty) continue;

      // Stop if we hit the stats section
      if (cells.any((c) => c.contains('Block') || c.contains('Duty') || c.contains('Landing'))) {
        break;
      }

      for (final entry in dayToCol.entries) {
        final day = entry.key;
        final col = entry.value;
        if (col < cells.length && cells[col].isNotEmpty) {
          dayData[day]!.add(cells[col]);
        }
      }
    }

    // Parse each day's collected data
    for (final entry in dayData.entries) {
      final day = entry.key;
      if (day > daysInMonth) continue;
      final values = entry.value;
      if (values.isEmpty) continue;

      // Check for activity codes
      final actIdx = values.indexWhere((v) => _isActivityCode(v.toUpperCase()));
      if (actIdx >= 0) {
        duties.add(RosterDuty(
          date: DateTime(year, month, day),
          type: _codeToType(values[actIdx].toUpperCase()),
        ));
        continue;
      }

      // Extract flight data from column values
      final flightDuties = _parseColumnValues(values, year, month, day);
      if (flightDuties.isNotEmpty) {
        duties.addAll(flightDuties);
      }
    }

    return duties;
  }

  List<RosterDuty> _parseColumnValues(List<String> values, int year, int month, int day) {
    final duties = <RosterDuty>[];
    final flightNums = <String>[];
    final airports = <String>[];
    final times = <DateTime>[];

    for (final v in values) {
      final upper = v.toUpperCase().trim();

      // Flight number: AH1069, AH 1069, 1069, etc.
      final fn = _extractFlightNum(upper);
      if (fn != null) {
        flightNums.add(fn);
        continue;
      }

      // Airport code
      if (RegExp(r'^[A-Z]{3}$').hasMatch(upper) && !_isActivityCode(upper)) {
        airports.add(upper);
        continue;
      }

      // Time: 0530, 05:30, 05.30, 530
      final time = _timeFromStr(year, month, day, v.replaceAll(RegExp(r'[hH]'), ':'));
      if (time != null) {
        times.add(time);
        continue;
      }
    }

    if (flightNums.isEmpty) return duties;

    // Match flight numbers with airport pairs and time pairs
    for (int i = 0; i < flightNums.length; i++) {
      final dep = (i * 2) < airports.length ? airports[i * 2] : null;
      final arr = (i * 2 + 1) < airports.length ? airports[i * 2 + 1] : null;
      final checkIn = (i * 2) < times.length ? times[i * 2] : null;
      final checkOut = (i * 2 + 1) < times.length ? times[i * 2 + 1] : null;

      duties.add(RosterDuty(
        date: DateTime(year, month, day),
        type: DutyType.flight,
        flightNumber: flightNums[i],
        departure: dep,
        arrival: arr,
        checkIn: checkIn,
        checkOut: checkOut,
      ));
    }

    return duties;
  }

  // Strategy: Each line contains day + flight info or day + activity
  List<RosterDuty> _tryRowParse(String text, int year, int month, int daysInMonth) {
    final duties = <RosterDuty>[];
    final lines = text.split(RegExp(r'[\r\n]+'));

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.length < 3) continue;

      // Flight line: "01 AH1069 ALG IST 0530 1015"
      // or "01Jun Mon AH 1069 ALG-IST 05:30 10:15"
      // or "1 1069 ALG IST 530 1015"
      final flightMatch = RegExp(
        r'(?:^|\s)(\d{1,2})\s*'
        r'(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)?\.?\s*'
        r'(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun|Lu|Ma|Me|Je|Ve|Sa|Di)?\.?\s+'
        r'(?:AH\s*)?(\d{3,4})\s+'
        r'([A-Z]{3})\s*[-–→/]?\s*([A-Z]{3})'
        r'(?:\s+(\d{2,4}[:.]?\d{2})\s+(\d{2,4}[:.]?\d{2}))?',
      ).firstMatch(trimmed);

      if (flightMatch != null) {
        final day = int.tryParse(flightMatch.group(1)!);
        if (day != null && day >= 1 && day <= daysInMonth) {
          duties.add(RosterDuty(
            date: DateTime(year, month, day),
            type: DutyType.flight,
            flightNumber: 'AH ${flightMatch.group(2)!}',
            departure: flightMatch.group(3)!,
            arrival: flightMatch.group(4)!,
            checkIn: _timeFromStr(year, month, day, flightMatch.group(5)),
            checkOut: _timeFromStr(year, month, day, flightMatch.group(6)),
          ));
          continue;
        }
      }

      // Activity line: "03 RH" or "03 OFF" or "29 SBY"
      final actMatch = RegExp(
        r'(?:^|\s)(\d{1,2})\s*'
        r'(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)?\.?\s*'
        r'(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun|Lu|Ma|Me|Je|Ve|Sa|Di)?\.?\s+'
        r'(RH|OFF|SBY|STBY|STANDBY|REPOS|REST|DO|JA|C/O)',
        caseSensitive: false,
      ).firstMatch(trimmed);

      if (actMatch != null) {
        final day = int.tryParse(actMatch.group(1)!);
        if (day != null && day >= 1 && day <= daysInMonth) {
          duties.add(RosterDuty(
            date: DateTime(year, month, day),
            type: _codeToType(actMatch.group(2)!),
          ));
        }
      }
    }

    return duties;
  }

  // Strategy 2: Tokenize text and find day→flight→airport→time sequences
  List<RosterDuty> _tryTokenParse(String text, int year, int month, int daysInMonth) {
    final duties = <RosterDuty>[];
    final tokens = text.split(RegExp(r'\s+'));

    for (int i = 0; i < tokens.length - 1; i++) {
      final dayNum = int.tryParse(tokens[i]);
      if (dayNum == null || dayNum < 1 || dayNum > daysInMonth) continue;

      final next = tokens[i + 1].toUpperCase();

      // Activity code right after day number
      if (_isActivityCode(next)) {
        duties.add(RosterDuty(
          date: DateTime(year, month, dayNum),
          type: _codeToType(next),
        ));
        i++;
        continue;
      }

      // Flight number right after day number
      final flightNum = _extractFlightNum(next);
      if (flightNum != null) {
        String? dep;
        String? arr;
        String? depTime;
        String? arrTime;

        // Look ahead for airports and times
        for (int j = i + 2; j < tokens.length && j < i + 8; j++) {
          final t = tokens[j].toUpperCase();
          if (RegExp(r'^[A-Z]{3}$').hasMatch(t)) {
            if (dep == null) {
              dep = t;
            } else if (arr == null) {
              arr = t;
            }
          } else if (RegExp(r'^\d{2,4}[:.]?\d{2}$').hasMatch(t)) {
            if (depTime == null) {
              depTime = t;
            } else if (arrTime == null) {
              arrTime = t;
            }
          } else if (int.tryParse(t) != null) {
            break;
          }
        }

        duties.add(RosterDuty(
          date: DateTime(year, month, dayNum),
          type: DutyType.flight,
          flightNumber: flightNum,
          departure: dep,
          arrival: arr,
          checkIn: _timeFromStr(year, month, dayNum, depTime),
          checkOut: _timeFromStr(year, month, dayNum, arrTime),
        ));
        i++;
        continue;
      }
    }

    return duties;
  }

  // Strategy 3: Find all flights and airports, associate with nearest day numbers
  List<RosterDuty> _tryProximityParse(String text, int year, int month, int daysInMonth) {
    final duties = <RosterDuty>[];

    // Find all occurrences of flight patterns with position
    final allMatches = <({int pos, String flightNum, String? dep, String? arr, String? depTime, String? arrTime})>[];

    // Pattern: AH followed by 3-4 digits, then possibly airports and times
    final pattern = RegExp(
      r'AH\s*(\d{3,4})\s+([A-Z]{3})\s*[-–→/]?\s*([A-Z]{3})'
      r'(?:\s+(\d{2,4}[:.]?\d{2})\s+(\d{2,4}[:.]?\d{2}))?',
    );

    for (final match in pattern.allMatches(text)) {
      allMatches.add((
        pos: match.start,
        flightNum: 'AH ${match.group(1)!}',
        dep: match.group(2),
        arr: match.group(3),
        depTime: match.group(4),
        arrTime: match.group(5),
      ));
    }

    if (allMatches.isEmpty) return duties;

    // Find all day numbers in text and their positions
    final dayPositions = <({int pos, int day})>[];
    final dayPattern = RegExp(r'(?:^|\s)(\d{1,2})(?:\s|$)');
    for (final match in dayPattern.allMatches(text)) {
      final day = int.tryParse(match.group(1)!);
      if (day != null && day >= 1 && day <= daysInMonth) {
        dayPositions.add((pos: match.start, day: day));
      }
    }

    // Associate each flight with the nearest preceding day number
    for (final flight in allMatches) {
      int? bestDay;
      int bestDist = 999999;

      for (final dp in dayPositions) {
        final dist = flight.pos - dp.pos;
        if (dist >= 0 && dist < bestDist) {
          bestDist = dist;
          bestDay = dp.day;
        }
      }

      duties.add(RosterDuty(
        date: DateTime(year, month, bestDay ?? 1),
        type: DutyType.flight,
        flightNumber: flight.flightNum,
        departure: flight.dep,
        arrival: flight.arr,
        checkIn: _timeFromStr(year, month, bestDay ?? 1, flight.depTime),
        checkOut: _timeFromStr(year, month, bestDay ?? 1, flight.arrTime),
      ));
    }

    return duties;
  }

  // Fill in OFF/RH/SBY days that don't have flights
  void _fillActivityDays(
    String text,
    List<RosterDuty> duties,
    int year,
    int month,
    int daysInMonth,
    Set<int> coveredDays,
  ) {
    // Look for patterns like "RH" or "OFF" near day numbers
    final tokens = text.split(RegExp(r'\s+'));

    for (int i = 0; i < tokens.length - 1; i++) {
      final dayNum = int.tryParse(tokens[i]);
      if (dayNum == null || dayNum < 1 || dayNum > daysInMonth) continue;
      if (coveredDays.contains(dayNum)) continue;

      final next = tokens[i + 1].toUpperCase();
      if (_isActivityCode(next)) {
        duties.add(RosterDuty(
          date: DateTime(year, month, dayNum),
          type: _codeToType(next),
        ));
        coveredDays.add(dayNum);
      }
    }

    // Also scan for "RH" / "OFF" patterns after day-of-week names
    final actPattern = RegExp(
      r'(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun|Lu|Ma|Me|Je|Ve|Sa|Di)\.?\s+'
      r'(RH|OFF|SBY|STBY|DO|JA|C/O)',
      caseSensitive: false,
    );
    // These are harder to associate with specific days without more context
  }

  // --- Helpers ---

  bool _isActivityCode(String token) {
    return ['RH', 'OFF', 'SBY', 'STBY', 'STANDBY', 'REPOS', 'REST', 'DO', 'JA', 'C/O']
        .contains(token.toUpperCase());
  }

  DutyType _codeToType(String code) {
    final upper = code.toUpperCase();
    if (upper == 'SBY' || upper == 'STBY' || upper == 'STANDBY') return DutyType.standby;
    if (upper == 'OFF' || upper == 'DO' || upper == 'JA') return DutyType.off;
    return DutyType.rest;
  }

  String? _extractFlightNum(String token) {
    final match = RegExp(r'^(?:AH)?(\d{3,4})$').firstMatch(token);
    if (match != null) {
      final num = int.tryParse(match.group(1)!);
      if (num != null && num >= 100) {
        return 'AH ${match.group(1)!}';
      }
    }
    return null;
  }

  DateTime? _timeFromStr(int year, int month, int day, String? timeStr) {
    if (timeStr == null) return null;
    final cleaned = timeStr.replaceAll(RegExp(r'[.:]'), '');
    if (cleaned.length < 3) return null;
    final padded = cleaned.padLeft(4, '0');
    final h = int.tryParse(padded.substring(0, 2));
    final m = int.tryParse(padded.substring(2, 4));
    if (h != null && m != null && h >= 0 && h < 24 && m >= 0 && m < 60) {
      return DateTime(year, month, day, h, m);
    }
    return null;
  }

  Map<String, double> _parseStats(String text) {
    final stats = <String, double>{};

    final blockMatch = RegExp(r'Block\s*Hours?\s+(\d+):(\d+)').firstMatch(text);
    if (blockMatch != null) {
      stats['blockHours'] = double.parse(blockMatch.group(1)!) +
          double.parse(blockMatch.group(2)!) / 60;
    }

    final dutyMatch = RegExp(r'Duty\s*Hours?\s+(\d+):(\d+)').firstMatch(text);
    if (dutyMatch != null) {
      stats['dutyHours'] = double.parse(dutyMatch.group(1)!) +
          double.parse(dutyMatch.group(2)!) / 60;
    }

    final landingsMatch = RegExp(r'Landings?\s+(\d+)').firstMatch(text);
    if (landingsMatch != null) {
      stats['landings'] = double.parse(landingsMatch.group(1)!);
    }

    final offMatch = RegExp(r'Off\s*Days?\s+(\d+)').firstMatch(text);
    if (offMatch != null) {
      stats['offDays'] = double.parse(offMatch.group(1)!);
    }

    final flightMatch = RegExp(r'Flight\s*Days?\s+(\d+)').firstMatch(text);
    if (flightMatch != null) {
      stats['flightDays'] = double.parse(flightMatch.group(1)!);
    }

    return stats;
  }

  static String airportName(String code) =>
      airportNames[code] ?? code;
}
