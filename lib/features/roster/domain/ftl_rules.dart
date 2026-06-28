import 'entities/roster_duty.dart';

enum FtlSeverity { info, warning, violation }

class FtlAlert {
  final FtlSeverity severity;
  final String title;
  final String detail;
  final String article;
  final DateTime? date;

  const FtlAlert({
    required this.severity,
    required this.title,
    required this.detail,
    required this.article,
    this.date,
  });
}

class FtlChecker {
  final Roster roster;
  late final String _base;

  FtlChecker(this.roster) : _base = roster.base;

  int get _utcOffset => const <String, int>{
    'ALG': 1, 'ORN': 1, 'AAE': 1, 'CZL': 1, 'TMR': 1,
    'GHA': 1, 'TLM': 1, 'BJA': 1, 'QSF': 1, 'BLJ': 1,
    'HME': 1, 'OGX': 1, 'TAM': 1, 'INZ': 1, 'DJG': 1,
  }[_base.toUpperCase()] ?? 1;

  DateTime _toLocal(DateTime utc) => utc.add(Duration(hours: _utcOffset));

  List<FtlAlert> checkAll() {
    final alerts = <FtlAlert>[];
    alerts.addAll(checkAmplitude());
    alerts.addAll(checkRestBetweenDuties());
    alerts.addAll(checkWeeklyRest());
    alerts.addAll(checkFridaySaturday());
    alerts.addAll(checkRhCount());
    alerts.addAll(checkNightFlights());
    alerts.addAll(checkMaxFlightHours());
    alerts.addAll(checkMaxServiceTime());
    return alerts;
  }

  List<FtlAlert> alertsForDate(DateTime date) {
    return checkAll().where((a) =>
        a.date != null &&
        a.date!.year == date.year &&
        a.date!.month == date.month &&
        a.date!.day == date.day).toList();
  }

  // ── Art. 22: TSV max based on start time and number of legs ──

  List<FtlAlert> checkAmplitude() {
    final alerts = <FtlAlert>[];
    final dayGroups = _flightsByDay();

    for (final entry in dayGroups.entries) {
      final date = entry.key;
      final flights = entry.value;
      if (flights.isEmpty) continue;

      final legs = flights.length;
      final serviceStart = _serviceStart(flights);
      final serviceEnd = _serviceEnd(flights);
      if (serviceStart == null || serviceEnd == null) continue;

      final tsvMinutes = serviceEnd.difference(serviceStart).inMinutes;
      final serviceStartLT = _toLocal(serviceStart);
      final maxTsv = _maxTsvMinutes(serviceStartLT.hour, legs);

      if (maxTsv == null) {
        alerts.add(FtlAlert(
          severity: FtlSeverity.violation,
          title: 'Trop d\'étapes',
          detail: '$legs étapes non autorisées pour un début de TSV à ${_fmtHour(serviceStartLT.hour)} LT',
          article: 'Art. 22',
          date: date,
        ));
      } else if (tsvMinutes > maxTsv) {
        final tsvH = tsvMinutes ~/ 60;
        final tsvM = tsvMinutes % 60;
        final maxH = maxTsv ~/ 60;
        final maxM = maxTsv % 60;
        alerts.add(FtlAlert(
          severity: FtlSeverity.violation,
          title: 'Hors amplitude',
          detail: 'TSV: ${tsvH}h${tsvM.toString().padLeft(2, '0')} '
              '(max: ${maxH}h${maxM.toString().padLeft(2, '0')} '
              'pour $legs étape${legs > 1 ? 's' : ''} à ${_fmtHour(serviceStartLT.hour)} LT)',
          article: 'Art. 22',
          date: date,
        ));
      } else {
        final remaining = maxTsv - tsvMinutes;
        if (remaining <= 30) {
          alerts.add(FtlAlert(
            severity: FtlSeverity.warning,
            title: 'Proche de l\'amplitude max',
            detail: 'Marge restante: ${remaining}min',
            article: 'Art. 22',
            date: date,
          ));
        }
      }
    }
    return alerts;
  }

