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
    'AZR': 'Adrar',
    'TMX': 'Timimoun',
    'ELU': 'El Oued',
    'LOO': 'Laghouat',
    'MZW': 'Mecheria',
    'IAM': 'In Amenas',
    'HME': 'Hassi Messaoud',
    'OGX': 'Ouargla',
    'INZ': 'In Salah',
    'DJG': 'Djanet',
    'TID': 'Tiaret',
    'BFW': 'Sidi Bel Abbès',
    'MUW': 'Mascara',
    'TIN': 'Tindouf',
    'BSK': 'Biskra',
    'EBH': 'El Bayadh',
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
    'LIS': 'Lisbonne',
    'ATH': 'Athènes',
    'VIE': 'Vienne',
    'ZRH': 'Zurich',
    'MLH': 'Mulhouse',
    'NTE': 'Nantes',
    'TLS': 'Toulouse',
    'NCE': 'Nice',
    'BOD': 'Bordeaux',
    'MPL': 'Montpellier',
  };

  static const _avioDevCodes = {
    '/', '/RH', '//', 'RH', 'OFF', 'DO', 'JA',
    'ESIM', 'ISIM', 'ING1', 'ING2', 'ING3', 'ING4', 'ING5',
    'ARRT', 'DEPL', 'ABS', 'HS', 'INST', 'C/O',
    'SBY', 'STBY', 'STANDBY', 'REPOS', 'REST',
    'CGET', 'GRTS', 'ESTG', 'ENG2', 'ESSP', '#',
    'ENG1', 'ENG3', 'ENG4', 'ENG5',
    'ELRN', 'BFGS', 'BFGE', 'CONV',
    'EDGR', 'STGE', '-->', 'LVO',
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
    final parsedExplanations = _parseCodeExplanations(text);
    final fallbackExplanations = _buildFallbackCodeExplanations(duties);
    // Merge: parsed descriptions take priority, fallback fills gaps
    final codeExplanations = <String, String>{...fallbackExplanations, ...parsedExplanations};

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

    // Fix cross-midnight flights: if arrival is before departure, the flight
    // crossed midnight so add 1 day to the arrival time.
    for (int i = 0; i < duties.length; i++) {
      final d = duties[i];
      if (d.isFlight && d.checkIn != null && d.checkOut != null &&
          d.checkOut!.isBefore(d.checkIn!)) {
        duties[i] = RosterDuty(
          date: d.date,
          type: d.type,
          flightNumber: d.flightNumber,
          departure: d.departure,
          arrival: d.arrival,
          checkIn: d.checkIn,
          checkOut: d.checkOut!.add(const Duration(days: 1)),
          notes: d.notes,
          activityCode: d.activityCode,
        );
      }
    }

    // Sanity check: flag flights with unrealistic duration (> 16h)
    for (int i = 0; i < duties.length; i++) {
      final d = duties[i];
      if (d.isFlight && d.checkIn != null && d.checkOut != null) {
        final durationMin = d.checkOut!.difference(d.checkIn!).inMinutes;
        if (durationMin > 16 * 60) {
          duties[i] = RosterDuty(
            date: d.date,
            type: d.type,
            flightNumber: d.flightNumber,
            departure: d.departure,
            arrival: d.arrival,
            checkIn: d.checkIn,
            checkOut: null,
            notes: '${d.notes ?? ''} [durée suspecte]'.trim(),
            activityCode: d.activityCode,
          );
        }
      }
    }

    duties.sort((a, b) {
      final cmp = a.date.compareTo(b.date);
      if (cmp != 0) return cmp;
      if (a.checkIn != null && b.checkIn != null) {
        return a.checkIn!.compareTo(b.checkIn!);
      }
      return 0;
    });

    // Deduplicate: remove duplicate flights on the same date with the same
    // flight number. Keep the entry with the most complete data.
    final seen = <String>{};
    duties.removeWhere((d) {
      if (!d.isFlight || d.flightNumber == null) return false;
      final key = '${d.date.year}-${d.date.month}-${d.date.day}_${d.flightNumber}';
      if (seen.contains(key)) return true;
      seen.add(key);
      return false;
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

    // Filter out dates not in the target month (PDF grid may include next month's 1st)
    dayDates.removeWhere((d) => d.month != month || d.year != year);

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

    final consumedLineIndices = <int>{};

    if (_countNonSkip(rawTokens) < dayDates.length) {
      for (int i = activityRowIdx + 1; i < lines.length && i < activityRowIdx + 5; i++) {
        if (_countNonSkip(rawTokens) >= dayDates.length) break;
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        final tokens = line.split(RegExp(r'\s+'));
        if (tokens.length >= 15 && tokens.every((t) => _dayOfWeek.hasMatch(t))) continue;
        final lower = line.toLowerCase();
        if (lower.contains('block hours') || lower.contains('duty hours') ||
            lower.contains('code explanations') || lower.contains('totals') ||
            RegExp(r'page\s+\d').hasMatch(lower)) break;

        // Count activity codes vs flight numbers separately.
        // If line is mostly flight numbers, it's likely an extra flight row
        // for 2nd+ legs — do NOT merge it into the activity row.
        int codeCount = 0;
        int fnCount = 0;
        for (final t in tokens) {
          final upper = t.toUpperCase();
          if (_avioDevCodes.contains(upper)) {
            codeCount++;
          } else if (_extractFlightNum(upper) != null) {
            fnCount++;
          }
        }
        if (fnCount > 0 && fnCount >= codeCount && codeCount == 0) {
          // Line has only flight numbers, no activity codes — skip it
          continue;
        }
        if (codeCount + fnCount >= 1) {
          rawTokens = [...rawTokens, ...tokens];
          consumedLineIndices.add(i);
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
    final outstationDayIndices = <int>[];
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
      } else if (RegExp(r'^[A-Z]{3}$').hasMatch(upper) && airportNames.containsKey(upper)) {
        dayActivities[dayIdx] = upper;
        outstationDayIndices.add(dayIdx);
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
    debugSb.writeln('Consumed continuation lines: ${consumedLineIndices.length} (indices: $consumedLineIndices)');
    debugSb.writeln('Raw tokens (${rawTokens.length}): ${rawTokens.join(" | ")}');
    debugSb.writeln('After /RH merge (${step1Tokens.length}): ${step1Tokens.join(" | ")}');
    debugSb.writeln('Final tokens (${actTokens.length}): ${actTokens.join(" | ")}');
    debugSb.writeln('Day count: ${dayDates.length}, Mapped: $dayIdx');
    debugSb.writeln('Flight days: ${flightDayIndices.length}');
    debugSb.writeln('Outstation days: ${outstationDayIndices.length}');
    for (final entry in dayActivities.entries) {
      final di = entry.key;
      final date = di < dayDates.length ? dayDates[di] : null;
      final dayNum = date?.day ?? '?';
      final isF = flightDayIndices.contains(di) ? ' [FLIGHT]' : '';
      final isO = outstationDayIndices.contains(di) ? ' [OUTSTATION]' : '';
      debugSb.writeln('  Day $dayNum (idx $di): ${entry.value}$isF$isO');
    }

    // Step 4: Collect data lines between activity row and stats section.
    // Skip lines already consumed by activity row continuation and
    // duplicate partial activity rows (PDF extraction artifact).
    final actRowText = lines[activityRowIdx].trim();
    final dataLines = <String>[];
    for (int i = activityRowIdx + 1; i < lines.length; i++) {
      if (consumedLineIndices.contains(i)) continue;
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
    // Store both flat lists (fallback) and raw lines (for tab-based mapping)
    final airportRows = <List<String>>[];
    final airportRawLines = <String>[];
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
        airportRawLines.add(dl);
      }
    }

    // Step 5b: Build column-to-day mapping from date row tab structure
    final dateTabCells = lines[dateRowIdx].split('\t');
    final colToDayIdx = <int, int>{};
    final dayNumToIdx = <int, int>{};
    for (int di = 0; di < dayDates.length; di++) {
      dayNumToIdx[dayDates[di].day] = di;
    }
    for (int j = 0; j < dateTabCells.length; j++) {
      final cell = dateTabCells[j].trim();
      final dayMatch = RegExp(r'^(\d{1,2})').firstMatch(cell);
      if (dayMatch != null) {
        final d = int.tryParse(dayMatch.group(1)!);
        if (d != null && d >= 1 && d <= daysInMonth) {
          final rest = cell.substring(dayMatch.end).trim();
          if (rest.isEmpty || !RegExp(r'^\d').hasMatch(rest)) {
            final idx = dayNumToIdx[d];
            if (idx != null) colToDayIdx[j] = idx;
          }
        }
      }
    }

    // Step 6: Map airport pairs to flight days.
    final nFlights = flightDayIndices.length;
    final flightRoutes = <int, ({String dep, String arr})>{};

    // Primary: tab-based column mapping (eliminates alignment bugs)
    if (colToDayIdx.isNotEmpty && airportRawLines.length >= 2) {
      final depTabs = airportRawLines[0].split('\t');
      final arrTabs = airportRawLines[1].split('\t');

      for (final entry in colToDayIdx.entries) {
        final col = entry.key;
        final dayIdx = entry.value;
        if (!flightDayIndices.contains(dayIdx)) continue;

        final dep = col < depTabs.length
            ? depTabs[col].trim().toUpperCase().replaceAll('*', '') : '';
        final arr = col < arrTabs.length
            ? arrTabs[col].trim().toUpperCase().replaceAll('*', '') : '';

        if (dep.isNotEmpty && RegExp(r'^[A-Z]{3}$').hasMatch(dep) &&
            arr.isNotEmpty && RegExp(r'^[A-Z]{3}$').hasMatch(arr)) {
          flightRoutes[dayIdx] = (dep: dep, arr: arr);
        }
      }
    }

    // Fallback: flat-list mapping if tab mapping found nothing
    if (flightRoutes.isEmpty && airportRows.length >= 2) {
      final depRow = airportRows[0];
      final arrRow = airportRows[1];
      final allAirportDays = [...flightDayIndices, ...outstationDayIndices]..sort();
      final List<int> mappingIndices;
      if (allAirportDays.length > nFlights && depRow.length == allAirportDays.length) {
        mappingIndices = allAirportDays;
      } else {
        mappingIndices = flightDayIndices;
      }
      final n = [depRow.length, arrRow.length, mappingIndices.length]
          .reduce((a, b) => a < b ? a : b);
      for (int i = 0; i < n; i++) {
        final dayIndex = mappingIndices[i];
        if (flightDayIndices.contains(dayIndex)) {
          flightRoutes[dayIndex] = (dep: depRow[i], arr: arrRow[i]);
        }
      }
    }

    // Step 7: Extract time rows and map to flight days
    final timeRows = <List<String>>[];
    final timeRawLines = <String>[];
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
        timeRawLines.add(dl);
      }
    }

    // Map check-in/check-out times to timed activity days.
    const _noTimeCodes = {'/', '/RH', '//', 'RH', 'OFF', 'DO', 'JA', 'ABS', 'C/O', 'REPOS', 'REST', 'ARRT', 'DEPL', '#', 'CGET'};
    final timedDayIndices = <int>[];
    for (int di = 0; di < dayDates.length; di++) {
      final act = dayActivities[di];
      if (act == null) continue;
      final upper = act.toUpperCase();
      if (_noTimeCodes.contains(upper)) continue;
      if (outstationDayIndices.contains(di)) continue;
      timedDayIndices.add(di);
    }

    final flightTimes = <int, ({String checkIn, String checkOut})>{};

    // Primary: tab-based time mapping
    if (colToDayIdx.isNotEmpty && timeRawLines.length >= 2) {
      final checkInTabs = timeRawLines[0].split('\t');
      final checkOutTabs = timeRawLines[1].split('\t');

      for (final entry in colToDayIdx.entries) {
        final col = entry.key;
        final dayIdx = entry.value;
        if (!timedDayIndices.contains(dayIdx)) continue;

        final ci = col < checkInTabs.length ? checkInTabs[col].trim() : '';
        final co = col < checkOutTabs.length ? checkOutTabs[col].trim() : '';

        if (ci.isNotEmpty && _timePattern.hasMatch(ci) &&
            co.isNotEmpty && _timePattern.hasMatch(co)) {
          flightTimes[dayIdx] = (checkIn: ci, checkOut: co);
        }
      }
    }

    // Fallback: flat-list time mapping
    if (flightTimes.isEmpty && timeRows.length >= 2) {
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

    // Step 7b: Map STA (arrival) from timeRows[2] to flight days
    final flightArrivalTimes = <int, String>{};

    // Primary: tab-based STA mapping
    if (colToDayIdx.isNotEmpty && timeRawLines.length >= 3) {
      final staTabs = timeRawLines[2].split('\t');
      for (final entry in colToDayIdx.entries) {
        final col = entry.key;
        final dayIdx = entry.value;
        if (!flightDayIndices.contains(dayIdx)) continue;
        final sta = col < staTabs.length ? staTabs[col].trim() : '';
        if (sta.isNotEmpty && _timePattern.hasMatch(sta)) {
          flightArrivalTimes[dayIdx] = sta;
        }
      }
    }

    // Fallback: flat-list STA mapping
    if (flightArrivalTimes.isEmpty && timeRows.length >= 3 && flightDayIndices.isNotEmpty) {
      final staRow = timeRows[2];
      final n = [staRow.length, flightDayIndices.length].reduce((a, b) => a < b ? a : b);
      for (int i = 0; i < n; i++) {
        flightArrivalTimes[flightDayIndices[i]] = staRow[i];
      }
    }

    // Step 8: Extract extra flight rows (2nd legs, 3rd legs, etc.)
    final extraFlightRows = <List<String>>[];
    final extraFlightRawLines = <String>[];
    for (final dl in dataLines) {
      final tokens = dl.split(RegExp(r'\s+'));
      if (tokens.isEmpty) continue;
      int fnCount = 0;
      int aptCount = 0;
      int timeCount = 0;
      final fns = <String>[];
      for (final t in tokens) {
        final fn = _extractFlightNum(t.toUpperCase());
        if (fn != null) {
          fnCount++;
          fns.add(fn);
        }
        if (_airportPattern.hasMatch(t.toUpperCase())) aptCount++;
        if (_timePattern.hasMatch(t)) timeCount++;
      }
      if (aptCount > fnCount || timeCount > fnCount) continue;
      if (fnCount >= 1 && fnCount >= tokens.length * 0.4) {
        extraFlightRows.add(fns);
        extraFlightRawLines.add(dl);
      }
    }

    // Step 8 - extra legs: use tab-based column mapping when available
    final extraLegs = <int, List<({String fn, String? dep, String? arr})>>{};

    // Primary: tab-based mapping for extra legs
    if (colToDayIdx.isNotEmpty && airportRawLines.length >= 4) {
      for (int tier = 1; tier * 2 + 1 < airportRawLines.length; tier++) {
        final depTabs = airportRawLines[tier * 2].split('\t');
        final arrTabs = airportRawLines[tier * 2 + 1].split('\t');

        // Find extra flight numbers via tab mapping too
        final fnTabs = tier - 1 < extraFlightRawLines.length
            ? extraFlightRawLines[tier - 1].split('\t') : <String>[];

        for (final entry in colToDayIdx.entries) {
          final col = entry.key;
          final dayIdx = entry.value;
          if (!flightDayIndices.contains(dayIdx)) continue;

          final dep = col < depTabs.length
              ? depTabs[col].trim().toUpperCase().replaceAll('*', '') : '';
          final arr = col < arrTabs.length
              ? arrTabs[col].trim().toUpperCase().replaceAll('*', '') : '';

          if (dep.isEmpty || !RegExp(r'^[A-Z]{3}$').hasMatch(dep)) continue;
          if (arr.isEmpty || !RegExp(r'^[A-Z]{3}$').hasMatch(arr)) continue;

          String fn = 'AH ???';
          if (col < fnTabs.length) {
            final extracted = _extractFlightNum(fnTabs[col].trim().toUpperCase());
            if (extracted != null) fn = extracted;
          }

          extraLegs.putIfAbsent(dayIdx, () => []);
          extraLegs[dayIdx]!.add((fn: fn, dep: dep, arr: arr));
        }
      }
    }

    // Fallback: route continuity matching with flat lists
    if (extraLegs.isEmpty) {
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

      if (extraLegs.isEmpty && airportRows.length >= 4) {
        for (int tier = 1; tier * 2 + 1 < airportRows.length; tier++) {
          final depRow = airportRows[tier * 2];
          final arrRow = airportRows[tier * 2 + 1];
          final n = [depRow.length, arrRow.length].reduce((a, b) => a < b ? a : b);
          int matchIdx = 0;
          for (final fi in flightDayIndices) {
            if (matchIdx >= n) break;
            String? prevArr;
            if (tier == 1) {
              prevArr = flightRoutes[fi]?.arr;
            } else {
              final legs = extraLegs[fi];
              if (legs != null && legs.length >= tier - 1) {
                prevArr = legs[tier - 2].arr;
              }
            }
            if (prevArr != null && prevArr == depRow[matchIdx]) {
              extraLegs.putIfAbsent(fi, () => []);
              final fn = tier - 1 < extraFlightRows.length &&
                      matchIdx < extraFlightRows[tier - 1].length
                  ? extraFlightRows[tier - 1][matchIdx]
                  : 'AH ???';
              extraLegs[fi]!.add((fn: fn, dep: depRow[matchIdx], arr: arrRow[matchIdx]));
              matchIdx++;
            }
          }
        }
      }
    }

    // Step 8a: Map extra time rows to extra legs
    // Extra leg times start from timeRows[3] (since timeRows[2] = STA of first legs)
    final extraLegTimes = <int, List<({String checkIn, String checkOut})>>{};
    final extraTimeStartIdx = flightArrivalTimes.isNotEmpty ? 3 : 2;
    if (timeRows.length >= extraTimeStartIdx + 2) {
      for (int tier = 0;
          extraTimeStartIdx + tier * 2 < timeRows.length &&
              extraTimeStartIdx + tier * 2 + 1 < timeRows.length;
          tier++) {
        final extraCheckIn = timeRows[extraTimeStartIdx + tier * 2];
        final extraCheckOut = timeRows[extraTimeStartIdx + tier * 2 + 1];

        final daysWithExtraLegs = flightDayIndices
            .where((fi) => extraLegs.containsKey(fi) && extraLegs[fi]!.length > tier)
            .toList();

        final n = [extraCheckIn.length, extraCheckOut.length, daysWithExtraLegs.length]
            .reduce((a, b) => a < b ? a : b);

        for (int i = 0; i < n; i++) {
          extraLegTimes.putIfAbsent(daysWithExtraLegs[i], () => []);
          extraLegTimes[daysWithExtraLegs[i]]!.add((
            checkIn: extraCheckIn[i],
            checkOut: extraCheckOut[i],
          ));
        }
      }
    }

    // Step 8b: Build duties
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
        final arrivalStr = flightArrivalTimes[di];

        // times.checkIn = report (timeRows[0]), times.checkOut = STD (timeRows[1])
        // arrivalStr = STA (timeRows[2])
        // For flights: show STD as departure, STA as arrival
        duties.add(RosterDuty(
          date: date,
          type: DutyType.flight,
          flightNumber: fn,
          departure: route?.dep,
          arrival: route?.arr,
          checkIn: _timeFromStr(
              date.year, date.month, date.day, times?.checkOut),
          checkOut: _timeFromStr(
              date.year, date.month, date.day, arrivalStr ?? times?.checkOut),
        ));

        // Add 2nd+ legs if available, with their times
        final extras = extraLegs[di];
        if (extras != null) {
          final legTimes = extraLegTimes[di];
          for (int li = 0; li < extras.length; li++) {
            final leg = extras[li];
            final lt = legTimes != null && li < legTimes.length ? legTimes[li] : null;
            duties.add(RosterDuty(
              date: date,
              type: DutyType.flight,
              flightNumber: leg.fn,
              departure: leg.dep,
              arrival: leg.arr,
              checkIn: _timeFromStr(date.year, date.month, date.day, lt?.checkIn),
              checkOut: _timeFromStr(date.year, date.month, date.day, lt?.checkOut),
            ));
          }
        }
        continue;
      }

      // Check if token is a known airport code (outstation day)
      if (RegExp(r'^[A-Z]{3}$').hasMatch(upper) && airportNames.containsKey(upper)) {
        duties.add(RosterDuty(
          date: date,
          type: DutyType.rest,
          activityCode: upper,
          notes: 'Escale ${airportNames[upper]}',
        ));
      } else {
        duties.add(RosterDuty(
          date: date,
          type: DutyType.off,
          activityCode: upper,
          notes: upper,
        ));
      }
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
    debugSb.writeln('Flight arrival times (STA): ${flightArrivalTimes.length}');
    for (final e in flightArrivalTimes.entries) {
      final date = e.key < dayDates.length ? dayDates[e.key] : null;
      debugSb.writeln('  Day ${date?.day}: STA=${e.value}');
    }
    debugSb.writeln('Extra leg time start index: $extraTimeStartIdx');
    for (final e in flightTimes.entries) {
      final date = e.key < dayDates.length ? dayDates[e.key] : null;
      final act = dayActivities[e.key] ?? '?';
      debugSb.writeln('  Day ${date?.day} ($act): ${e.value.checkIn} → ${e.value.checkOut}');
    }
    debugSb.writeln('Extra leg times mapped: ${extraLegTimes.length}');
    for (final e in extraLegTimes.entries) {
      final date = e.key < dayDates.length ? dayDates[e.key] : null;
      for (int l = 0; l < e.value.length; l++) {
        final lt = e.value[l];
        debugSb.writeln('  Day ${date?.day} leg${l + 2}: ${lt.checkIn} → ${lt.checkOut}');
      }
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

    if (flightNums.isEmpty && airports.length == 1) {
      duties.add(RosterDuty(
        date: DateTime(year, month, day),
        type: DutyType.rest,
        activityCode: airports[0],
        notes: 'Escale ${airportNames[airports[0]] ?? airports[0]}',
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

    // Fallback: use grid parser for any still-missing days
    if (coveredDays.length < daysInMonth) {
      final gridDuties = _tryGridParse(text, year, month, daysInMonth);
      for (final gd in gridDuties) {
        if (!coveredDays.contains(gd.date.day)) {
          duties.add(gd);
          coveredDays.add(gd.date.day);
        }
      }
    }
  }

  // ── AvioDev helpers ──

  static DutyType _avioDevType(String code) {
    if (['/', 'OFF', 'DO', 'JA'].contains(code)) {
      return DutyType.off;
    }
    if (['/RH', '//', 'RH', '#'].contains(code)) {
      return DutyType.rest;
    }
    if (code == 'ESIM') return DutyType.simulator;
    if (['ING1', 'ING2', 'ING3', 'ING4', 'ING5', 'INST',
         'ENG1', 'ENG2', 'ENG3', 'ENG4', 'ENG5'].contains(code)) {
      return DutyType.training;
    }
    if (['ISIM'].contains(code)) return DutyType.simulator;
    if (['GRTS', 'ESTG', 'ESSP', 'ELRN', 'BFGS', 'BFGE', 'CONV',
         'STGE', 'EDGR', 'LVO'].contains(code)) {
      return DutyType.training;
    }
    if (['SBY', 'STBY', 'STANDBY', 'HS'].contains(code)) return DutyType.standby;
    if (['ARRT', 'DEPL', '-->'].contains(code)) return DutyType.deadhead;
    if (['CGET'].contains(code)) return DutyType.off;
    if (['ABS', 'C/O', 'REPOS', 'REST'].contains(code)) {
      return DutyType.rest;
    }
    return DutyType.off;
  }

  static String _avioDevLabel(String code) {
    return switch (code) {
      '/' => 'Sans activité programmée',
      '//' => 'Repos post-courrier',
      '#' => 'Repos pré-courrier',
      '/RH' || 'RH' => 'Repos Hebdomadaire',
      'OFF' || 'DO' || 'JA' => 'OFF',
      'CGET' => 'Congé Été',
      'ESIM' => 'Simulateur à l\'Etranger',
      'ING1' => 'Simu NG Kouba 04:30 UTC',
      'ING2' => 'Simu NG Kouba',
      'ING3' => 'Simu NG Kouba 13:00 UTC',
      'ING4' => 'Simu NG Kouba',
      'ING5' => 'Simu NG Kouba 08:45 UTC',
      'ENG1' => 'Simu NG Kouba - Élève',
      'ENG2' => 'Simu NG Kouba - Élève',
      'ENG3' => 'Simu NG Kouba - Élève',
      'ENG4' => 'Simu NG Kouba - Élève',
      'ENG5' => 'Simu NG Kouba - Élève',
      'GRTS' => 'E-learn Ground Refresh Training Summer',
      'ESTG' => 'Briefing simulateur - Élève PNT',
      'ESSP' => 'E-learn sécurité & sauvetage théorique',
      'ELRN' => 'E-learning',
      'BFGS' => 'Briefing simulateur',
      'BFGE' => 'Briefing Élève',
      'CONV' => 'Conversion',
      'ISIM' => 'Simulateur Instructeur',
      'STGE' => 'Stage',
      'EDGR' => 'E-learning DGR',
      '-->' => 'Mise en place',
      'LVO' => 'Low Visibility Operations',
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
    final match = RegExp(r'^(?:AH\s*)?(\d{3,4})[A-Z]?$').firstMatch(token);
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

    // Find the CODE EXPLANATIONS section - try multiple header patterns
    final sectionPatterns = [
      RegExp(r'CODE\s*EXPLANATION[S]?\s*\n(.*?)(?=\nTOTALS|\nOTHER\s+TRAINING|\nPage\s+\d|$)', dotAll: true, caseSensitive: false),
      RegExp(r'CODE\s*\|\s*DESCRIPTION\s*\n(.*?)(?=\nTOTALS|\nOTHER\s+TRAINING|\nPage\s+\d|$)', dotAll: true, caseSensitive: false),
      RegExp(r'CODE\s*EXPLANATION[S]?(.*?)(?:TOTALS|OTHER\s+TRAINING|Page\s+\d|$)', dotAll: true, caseSensitive: false),
      RegExp(r'CODE\s*\|\s*DESCRIPTION(.*?)(?:TOTALS|OTHER\s+TRAINING|Page\s+\d|$)', dotAll: true, caseSensitive: false),
    ];

    String? block;
    for (final pattern in sectionPatterns) {
      final section = pattern.firstMatch(text);
      if (section != null && section.group(1)!.trim().isNotEmpty) {
        block = section.group(1)!;
        break;
      }
    }

    if (block != null) {
      // Strategy 1: pipe-separated lines
      // Handles: "CGET    |Congé Eté" and "#       |Repos pre-courier"
      // Also handles wrapped descriptions across lines
      final lines = block.split('\n');
      String? lastCode;
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        // Match: CODE | description (code can be symbols like # or /RH)
        final pipeMatch = RegExp(r'^([^\s|]+(?:\s*/\s*\w+)?)\s*\|\s*(.+)$').firstMatch(trimmed);
        if (pipeMatch != null) {
          final code = pipeMatch.group(1)!.trim();
          final desc = pipeMatch.group(2)!.trim();
          if (code.toUpperCase() != 'CODE' && desc.toUpperCase() != 'DESCRIPTION') {
            codes[code] = desc;
            lastCode = code;
          }
          continue;
        }

        // Check for multiple pipe entries on one line:
        // "CGET    |Congé Eté      /RH     |Repos Hebdomadaire"
        if (trimmed.contains('|')) {
          final multiPipe = RegExp(r'(\S+)\s*\|\s*([^|]+?)(?=\s{2,}\S+\s*\||$)');
          final matches = multiPipe.allMatches(trimmed);
          for (final m in matches) {
            final code = m.group(1)!.trim();
            final desc = m.group(2)!.trim();
            if (code.toUpperCase() != 'CODE' && desc.toUpperCase() != 'DESCRIPTION' && desc.isNotEmpty) {
              codes[code] = desc;
              lastCode = code;
            }
          }
          continue;
        }

        // Continuation line (no pipe, no code-like start) - append to last code
        if (lastCode != null && codes.containsKey(lastCode)) {
          final isNewCode = RegExp(r'^[A-Z/#][A-Z0-9/#]{0,8}\s').hasMatch(trimmed);
          if (!isNewCode) {
            codes[lastCode] = '${codes[lastCode]!} $trimmed';
            continue;
          }
        }

        // Fallback: space-separated "CODE Description text"
        final spaceMatch = RegExp(r'^(//?(?:RH)?|#|[A-Z][A-Z0-9/]{0,8})\s{2,}(.+)$').firstMatch(trimmed);
        if (spaceMatch != null) {
          final code = spaceMatch.group(1)!.trim();
          final desc = spaceMatch.group(2)!.trim();
          if (code.toUpperCase() != 'CODE' && desc.length > 1) {
            codes[code] = desc;
            lastCode = code;
          }
        }
      }

      // Strategy 2: tab-separated
      if (codes.isEmpty) {
        for (final line in lines) {
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
    }

    // Also scan the entire text for pipe-separated code entries outside a section
    if (codes.isEmpty) {
      final globalPipe = RegExp(r'^([A-Z/#][A-Z0-9/#]{0,8})\s*\|\s*(.{3,})$', multiLine: true);
      final matches = globalPipe.allMatches(text);
      for (final m in matches) {
        final code = m.group(1)!.trim();
        final desc = m.group(2)!.trim();
        if (code.toUpperCase() != 'CODE' && desc.toUpperCase() != 'DESCRIPTION') {
          codes[code] = desc;
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
