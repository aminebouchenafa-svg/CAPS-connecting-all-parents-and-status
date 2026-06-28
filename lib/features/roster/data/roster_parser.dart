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

  static const _avioDevCodes = {
    '/', '/RH', '//', 'RH', 'OFF', 'DO', 'JA',
    'ESIM', 'ING1', 'ING2', 'ING3', 'ING4', 'ING5',
    'ARRT', 'DEPL', 'ABS', 'HS', 'INST', 'C/O',
    'SBY', 'STBY', 'STANDBY', 'REPOS', 'REST',
  };

  String? lastExtractedText;
  String? lastDebugInfo;

  Roster parse(String text) {
    lastExtractedText = text;
    lastDebugInfo = null;

    final pilotName = _extractField(text, 'NAME');
    final pilotId = _extractField(text, 'ID');
    final base = _extractBase(text);
    final aircraft = _extractAircraft(text);
    final period = _extractPeriod(text);
    final stats = _parseStats(text);
    final duties = _parseDuties(text, period.$1);
    final allStats = _parseAllStats(text);
    var codeExplanations = _parseCodeExplanations(text);
    if (codeExplanations.isEmpty) {
      codeExplanations = _buildFallbackCodeExplanations(duties);
    }

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
      allStats: allStats,
      codeExplanations: codeExplanations,
    );
  }

  // ── Header extraction ──

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
    final regex = RegExp(
        r'Period:\s*(\d{2}/\d{2}/\d{4})\s*START\s*to\s*(\d{2}/\d{2}/\d{4})');
    final match = regex.firstMatch(text);
    if (match != null) {
      return (_parseDate(match.group(1)!), _parseDate(match.group(2)!));
    }
    final now = DateTime.now();
    return (
      DateTime(now.year, now.month, 1),
      DateTime(now.year, now.month + 1, 0)
    );
  }

  DateTime _parseDate(String dateStr) {
    final parts = dateStr.split('/');
    return DateTime(
        int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
  }

  // ── Duty parsing (tries multiple strategies) ──

  List<RosterDuty> _parseDuties(String text, DateTime periodStart) {
    final year = periodStart.year;
    final month = periodStart.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;

    var duties = _trySequentialParse(text, year, month, daysInMonth);

    if (duties.isEmpty) {
      duties = _tryGridParse(text, year, month, daysInMonth);
    }

    if (duties.isEmpty) {
      duties = _tryRowParse(text, year, month, daysInMonth);
    }

    if (duties.isEmpty) {
      duties = _tryTokenParse(text, year, month, daysInMonth);
    }

    if (duties.isEmpty) {
      duties = _tryProximityParse(text, year, month, daysInMonth);
    }

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

  // ── Strategy 0: Sequential parse for AvioDev plain-text extraction ──

  static final _monthAbbr = {
    'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
    'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
  };

  static final _dayOfWeek = RegExp(
    r'^(Mon|Tue|Wed|Thu|Fri|Sat|Sun|Lun|Mar|Mer|Jeu|Ven|Sam|Dim)$',
    caseSensitive: false,
  );

  static final _timePattern = RegExp(r'^(\d{2}):(\d{2})$');

  static final _airportPattern = RegExp(r'^\*?([A-Z]{3})\*?$');

  List<RosterDuty> _trySequentialParse(
      String text, int year, int month, int daysInMonth) {
    final lines = text.split('\n');

    // Step 1: Find the date row ("01 Jun 02 Jun 03 Jun ...")
    int dateRowIdx = -1;
    final dayDates = <DateTime>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      final dateMatches = RegExp(
              r'(\d{2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)')
          .allMatches(line)
          .toList();

      if (dateMatches.length >= 15) {
        dateRowIdx = i;
        for (final m in dateMatches) {
          final day = int.parse(m.group(1)!);
          final mon = _monthAbbr[m.group(2)!]!;
          int y = year;
          if (mon < month) y = year + 1;
          dayDates.add(DateTime(y, mon, day));
        }
        break;
      }
    }

    if (dateRowIdx < 0 || dayDates.isEmpty) return [];

    // Step 2: Find the activity row (skip day-of-week row)
    int activityRowIdx = -1;
    for (int i = dateRowIdx + 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final tokens = line.split(RegExp(r'\s+'));

      if (tokens.length >= 15 && tokens.every((t) => _dayOfWeek.hasMatch(t))) {
        continue;
      }

      final actCount = tokens.where((t) {
        final upper = t.toUpperCase();
        return _avioDevCodes.contains(upper) ||
            _extractFlightNum(upper) != null;
      }).length;

      if (actCount >= 5) {
        activityRowIdx = i;
        break;
      }
    }

    if (activityRowIdx < 0) return [];

    // Step 3: Parse the activity row - map each token to a day index.
    // PDF extraction can split "//" → "/ /" and "/RH" → "/ RH".
    // Strategy: always merge "/ RH" → "/RH" (standalone RH after / is
    // always /RH in AvioDev). Then merge "/ /" → "//" only if needed.
    var rawTokens = lines[activityRowIdx].trim().split(RegExp(r'\s+'));

    // Check if activity row has fewer codes than days - look for continuation
    int _countNonSkip(List<String> tokens) {
      int c = 0;
      for (final t in tokens) {
        if (_dayOfWeek.hasMatch(t) || _monthAbbr.containsKey(t)) continue;
        c++;
      }
      return c;
    }

    if (_countNonSkip(rawTokens) < dayDates.length) {
      for (int i = activityRowIdx + 1; i < lines.length && i < activityRowIdx + 4; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        final tokens = line.split(RegExp(r'\s+'));
        if (tokens.length >= 15 && tokens.every((t) => _dayOfWeek.hasMatch(t))) continue;
        final lower = line.toLowerCase();
        if (lower.contains('block hours') || lower.contains('duty hours') ||
            lower.contains('code explanations') || lower.contains('totals') ||
            RegExp(r'page\s+\d').hasMatch(lower)) break;
        final actCount = tokens.where((t) {
          final upper = t.toUpperCase();
          return _avioDevCodes.contains(upper) || _extractFlightNum(upper) != null;
        }).length;
        if (actCount >= 2) {
          rawTokens = [...rawTokens, ...tokens];
          break;
        }
      }
    }

    // Step 3a: Always merge "/ RH" → "/RH"
    final step1Tokens = <String>[];
    for (int i = 0; i < rawTokens.length; i++) {
      if (rawTokens[i] == '/' && i + 1 < rawTokens.length &&
          rawTokens[i + 1].toUpperCase() == 'RH') {
        step1Tokens.add('/RH');
        i++;
      } else {
        step1Tokens.add(rawTokens[i]);
      }
    }

    // Step 3b: If still too many tokens, merge "/ /" → "//" from end
    int step1Count = _countNonSkip(step1Tokens);
    final List<String> actTokens;
    if (step1Count > dayDates.length) {
      final extraMerges = step1Count - dayDates.length;
      final mergePositions = <int>[];
      for (int i = 0; i < step1Tokens.length - 1; i++) {
        if (step1Tokens[i] == '/' && step1Tokens[i + 1] == '/') {
          mergePositions.add(i);
        }
      }
      final useMerges = <int>{};
      for (int i = mergePositions.length - 1;
          i >= 0 && useMerges.length < extraMerges; i--) {
        useMerges.add(mergePositions[i]);
      }
      final result = <String>[];
      for (int i = 0; i < step1Tokens.length; i++) {
        if (useMerges.contains(i) && i + 1 < step1Tokens.length) {
          result.add('//');
          i++;
        } else {
          result.add(step1Tokens[i]);
        }
      }
      actTokens = result;
    } else {
      actTokens = step1Tokens;
    }

    final dayActivities = <int, String>{};
    final flightDayIndices = <int>[];
    int dayIdx = 0;

    for (int t = 0; t < actTokens.length && dayIdx < dayDates.length; t++) {
      final token = actTokens[t];
      final upper = token.toUpperCase();

      if (_dayOfWeek.hasMatch(token) || _monthAbbr.containsKey(token)) {
        continue;
      }

      if (_avioDevCodes.contains(upper)) {
        dayActivities[dayIdx] = upper;
        dayIdx++;
      } else if (_extractFlightNum(upper) != null) {
        dayActivities[dayIdx] = upper;
        flightDayIndices.add(dayIdx);
        dayIdx++;
      } else {
        dayActivities[dayIdx] = upper;
        dayIdx++;
      }
    }

    if (dayActivities.isEmpty) return [];

    // Debug: store the parsed mapping for troubleshooting
    final debugSb = StringBuffer();
    debugSb.writeln('=== SEQUENTIAL PARSER DEBUG ===');
    debugSb.writeln('Raw tokens (${rawTokens.length}): ${rawTokens.join(" | ")}');
    debugSb.writeln('After /RH merge (${step1Tokens.length}): ${step1Tokens.join(" | ")}');
    debugSb.writeln('Final tokens (${actTokens.length}): ${actTokens.join(" | ")}');
    debugSb.writeln('Day count: ${dayDates.length}, Mapped: $dayIdx');
    debugSb.writeln('Flight days: ${flightDayIndices.length}');
    for (final entry in dayActivities.entries) {
      final di = entry.key;
      final date = di < dayDates.length ? dayDates[di] : null;
      final dayNum = date?.day ?? '?';
      final isF = flightDayIndices.contains(di) ? ' [FLIGHT]' : '';
      debugSb.writeln('  Day $dayNum (idx $di): ${entry.value}$isF');
    }

    // Step 4: Collect data lines between activity row and stats section.
    // Skip duplicate partial activity rows (PDF extraction artifact).
    final actRowText = lines[activityRowIdx].trim();
    final dataLines = <String>[];
    for (int i = activityRowIdx + 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final lower = line.toLowerCase();
      if (lower.contains('block hours') ||
          lower.contains('duty hours') ||
          lower.contains('code explanations') ||
          lower.contains('totals') ||
          lower.contains('other training') ||
          lower.contains('code|description') ||
          RegExp(r'page\s+\d').hasMatch(lower)) {
        break;
      }
      // Stop at single-char indicator row (e.g. "I") or timestamp
      if (RegExp(r'^[A-Z]$').hasMatch(line)) break;
      if (RegExp(r'\d{2}-\d{2}-\d{4}\s+at').hasMatch(line)) break;
      // Skip if this line is a substring of the activity row (duplicate artifact)
      if (line.length > 10 && actRowText.contains(line)) continue;
      dataLines.add(line);
    }

    // Step 5: Extract airport rows (lines with mostly 3-letter codes)
    final airportRows = <List<String>>[];
    for (final dl in dataLines) {
      final tokens = dl.split(RegExp(r'\s+'));
      if (tokens.length < 3) continue;
      int aptCount = 0;
      final apts = <String>[];
      for (final t in tokens) {
        final m = _airportPattern.firstMatch(t.toUpperCase());
        if (m != null && !_avioDevCodes.contains(m.group(1))) {
          aptCount++;
          apts.add(m.group(1)!);
        }
      }
      if (aptCount >= 3 && aptCount > tokens.length * 0.6) {
        airportRows.add(apts);
      }
    }

    // Step 6: Map airport pairs to flight days.
    // Airport rows only contain data for actual flights. ESIM is a
    // simulator briefing and does NOT have airport data. Map first N
    // airports directly to the first N flight days in order.
    final nFlights = flightDayIndices.length;
    final flightRoutes = <int, ({String dep, String arr})>{};

    if (airportRows.length >= 2) {
      final depRow = airportRows[0];
      final arrRow = airportRows[1];
      final n = [depRow.length, arrRow.length, nFlights]
          .reduce((a, b) => a < b ? a : b);

      for (int i = 0; i < n; i++) {
        flightRoutes[flightDayIndices[i]] = (dep: depRow[i], arr: arrRow[i]);
      }
    }

    // Step 7: Extract time rows and map to flight days
    final timeRows = <List<String>>[];
    for (final dl in dataLines) {
      final tokens = dl.split(RegExp(r'\s+'));
      if (tokens.length < 3) continue;
      int timeCount = 0;
      final times = <String>[];
      for (final t in tokens) {
        if (_timePattern.hasMatch(t)) {
          timeCount++;
          times.add(t);
        }
      }
      if (timeCount >= 3 && timeCount > tokens.length * 0.6) {
        timeRows.add(times);
      }
    }

    // Map check-in/check-out times to timed activity days.
    // Timed = flights, HS, SBY, ING*, ESIM, INST
    // Excluded: off/rest codes + ARRT/DEPL (no scheduled times in PDF)
    const _noTimeCodes = {'/', '/RH', '//', 'RH', 'OFF', 'DO', 'JA', 'ABS', 'C/O', 'REPOS', 'REST', 'ARRT', 'DEPL'};
    final timedDayIndices = <int>[];
    for (int di = 0; di < dayDates.length; di++) {
      final act = dayActivities[di];
      if (act == null) continue;
      final upper = act.toUpperCase();
      if (_noTimeCodes.contains(upper)) continue;
      timedDayIndices.add(di);
    }

    final flightTimes = <int, ({String checkIn, String checkOut})>{};
    if (timeRows.length >= 2) {
      final checkInRow = timeRows[0];
      final checkOutRow = timeRows[1];
      final n = [checkInRow.length, checkOutRow.length, timedDayIndices.length]
          .reduce((a, b) => a < b ? a : b);
      for (int i = 0; i < n; i++) {
        flightTimes[timedDayIndices[i]] = (
          checkIn: checkInRow[i],
          checkOut: checkOutRow[i],
        );
      }
    }

    // Step 8: Extract extra flight rows (2nd legs, 3rd legs, etc.)
    final extraFlightRows = <List<String>>[];
    for (final dl in dataLines) {
      final tokens = dl.split(RegExp(r'\s+'));
      if (tokens.length < 3) continue;
      int fnCount = 0;
      final fns = <String>[];
      for (final t in tokens) {
        final fn = _extractFlightNum(t.toUpperCase());
        if (fn != null) {
          fnCount++;
          fns.add(fn);
        }
      }
      if (fnCount >= 3 && fnCount > tokens.length * 0.5) {
        extraFlightRows.add(fns);
      }
    }

    // Match extra legs by route continuity across all tiers:
    //   2nd-leg departure == 1st-leg arrival
    //   3rd-leg departure == 2nd-leg arrival
    //   etc.
    // Airport rows alternate dep/arr per tier:
    //   [0]=1st dep, [1]=1st arr, [2]=2nd dep, [3]=2nd arr, ...
    final extraLegs = <int, List<({String fn, String? dep, String? arr})>>{};
    for (int r = 0; r < extraFlightRows.length; r++) {
      final row = extraFlightRows[r];

      final depRowIdx = 2 + r * 2;
      final arrRowIdx = 3 + r * 2;
      final depN = depRowIdx < airportRows.length ? airportRows[depRowIdx] : null;
      final arrN = arrRowIdx < airportRows.length ? airportRows[arrRowIdx] : null;

      final matched = <int>{};
      for (int i = 0; i < row.length; i++) {
        final dN = depN != null && i < depN.length ? depN[i] : null;
        final aN = arrN != null && i < arrN.length ? arrN[i] : null;

        if (dN == null) continue;

        for (final fi in flightDayIndices) {
          if (matched.contains(fi)) continue;

          String? prevArr;
          if (r == 0) {
            prevArr = flightRoutes[fi]?.arr;
          } else {
            final legs = extraLegs[fi];
            if (legs != null && legs.length >= r) {
              prevArr = legs[r - 1].arr;
            }
          }

          if (prevArr == dN) {
            matched.add(fi);
            extraLegs.putIfAbsent(fi, () => []);
            extraLegs[fi]!.add((fn: row[i], dep: dN, arr: aN));
            break;
          }
        }
      }
    }

    // Step 8: Build duties
    final duties = <RosterDuty>[];

    for (final entry in dayActivities.entries) {
      final di = entry.key;
      if (di >= dayDates.length) continue;
      final date = dayDates[di];
      if (date.month != month || date.day > daysInMonth) continue;

      final upper = entry.value;

      if (_avioDevCodes.contains(upper)) {
        final times = flightTimes[di];
        DateTime? checkIn = _timeFromStr(date.year, date.month, date.day, times?.checkIn);
        DateTime? checkOut = _timeFromStr(date.year, date.month, date.day, times?.checkOut);
        if (['HS', 'SBY', 'STBY', 'STANDBY'].contains(upper) && checkIn == null && checkOut == null) {
          checkIn = DateTime(date.year, date.month, date.day, 7, 0);
          checkOut = DateTime(date.year, date.month, date.day, 21, 0);
        }
        duties.add(RosterDuty(
          date: date,
          type: _avioDevType(upper),
          activityCode: upper,
          notes: _avioDevLabel(upper),
          checkIn: checkIn,
          checkOut: checkOut,
        ));
        continue;
      }

      final fn = _extractFlightNum(upper);
      if (fn != null) {
        final route = flightRoutes[di];
        final times = flightTimes[di];

        duties.add(RosterDuty(
          date: date,
          type: DutyType.flight,
          flightNumber: fn,
          departure: route?.dep,
          arrival: route?.arr,
          checkIn: _timeFromStr(
              date.year, date.month, date.day, times?.checkIn),
          checkOut: _timeFromStr(
              date.year, date.month, date.day, times?.checkOut),
        ));

        // Add 2nd leg if available
        final extras = extraLegs[di];
        if (extras != null) {
          for (final leg in extras) {
            duties.add(RosterDuty(
              date: date,
              type: DutyType.flight,
              flightNumber: leg.fn,
              departure: leg.dep,
              arrival: leg.arr,
            ));
          }
        }
        continue;
      }

      duties.add(RosterDuty(
        date: date,
        type: DutyType.off,
        activityCode: upper,
        notes: upper,
      ));
    }

    // Store debug info
    debugSb.writeln('Airport rows found: ${airportRows.length}');
    for (int r = 0; r < airportRows.length; r++) {
      debugSb.writeln('  Row $r (${airportRows[r].length}): ${airportRows[r].join(" ")}');
    }
    debugSb.writeln('Flight days: $nFlights');
    debugSb.writeln('Routes mapped:');
    for (final fi in flightDayIndices) {
      final route = flightRoutes[fi];
      final date = fi < dayDates.length ? dayDates[fi] : null;
      final fn = dayActivities[fi] ?? '?';
      debugSb.writeln('  Day ${date?.day} $fn: ${route?.dep ?? "?"} → ${route?.arr ?? "?"}');
    }
    debugSb.writeln('Extra flight rows: ${extraFlightRows.length}');
    for (int r = 0; r < extraFlightRows.length; r++) {
      debugSb.writeln('  Tier ${r + 2} (${extraFlightRows[r].length}): ${extraFlightRows[r].join(" ")}');
    }
    debugSb.writeln('Extra legs mapped: ${extraLegs.length} days');
    for (final e in extraLegs.entries) {
      final date = e.key < dayDates.length ? dayDates[e.key] : null;
      for (int l = 0; l < e.value.length; l++) {
        final leg = e.value[l];
        debugSb.writeln('  Day ${date?.day} leg${l + 2} ${leg.fn}: ${leg.dep ?? "?"} → ${leg.arr ?? "?"}');
      }
    }
    debugSb.writeln('Time rows found: ${timeRows.length}');
    for (int r = 0; r < timeRows.length; r++) {
      debugSb.writeln('  Time row $r (${timeRows[r].length}): ${timeRows[r].join(" ")}');
    }
    debugSb.writeln('Timed days: ${timedDayIndices.length} indices: $timedDayIndices');
    debugSb.writeln('Times mapped: ${flightTimes.length}');
    for (final e in flightTimes.entries) {
      final date = e.key < dayDates.length ? dayDates[e.key] : null;
      final act = dayActivities[e.key] ?? '?';
      debugSb.writeln('  Day ${date?.day} ($act): ${e.value.checkIn} → ${e.value.checkOut}');
    }
    debugSb.writeln('Flights detected: ${duties.where((d) => d.isFlight).length}');
    lastDebugInfo = debugSb.toString();

    return duties;
  }

  // ── Strategy 1: Grid (column-aligned tab-separated from AvioDev PDF) ──

  int? _dayFromCell(String cell) {
    if (cell.isEmpty) return null;
    final match = RegExp(r'^(\d{1,2})').firstMatch(cell);
    if (match == null) return null;
    final d = int.tryParse(match.group(1)!);
    if (d == null || d < 1 || d > 31) return null;
    final rest = cell.substring(match.end).trim();
    if (rest.isNotEmpty && RegExp(r'^\d').hasMatch(rest)) return null;
    return d;
  }

  List<RosterDuty> _tryGridParse(
      String text, int year, int month, int daysInMonth) {
    final lines = text.split('\n');

    int? dateRowIdx;
    final colToDay = <int, int>{};

    for (int i = 0; i < lines.length; i++) {
      final cells = lines[i].split('\t');
      if (cells.length < 10) continue;

      final temp = <int, int>{};
      for (int j = 0; j < cells.length; j++) {
        final day = _dayFromCell(cells[j].trim());
        if (day != null) temp[j] = day;
      }

      if (temp.length >= 10) {
        final days = temp.values.toList()..sort();
        int maxC = 1, cur = 1;
        for (int k = 1; k < days.length; k++) {
          if (days[k] == days[k - 1] + 1) {
            cur++;
            if (cur > maxC) maxC = cur;
          } else {
            cur = 1;
          }
        }
        if (maxC >= 10) {
          dateRowIdx = i;
          colToDay.addAll(temp);
          break;
        }
      }
    }

    if (dateRowIdx == null) return [];

    final dayData = <int, List<String>>{};
    for (final day in colToDay.values) {
      dayData[day] = [];
    }

    for (int i = dateRowIdx + 1; i < lines.length; i++) {
      final lineText = lines[i].toLowerCase();
      if (lineText.contains('block hours') ||
          lineText.contains('duty hours') ||
          lineText.contains('off days') ||
          lineText.contains('flight days') ||
          lineText.contains('total landings')) {
        break;
      }

      final cells = lines[i].split('\t');
      for (final entry in colToDay.entries) {
        final col = entry.key;
        final day = entry.value;
        if (col < cells.length) {
          final val = cells[col].trim();
          if (val.isNotEmpty) {
            dayData[day]!.add(val);
          }
        }
      }
    }

    final duties = <RosterDuty>[];
    for (final entry in dayData.entries) {
      final day = entry.key;
      if (day > daysInMonth) continue;
      final values = entry.value;
      if (values.isEmpty) continue;
      duties.addAll(_parseDayColumn(values, year, month, day));
    }

    return duties;
  }

  List<RosterDuty> _parseDayColumn(
      List<String> values, int year, int month, int day) {
    final duties = <RosterDuty>[];
    final flightNums = <String>[];
    final airports = <String>[];
    final times = <DateTime>[];
    bool hasActivity = false;
    DutyType actType = DutyType.off;
    String? actCode;
    String? actNotes;

    for (final v in values) {
      final cleaned = v.replaceAll('*', '').trim();
      final upper = cleaned.toUpperCase();

      if (RegExp(
              r'^(Mon|Tue|Wed|Thu|Fri|Sat|Sun|Lun|Mar|Mer|Jeu|Ven|Sam|Dim)$',
              caseSensitive: false)
          .hasMatch(cleaned)) continue;
      if (RegExp(r'^(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)$',
              caseSensitive: false)
          .hasMatch(cleaned)) continue;

      if (_avioDevCodes.contains(upper)) {
        hasActivity = true;
        actType = _avioDevType(upper);
        actCode = upper;
        actNotes = _avioDevLabel(upper);
        continue;
      }

      final fn = _extractFlightNum(upper);
      if (fn != null) {
        flightNums.add(fn);
        continue;
      }

      final apt = upper.replaceAll('*', '');
      if (RegExp(r'^[A-Z]{3}$').hasMatch(apt) && !_avioDevCodes.contains(apt)) {
        airports.add(apt);
        continue;
      }

      final time = _timeFromStr(year, month, day, cleaned);
      if (time != null) {
        times.add(time);
        continue;
      }
    }

    if (hasActivity && flightNums.isEmpty) {
      duties.add(RosterDuty(
        date: DateTime(year, month, day),
        type: actType,
        activityCode: actCode,
        notes: actNotes,
      ));
      return duties;
    }

    for (int i = 0; i < flightNums.length; i++) {
      duties.add(RosterDuty(
        date: DateTime(year, month, day),
        type: DutyType.flight,
        flightNumber: flightNums[i],
        departure: (i * 2) < airports.length ? airports[i * 2] : null,
        arrival: (i * 2 + 1) < airports.length ? airports[i * 2 + 1] : null,
        checkIn: (i * 2) < times.length ? times[i * 2] : null,
        checkOut: (i * 2 + 1) < times.length ? times[i * 2 + 1] : null,
      ));
    }

    return duties;
  }

  // ── Strategy 2: Row-based (one duty per line with day number) ──

  List<RosterDuty> _tryRowParse(
      String text, int year, int month, int daysInMonth) {
    final duties = <RosterDuty>[];
    final lines = text.split(RegExp(r'[\r\n]+'));

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.length < 3) continue;

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

  // ── Strategy 3: Token sequences (day + flight + airport) ──

  List<RosterDuty> _tryTokenParse(
      String text, int year, int month, int daysInMonth) {
    final duties = <RosterDuty>[];
    final tokens = text.split(RegExp(r'\s+'));

    for (int i = 0; i < tokens.length - 1; i++) {
      final dayNum = int.tryParse(tokens[i]);
      if (dayNum == null || dayNum < 1 || dayNum > daysInMonth) continue;

      final next = tokens[i + 1].toUpperCase();

      if (_isActivityCode(next)) {
        duties.add(RosterDuty(
          date: DateTime(year, month, dayNum),
          type: _codeToType(next),
        ));
        i++;
        continue;
      }

      final flightNum = _extractFlightNum(next);
      if (flightNum != null) {
        String? dep, arr, depTime, arrTime;

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

  // ── Strategy 4: Proximity (flights near day numbers) ──

  List<RosterDuty> _tryProximityParse(
      String text, int year, int month, int daysInMonth) {
    final duties = <RosterDuty>[];

    final allMatches =
        <({int pos, String flightNum, String? dep, String? arr, String? depTime, String? arrTime})>[];

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

    final dayPositions = <({int pos, int day})>[];
    final dayPattern = RegExp(r'(?:^|\s)(\d{1,2})(?:\s|$)');
    for (final match in dayPattern.allMatches(text)) {
      final day = int.tryParse(match.group(1)!);
      if (day != null && day >= 1 && day <= daysInMonth) {
        dayPositions.add((pos: match.start, day: day));
      }
    }

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

  // ── Fill uncovered days with activity codes from text ──

  void _fillActivityDays(
    String text,
    List<RosterDuty> duties,
    int year,
    int month,
    int daysInMonth,
    Set<int> coveredDays,
  ) {
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
          activityCode: next,
          notes: _avioDevLabel(next),
        ));
        coveredDays.add(dayNum);
      }
    }
  }

  // ── AvioDev helpers ──

  static DutyType _avioDevType(String code) {
    if (['/', 'OFF', 'DO', 'JA'].contains(code)) {
      return DutyType.off;
    }
    if (['/RH', '//', 'RH'].contains(code)) {
      return DutyType.rest;
    }
    if (code == 'ESIM') return DutyType.simulator;
    if (['ING1', 'ING2', 'ING3', 'ING4', 'ING5', 'INST'].contains(code)) {
      return DutyType.training;
    }
    if (['SBY', 'STBY', 'STANDBY', 'HS'].contains(code)) return DutyType.standby;
    if (['ARRT', 'DEPL'].contains(code)) return DutyType.deadhead;
    if (['ABS', 'C/O', 'REPOS', 'REST'].contains(code)) {
      return DutyType.rest;
    }
    return DutyType.off;
  }

  static String _avioDevLabel(String code) {
    return switch (code) {
      '/' => 'Sans activité programmée',
      '//' => 'Repos post-courrier',
      '/RH' || 'RH' => 'Repos Hebdomadaire',
      'OFF' || 'DO' || 'JA' => 'OFF',
      'ESIM' => 'Simulateur à l\'Etranger',
      'ING1' => 'Simu NG Kouba 04:30 UTC',
      'ING2' => 'Simu NG Kouba',
      'ING3' => 'Simu NG Kouba 13:00 UTC',
      'ING4' => 'Simu NG Kouba',
      'ING5' => 'Simu NG Kouba 08:45 UTC',
      'ARRT' => 'Arrivée tardive',
      'DEPL' => 'Mission',
      'ABS' => 'Absence',
      'HS' => 'Home Standby',
      'INST' => 'Instructeur Ligne PNT',
      'C/O' => 'Check Out',
      'SBY' || 'STBY' || 'STANDBY' => 'Standby',
      'REPOS' || 'REST' => 'Repos',
      _ => code,
    };
  }

  // ── Shared helpers ──

  bool _isActivityCode(String token) =>
      _avioDevCodes.contains(token.toUpperCase());

  DutyType _codeToType(String code) => _avioDevType(code.toUpperCase());

  String? _extractFlightNum(String token) {
    final match = RegExp(r'^(?:AH\s*)?(\d{3,4})$').firstMatch(token);
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

    final blockMatch =
        RegExp(r'Block\s*Hours?\s+(\d+):(\d+)').firstMatch(text);
    if (blockMatch != null) {
      stats['blockHours'] = double.parse(blockMatch.group(1)!) +
          double.parse(blockMatch.group(2)!) / 60;
    }

    final dutyMatch =
        RegExp(r'Duty\s*Hours?\s+(\d+):(\d+)').firstMatch(text);
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

  Map<String, String> _parseAllStats(String text) {
    final stats = <String, String>{};
    final statPatterns = [
      (r'Block\s*Hours?\s+(\d+:\d+)', 'Block Hours'),
      (r'Duty\s*Hours?\s+(\d+:\d+)', 'Duty Hours'),
      (r'Night\s*Hours?\s+(\d+:\d+)', 'Night Hours'),
      (r'S1\s*Hours?\s+(\d+:\d+)', 'S1 Hours'),
      (r'International\s+Layover\s+Hours?\s+(\d+:\d+)', 'International Layover Hours'),
      (r'Domestic\s+Layover\s+Hours?\s+(\d+:\d+)', 'Domestic Layover Hours'),
      (r'Out\s+of\s+Base\s+Rest\s+(\d+:\d+)', 'Out of Base Rest'),
      (r'Time\s+Away\s+from\s+Base\s+(\d+:\d+)', 'Time Away from Base'),
      (r'StandBy\s*Days?\s+(\d+)', 'StandBy Days'),
      (r'Training\s*Days?\s+(\d+)', 'Training Days'),
      (r'Off\s*Days?\s+(\d+)', 'Off Days'),
      (r'Flight\s*Days?\s+(\d+)', 'Flight Days'),
      (r'Landings?\s+(\d+)', 'Landings'),
    ];
    for (final (pattern, label) in statPatterns) {
      final match = RegExp(pattern).firstMatch(text);
      if (match != null) {
        stats[label] = match.group(1)!;
      }
    }
    return stats;
  }

  Map<String, String> _parseCodeExplanations(String text) {
    final codes = <String, String>{};

    // Try multiple section headers
    final sectionPatterns = [
      RegExp(r'CODE\s*EXPLANATION[S]?(.*?)(?:TOTALS|OTHER\s+TRAINING|Page\s+\d|$)', dotAll: true, caseSensitive: false),
      RegExp(r'CODE\s*DESCRIPTION(.*?)(?:TOTALS|OTHER\s+TRAINING|Page\s+\d|$)', dotAll: true, caseSensitive: false),
      RegExp(r'CODE\s*\|\s*DESCRIPTION(.*?)(?:TOTALS|OTHER\s+TRAINING|Page\s+\d|$)', dotAll: true, caseSensitive: false),
    ];

    String? block;
    for (final pattern in sectionPatterns) {
      final section = pattern.firstMatch(text);
      if (section != null) {
        block = section.group(1)!;
        break;
      }
    }

    if (block != null) {
      // Try pipe-separated format: CODE | DESCRIPTION
      final pipeMatches = RegExp(r'(\S+)\s*\|\s*(.+?)(?=\n|\s{2,}\S+\s*\||$)')
          .allMatches(block);
      for (final m in pipeMatches) {
        final code = m.group(1)!.trim();
        final desc = m.group(2)!.trim();
        if (code.toUpperCase() != 'CODE' && desc.toUpperCase() != 'DESCRIPTION') {
          codes[code] = desc;
        }
      }

      // Try tab-separated format
      if (codes.isEmpty) {
        for (final line in block.split('\n')) {
          final parts = line.split('\t');
          for (int i = 0; i < parts.length - 1; i += 2) {
            final code = parts[i].trim();
            final desc = i + 1 < parts.length ? parts[i + 1].trim() : '';
            if (code.isNotEmpty && desc.isNotEmpty && code.toUpperCase() != 'CODE') {
              codes[code] = desc;
            }
          }
        }
      }

      // Try space-separated: CODE Description text
      if (codes.isEmpty) {
        for (final line in block.split('\n')) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;
          final m = RegExp(r'^(//?(?:RH)?|[A-Z][A-Z0-9/]{1,8})\s+(.+)$').firstMatch(trimmed);
          if (m != null) {
            final code = m.group(1)!.trim();
            final desc = m.group(2)!.trim();
            if (code.toUpperCase() != 'CODE' && desc.toUpperCase() != 'DESCRIPTION' && desc.length > 1) {
              codes[code] = desc;
            }
          }
        }
      }
    }

    return codes;
  }

  Map<String, String> _buildFallbackCodeExplanations(List<RosterDuty> duties) {
    final codes = <String, String>{};
    for (final duty in duties) {
      final code = duty.activityCode;
      if (code != null && code.isNotEmpty && !codes.containsKey(code)) {
        codes[code] = _avioDevLabel(code);
      }
    }
    return codes;
  }

  static String airportName(String code) => airportNames[code] ?? code;
}