  // Art. 22 table: max TSV in minutes by start hour and number of legs
  int? _maxTsvMinutes(int startHour, int legs) {
    if (legs < 1 || legs > 5) return null;

    // [1 leg, 2 legs, 3 legs, 4 legs, 5 legs] - null means not allowed
    final List<int?> row;
    if (startHour >= 6 && startHour <= 7) {
      row = [720, 705, 690, 675, null]; // 12:00, 11:45, 11:30, 11:15, exceptional
    } else if (startHour >= 8 && startHour <= 12) {
      row = [720, 720, 705, 705, null]; // 12:00, 12:00, 11:45, 11:45
    } else if (startHour >= 13 && startHour <= 15) {
      row = [705, 690, 675, 645, null]; // 11:45, 11:30, 11:15, 10:45
    } else if (startHour >= 16 && startHour <= 19) {
      row = [645, 630, 600, null, null]; // 10:45, 10:30, 10:00
    } else {
      row = [630, 600, 585, null, null]; // 10:30, 10:00, 9:45
    }

    return row[legs - 1];
  }

  // ── Art. 42-43: Minimum rest between duties ──

  List<FtlAlert> checkRestBetweenDuties() {
    final alerts = <FtlAlert>[];
    final serviceDays = _serviceDaysSorted();
    if (serviceDays.length < 2) return alerts;

    for (int i = 1; i < serviceDays.length; i++) {
      final prevDay = serviceDays[i - 1];
      final currDay = serviceDays[i];

      final prevEnd = _dayServiceEnd(prevDay.duties);
      final currStart = _dayServiceStart(currDay.duties);
      if (prevEnd == null || currStart == null) continue;

      final restMinutes = currStart.difference(prevEnd).inMinutes;
      final prevTsvMinutes = _dayTsvMinutes(prevDay.duties);

      final isAtBase = _isDepartureFromBase(currDay.duties);
      final minRestBase = isAtBase ? 12 * 60 : 10 * 60; // Art. 42
      final minRestNight = isAtBase ? 14 * 60 : 12 * 60; // Art. 43
      final restIncludesNight = _restIncludesNightPeriod(prevEnd, currStart);

      int requiredRest = minRestBase;
      if (!restIncludesNight) {
        requiredRest = minRestNight;
      }
      // Rest must also be >= previous TSV
      if (prevTsvMinutes != null && prevTsvMinutes > requiredRest) {
        requiredRest = prevTsvMinutes;
      }

      // Subtract travel time (Art. 39): 2h at base, 45min out of base
      final travelMinutes = isAtBase ? 120 : 45;
      final effectiveRest = restMinutes - travelMinutes;

      if (effectiveRest < requiredRest) {
        final restH = restMinutes ~/ 60;
        final restM = restMinutes % 60;
        final reqH = requiredRest ~/ 60;
        final reqM = requiredRest % 60;
        final location = isAtBase ? 'base' : 'escale';
        alerts.add(FtlAlert(
          severity: FtlSeverity.violation,
          title: 'Repos insuffisant ($location)',
          detail: 'Repos: ${restH}h${restM.toString().padLeft(2, '0')} '
              '(min requis: ${reqH}h${reqM.toString().padLeft(2, '0')} '
              '+ ${travelMinutes}min trajet)',
          article: 'Art. 42-43',
          date: currDay.date,
        ));
      }

      // Art. 45: Post-flight rest when TSV > 11h
      if (prevTsvMinutes != null && prevTsvMinutes > 11 * 60) {
        final prevEndHourLT = _toLocal(prevEnd).hour;
        final first2hNotNight = prevEndHourLT >= 6 && prevEndHourLT < 19;
        final required45 = first2hNotNight ? 24 * 60 : 12 * 60;
        if (restMinutes < required45) {
          alerts.add(FtlAlert(
            severity: FtlSeverity.violation,
            title: 'Repos post-courrier insuffisant',
            detail: 'TSV > 11h: repos requis ${required45 ~/ 60}h',
            article: 'Art. 45',
            date: currDay.date,
          ));
        }
      }
    }
    return alerts;
  }

  // ── Art. 47-48: Weekly rest ──

