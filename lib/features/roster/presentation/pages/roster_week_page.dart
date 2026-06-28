import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/roster_parser.dart';
import '../../domain/entities/roster_duty.dart';
import '../providers/roster_provider.dart';
import 'roster_day_page.dart';

const _dayNames = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
const _monthNames = [
  'Jan',
  'Fev',
  'Mar',
  'Avr',
  'Mai',
  'Jun',
  'Jul',
  'Aou',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

Color _neonColorForDuty(RosterDuty duty) {
  if (duty.isFlight) return AppColors.neonCyan;
  return switch (duty.type) {
    DutyType.standby => AppColors.neonOrange,
    DutyType.rest => AppColors.neonGreen,
    DutyType.training || DutyType.simulator => AppColors.neonPurple,
    DutyType.off => AppColors.neonGreen,
    DutyType.deadhead => AppColors.neonOrange,
    _ => AppColors.neonCyan,
  };
}

String _formatTime(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}h${dt.minute.toString().padLeft(2, '0')}';

/// Returns the Monday of the week containing [date].
DateTime _weekStart(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  return d.subtract(Duration(days: d.weekday - 1));
}

/// ISO week number for [date].
int _weekNumber(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  final jan4 = DateTime(d.year, 1, 4);
  final dayOfYear = d.difference(DateTime(d.year, 1, 1)).inDays;
  return ((dayOfYear - d.weekday + jan4.weekday + 6) ~/ 7);
}

class RosterWeekPage extends ConsumerStatefulWidget {
  const RosterWeekPage({super.key});

  @override
  ConsumerState<RosterWeekPage> createState() => _RosterWeekPageState();
}

class _RosterWeekPageState extends ConsumerState<RosterWeekPage> {
  late DateTime _currentWeekStart;
  late PageController _pageController;

  // We use a PageView with a large number of pages; center page = current week.
  static const _totalPages = 200;
  static const _centerPage = 100;

  @override
  void initState() {
    super.initState();
    _currentWeekStart = _weekStart(DateTime.now());
    _pageController = PageController(initialPage: _centerPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  DateTime _weekStartForPage(int page) {
    final offset = page - _centerPage;
    return _currentWeekStart.add(Duration(days: offset * 7));
  }

  void _goToWeek(int delta) {
    final currentPage = _pageController.page?.round() ?? _centerPage;
    _pageController.animateToPage(
      currentPage + delta,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final roster = ref.watch(rosterProvider);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(
          'Vue Semaine',
          style: AppTextStyles.heading3.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.primary),
      ),
      body: roster == null
          ? _buildNoRoster()
          : Column(
              children: [
                // Week selector
                _WeekSelector(
                  pageController: _pageController,
                  currentWeekStart: _currentWeekStart,
                  centerPage: _centerPage,
                  onPrevious: () => _goToWeek(-1),
                  onNext: () => _goToWeek(1),
                ),
                // Week content - swipeable
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _totalPages,
                    itemBuilder: (context, page) {
                      final weekStart = _weekStartForPage(page);
                      return _WeekContent(
                        weekStart: weekStart,
                        roster: roster,
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildNoRoster() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today, size: 48,
              color: AppColors.neonCyan.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            'Aucun roster charge',
            style: AppTextStyles.heading3.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Week Selector header
// ---------------------------------------------------------------------------

class _WeekSelector extends StatefulWidget {
  final PageController pageController;
  final DateTime currentWeekStart;
  final int centerPage;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _WeekSelector({
    required this.pageController,
    required this.currentWeekStart,
    required this.centerPage,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  State<_WeekSelector> createState() => _WeekSelectorState();
}

class _WeekSelectorState extends State<_WeekSelector> {
  int _currentPage = _RosterWeekPageState._centerPage;

  @override
  void initState() {
    super.initState();
    widget.pageController.addListener(_onPageChanged);
  }

  @override
  void dispose() {
    widget.pageController.removeListener(_onPageChanged);
    super.dispose();
  }

  void _onPageChanged() {
    final page = widget.pageController.page?.round() ?? widget.centerPage;
    if (page != _currentPage) {
      setState(() => _currentPage = page);
    }
  }

  @override
  Widget build(BuildContext context) {
    final offset = _currentPage - widget.centerPage;
    final weekStart =
        widget.currentWeekStart.add(Duration(days: offset * 7));
    final weekNum = _weekNumber(weekStart);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: widget.onPrevious,
            icon: Icon(Icons.chevron_left, color: Theme.of(context).colorScheme.primary),
          ),
          Column(
            children: [
              Text(
                'Sem. $weekNum',
                style: AppTextStyles.heading3.copyWith(
                  color: AppColors.neonCyan,
                  shadows: isDark
                      ? [Shadow(color: AppColors.neonCyan.withValues(alpha: 0.6), blurRadius: 6)]
                      : [],
                ),
              ),
              Text(
                '${weekStart.day} ${_monthNames[weekStart.month - 1]} - '
                '${weekStart.add(const Duration(days: 6)).day} '
                '${_monthNames[weekStart.add(const Duration(days: 6)).month - 1]}',
                style: AppTextStyles.caption.copyWith(color: onSurface.withValues(alpha: 0.6)),
              ),
            ],
          ),
          IconButton(
            onPressed: widget.onNext,
            icon: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.primary),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Week Content - list of 7 day cards
// ---------------------------------------------------------------------------

class _WeekContent extends StatelessWidget {
  final DateTime weekStart;
  final Roster roster;

  const _WeekContent({required this.weekStart, required this.roster});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 7,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final date = weekStart.add(Duration(days: index));
        final duties = roster.dutiesForDate(date);
        final isToday = date.year == today.year &&
            date.month == today.month &&
            date.day == today.day;
        return _DayCard(
          date: date,
          duties: duties,
          isToday: isToday,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => RosterDayPage(date: date)),
          ),
        );
      },
    );
  }

}

// ---------------------------------------------------------------------------
// Day Card
// ---------------------------------------------------------------------------

class _DayCard extends StatelessWidget {
  final DateTime date;
  final List<RosterDuty> duties;
  final bool isToday;
  final VoidCallback onTap;

  const _DayCard({
    required this.date,
    required this.duties,
    required this.isToday,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final dayName = _dayNames[date.weekday - 1];
    final hasDuties = duties.isNotEmpty;
    final primaryDuty = hasDuties ? duties.first : null;
    final glowColor = primaryDuty != null
        ? _neonColorForDuty(primaryDuty)
        : AppColors.neonCyan.withValues(alpha: 0.3);
    final cardBg = isDark ? AppColors.cardDark : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isToday ? glowColor.withValues(alpha: 0.08) : cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isToday ? glowColor.withValues(alpha: 0.4) : glowColor.withValues(alpha: 0.15),
          ),
          boxShadow: isToday
              ? [BoxShadow(color: glowColor.withValues(alpha: 0.2), blurRadius: 12, spreadRadius: -2)]
              : isDark
                  ? [BoxShadow(color: glowColor.withValues(alpha: 0.08), blurRadius: 8, spreadRadius: -2)]
                  : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              child: Column(
                children: [
                  Text(
                    dayName,
                    style: AppTextStyles.caption.copyWith(
                      color: isToday ? glowColor : onSurface.withValues(alpha: 0.5),
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                  Text(
                    '${date.day}',
                    style: AppTextStyles.heading2.copyWith(
                      color: isToday ? glowColor : onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 2, height: 48,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: glowColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            Expanded(
              child: hasDuties
                  ? _buildDutyContent(context, duties, glowColor)
                  : Text('Aucune activite', style: AppTextStyles.body.copyWith(color: onSurface.withValues(alpha: 0.3))),
            ),
            Icon(Icons.chevron_right, color: onSurface.withValues(alpha: 0.3), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDutyContent(BuildContext context, List<RosterDuty> duties, Color glowColor) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final duty in duties) ...[
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _neonColorForDuty(duty).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _neonColorForDuty(duty).withValues(alpha: 0.3)),
                ),
                child: Text(
                  duty.isFlight ? (duty.flightNumber ?? 'Vol') : (duty.activityCode ?? duty.type.label),
                  style: AppTextStyles.caption.copyWith(
                    color: _neonColorForDuty(duty),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              if (duty.isFlight && duty.departure != null && duty.arrival != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${RosterParser.airportName(duty.departure!)} → ${RosterParser.airportName(duty.arrival!)}',
                    style: AppTextStyles.caption.copyWith(color: onSurface.withValues(alpha: 0.7)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              if (duty.checkIn != null) ...[
                const SizedBox(width: 8),
                Text(
                  _formatTime(duty.checkIn!),
                  style: AppTextStyles.caption.copyWith(color: onSurface.withValues(alpha: 0.5), fontSize: 11),
                ),
              ],
            ],
          ),
          if (duty != duties.last) const SizedBox(height: 6),
        ],
      ],
    );
  }
}