  List<FtlAlert> checkWeeklyRest() {
    final alerts = <FtlAlert>[];
    final start = roster.periodStart;
    final end = roster.periodEnd;

    // Check for 36h rest every 7 consecutive days
    for (var weekStart = start;
        weekStart.isBefore(end);
        weekStart = weekStart.add(const Duration(days: 7))) {
      final weekEnd = weekStart.add(const Duration(days: 6));
      final weekDuties = roster.duties.where((d) =>
          !d.date.isBefore(weekStart) && !d.date.isAfter(weekEnd)).toList();

      final serviceDays = weekDuties
          .where((d) => !d.isOff)
          .map((d) => d.date.day)
          .toSet()
          .length;

      if (serviceDays >= 7) {
        alerts.add(FtlAlert(
          severity: FtlSeverity.violation,
          title: '7 jours consécutifs sans repos',
          detail: 'Repos hebdomadaire de 36h requis (2 nuits locales)',
          article: 'Art. 47',
          date: weekStart,
        ));
      }
    }

    // Check for 6 consecutive days -> 48h rest required
    final daysList = <DateTime>[];
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      daysList.add(d);
    }

    int consecutiveWork = 0;
    for (final day in daysList) {
      final duties = roster.dutiesForDate(day);
      final isWork = duties.isNotEmpty && duties.any((d) => !d.isOff);
      if (isWork) {
        consecutiveWork++;
        if (consecutiveWork >= 6) {
          alerts.add(FtlAlert(
            severity: FtlSeverity.warning,
            title: '$consecutiveWork jours consécutifs d\'activité',
            detail: 'Repos de 48h avec 2 nuits locales requis avant prochaine programmation',
            article: 'Art. 48',
            date: day,
          ));
        }
      } else {
        consecutiveWork = 0;
      }
    }

    return alerts;
  }

  // ── Art. 40: Friday + Saturday free ──

  List<FtlAlert> checkFridaySaturday() {
    final alerts = <FtlAlert>[];
    final month = roster.periodStart.month;
    final year = roster.periodStart.year;

    bool hasFridayOff = false;
    bool hasSaturdayOff = false;
    bool hasFriSatCombo = false;

    for (var d = roster.periodStart;
        !d.isAfter(roster.periodEnd);
        d = d.add(const Duration(days: 1))) {
      final duties = roster.dutiesForDate(d);
      final isOff = duties.isEmpty || duties.every((du) => du.isOff);

      if (d.weekday == DateTime.friday && isOff) {
        hasFridayOff = true;
        final saturday = d.add(const Duration(days: 1));
        final satDuties = roster.dutiesForDate(saturday);
        final satOff = satDuties.isEmpty || satDuties.every((du) => du.isOff);
        if (satOff) hasFriSatCombo = true;
      }
      if (d.weekday == DateTime.saturday && isOff) hasSaturdayOff = true;
    }

    if (!hasFriSatCombo) {
      alerts.add(FtlAlert(
        severity: FtlSeverity.violation,
        title: 'Pas de Vendredi + Samedi libre',
        detail: 'Au moins un repos coïncidant avec un vendredi et un samedi requis par mois civil',
        article: 'Art. 40',
        date: DateTime(year, month, 1),
      ));
    }

    return alerts;
  }

  // ── RH count check ──

  List<FtlAlert> checkRhCount() {
    final alerts = <FtlAlert>[];
    final rhDuties = roster.duties.where((d) {
      final code = d.activityCode?.toUpperCase() ?? '';
      return ['/RH', 'RH', '//'].contains(code);
    }).toList();

    final rhCount = rhDuties.map((d) => d.date.day).toSet().length;

    // Art. 47: weekly rest required every 7 days = ~4 per month
    final daysInPeriod = roster.periodEnd.difference(roster.periodStart).inDays + 1;
    final expectedRh = (daysInPeriod / 7).floor();

    if (rhCount < expectedRh) {
      alerts.add(FtlAlert(
        severity: FtlSeverity.warning,
        title: 'RH insuffisants: $rhCount/$expectedRh',
        detail: 'Nombre de repos hebdomadaires trouvés: $rhCount (minimum attendu: $expectedRh)',
        article: 'Art. 47',
        date: roster.periodStart,
      ));
    } else {
      alerts.add(FtlAlert(
        severity: FtlSeverity.info,
        title: 'RH respectés: $rhCount/$expectedRh',
        detail: 'Nombre de repos hebdomadaires conforme',
        article: 'Art. 47',
        date: roster.periodStart,
      ));
    }

    return alerts;
  }

  // ── Art. 25-26: Night flights ──

  List<FtlAlert> checkNightFlights() {
    final alerts = <FtlAlert>[];
    final flightDays = _flightsByDay();
    final sortedDates = flightDays.keys.toList()..sort();

    int consecutiveNights = 0;
    for (final date in sortedDates) {
      final flights = flightDays[date]!;
      final isNight = flights.any((f) {
        if (f.checkIn == null) return false;
        final h = _toLocal(f.checkIn!).hour;
        return h >= 21 || h < 6;
      });

      if (isNight) {
        consecutiveNights++;
        if (consecutiveNights > 2) {
          alerts.add(FtlAlert(
            severity: FtlSeverity.violation,
            title: 'Plus de 2 vols de nuit consécutifs',
            detail: '$consecutiveNights nuits consécutives (max: 2)',
            article: 'Art. 25',
            date: date,
          ));
        }
      } else {
        consecutiveNights = 0;
      }
    }

    return alerts;
  }

  // ── Art. 24: Max flight hours ──

  List<FtlAlert> checkMaxFlightHours() {
    final alerts = <FtlAlert>[];
    final flights = roster.flights;

    double totalBlock = 0;
    for (final f in flights) {
      if (f.checkIn != null && f.checkOut != null) {
        totalBlock += f.checkOut!.difference(f.checkIn!).inMinutes / 60.0;
      }
    }

    if (totalBlock > 90) {
      alerts.add(FtlAlert(
        severity: FtlSeverity.violation,
        title: 'Heures de vol > 90h/28j',
        detail: '${totalBlock.toStringAsFixed(1)}h de vol (max: 90h sur 28 jours)',
        article: 'Art. 24',
        date: roster.periodStart,
      ));
    } else if (totalBlock > 80) {
      alerts.add(FtlAlert(
        severity: FtlSeverity.warning,
        title: 'Proche limite heures de vol',
        detail: '${totalBlock.toStringAsFixed(1)}h/90h utilisées',
        article: 'Art. 24',
        date: roster.periodStart,
      ));
    }

    return alerts;
  }

  // ── Art. 20: Max total service time ──

  List<FtlAlert> checkMaxServiceTime() {
    final alerts = <FtlAlert>[];

    // Check 7-day rolling windows for 52h max
    final start = roster.periodStart;
    final end = roster.periodEnd;

    for (var weekStart = start;
        weekStart.add(const Duration(days: 6)).isBefore(end) ||
            weekStart.add(const Duration(days: 6)).isAtSameMomentAs(end);
        weekStart = weekStart.add(const Duration(days: 1))) {
      final weekEnd = weekStart.add(const Duration(days: 6));
      double weekService = 0;

      for (var d = weekStart; !d.isAfter(weekEnd); d = d.add(const Duration(days: 1))) {
        final duties = roster.dutiesForDate(d);
        final tsv = _dayTsvMinutes(duties);
        if (tsv != null) weekService += tsv / 60.0;
      }

      if (weekService > 52) {
        alerts.add(FtlAlert(
          severity: FtlSeverity.violation,
          title: 'Service > 52h/7j',
          detail: '${weekService.toStringAsFixed(1)}h de service sur 7 jours (max: 52h)',
          article: 'Art. 20',
          date: weekStart,
        ));
        break;
      }
    }

    return alerts;
  }

  // ── Service time calculations ──

  DateTime? _serviceStart(List<RosterDuty> flights) {
    DateTime? earliest;
    for (final f in flights) {
      if (f.checkIn != null) {
        if (earliest == null || f.checkIn!.isBefore(earliest)) {
          earliest = f.checkIn!;
        }
      }
    }
    return earliest?.subtract(const Duration(hours: 1));
  }

  DateTime? _serviceEnd(List<RosterDuty> flights) {
    DateTime? latest;
    for (final f in flights) {
      if (f.checkOut != null) {
        if (latest == null || f.checkOut!.isAfter(latest)) {
          latest = f.checkOut!;
        }
      }
    }
    return latest?.add(const Duration(minutes: 30));
  }

  DateTime? _dayServiceStart(List<RosterDuty> duties) {
    final flights = duties.where((d) => d.isFlight).toList();
    if (flights.isNotEmpty) return _serviceStart(flights);
    // Non-flight duties
    DateTime? earliest;
    for (final d in duties) {
      if (d.checkIn != null) {
        if (earliest == null || d.checkIn!.isBefore(earliest)) {
          earliest = d.checkIn!;
        }
      }
    }
    return earliest;
  }

  DateTime? _dayServiceEnd(List<RosterDuty> duties) {
    final flights = duties.where((d) => d.isFlight).toList();
    if (flights.isNotEmpty) return _serviceEnd(flights);
    DateTime? latest;
    for (final d in duties) {
      if (d.checkOut != null) {
        if (latest == null || d.checkOut!.isAfter(latest)) {
          latest = d.checkOut!;
        }
      }
    }
    return latest;
  }

  int? _dayTsvMinutes(List<RosterDuty> duties) {
    final start = _dayServiceStart(duties);
    final end = _dayServiceEnd(duties);
    if (start == null || end == null) return null;
    return end.difference(start).inMinutes;
  }

  Map<DateTime, List<RosterDuty>> _flightsByDay() {
    final map = <DateTime, List<RosterDuty>>{};
    for (final d in roster.flights) {
      final key = DateTime(d.date.year, d.date.month, d.date.day);
      map.putIfAbsent(key, () => []).add(d);
    }
    return map;
  }

  bool _isDepartureFromBase(List<RosterDuty> duties) {
    for (final d in duties) {
      if (d.departure != null) {
        return d.departure!.toUpperCase() == _base.toUpperCase();
      }
    }
    return true;
  }

  bool _restIncludesNightPeriod(DateTime end, DateTime start) {
    // Check if the rest period includes time between 21h and 05h
    var t = end;
    while (t.isBefore(start)) {
      final localHour = _toLocal(t).hour;
    if (localHour >= 21 || localHour < 5) return true;
      t = t.add(const Duration(hours: 1));
    }
    return false;
  }

  List<_ServiceDay> _serviceDaysSorted() {
    final dayMap = <DateTime, List<RosterDuty>>{};
    for (final d in roster.duties) {
      if (d.isOff) continue;
      final key = DateTime(d.date.year, d.date.month, d.date.day);
      dayMap.putIfAbsent(key, () => []).add(d);
    }
    final days = dayMap.entries
        .map((e) => _ServiceDay(date: e.key, duties: e.value))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return days;
  }

  String _fmtHour(int h) => '${h.toString().padLeft(2, '0')}h00';

  // ── Summary helpers ──

  ({Duration? tsv, DateTime? serviceStartLT, DateTime? heureLimite, DateTime? serviceEndLT, int legs, Duration? maxTsv}) serviceInfoForDate(DateTime date) {
    final key = DateTime(date.year, date.month, date.day);
    final flights = _flightsByDay()[key];
    if (flights == null || flights.isEmpty) {
      return (tsv: null, serviceStartLT: null, heureLimite: null, serviceEndLT: null, legs: 0, maxTsv: null);
    }
    final start = _serviceStart(flights);
    final end = _serviceEnd(flights);
    final tsv = start != null && end != null ? end.difference(start) : null;

    DateTime? startLT;
    DateTime? endLT;
    DateTime? heureLimite;
    Duration? maxTsvDuration;

    if (start != null) {
      startLT = _toLocal(start);
      final maxMin = _maxTsvMinutes(startLT.hour, flights.length);
      if (maxMin != null) {
        maxTsvDuration = Duration(minutes: maxMin);
        heureLimite = startLT.add(Duration(minutes: maxMin));
      }
    }
    if (end != null) {
      endLT = _toLocal(end);
    }

    return (tsv: tsv, serviceStartLT: startLT, heureLimite: heureLimite, serviceEndLT: endLT, legs: flights.length, maxTsv: maxTsvDuration);
  }

  ({int required, int actual, bool compliant}) rhSummary() {
    final rhDays = roster.duties
        .where((d) {
          final code = d.activityCode?.toUpperCase() ?? '';
          return ['/RH', 'RH', '//'].contains(code);
        })
        .map((d) => d.date.day)
        .toSet()
        .length;
    final daysInPeriod = roster.periodEnd.difference(roster.periodStart).inDays + 1;
    final expected = (daysInPeriod / 7).floor();
    return (required: expected, actual: rhDays, compliant: rhDays >= expected);
  }

  ({Duration minRest, String location}) minRestForDate(DateTime date) {
    final duties = roster.dutiesForDate(date);
    final isAtBase = _isDepartureFromBase(duties);
    final location = isAtBase ? 'Base mère' : 'Escale';
    final minHours = isAtBase ? 12 : 10;
    return (minRest: Duration(hours: minHours), location: location);
  }
}

class _ServiceDay {
  final DateTime date;
  final List<RosterDuty> duties;
  const _ServiceDay({required this.date, required this.duties});
}
