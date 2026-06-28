import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/roster_parser.dart';
import '../../domain/entities/roster_duty.dart';
import '../providers/roster_provider.dart';

const _fullDayNames = [
  'Lundi',
  'Mardi',
  'Mercredi',
  'Jeudi',
  'Vendredi',
  'Samedi',
  'Dimanche',
];
const _monthNames = [
  'Janvier',
  'Fevrier',
  'Mars',
  'Avril',
  'Mai',
  'Juin',
  'Juillet',
  'Aout',
  'Septembre',
  'Octobre',
  'Novembre',
  'Decembre',
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

String _dutyEmoji(RosterDuty duty) => switch (duty.type) {
      DutyType.flight => '✈️',
      DutyType.standby => '📟',
      DutyType.rest => '😴',
      DutyType.training => '📚',
      DutyType.off => '🏠',
      DutyType.simulator => '🎮',
      DutyType.deadhead => '🚗',
    };

String _formatTime(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}h${dt.minute.toString().padLeft(2, '0')}';

class RosterDayPage extends ConsumerWidget {
  final DateTime date;

  const RosterDayPage({super.key, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roster = ref.watch(rosterProvider);
    final duties = roster?.dutiesForDate(date) ?? [];
    final fullDayName = _fullDayNames[date.weekday - 1];
    final monthName = _monthNames[date.month - 1];

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDark,
        elevation: 0,
        title: Text(
          'Detail du Jour',
          style: AppTextStyles.heading3.copyWith(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: AppColors.neonCyan),
      ),
      body: Column(
        children: [
          // Day navigation header
          _DayNavHeader(
            date: date,
            fullDayName: fullDayName,
            monthName: monthName,
            onPrevious: () => _navigateToDay(context, ref, -1),
            onNext: () => _navigateToDay(context, ref, 1),
          ),
          // Content
          Expanded(
            child: duties.isEmpty
                ? _buildEmpty()
                : _buildTimeline(duties),
          ),
        ],
      ),
    );
  }

  void _navigateToDay(BuildContext context, WidgetRef ref, int delta) {
    final newDate = date.add(Duration(days: delta));
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => RosterDayPage(date: newDate),
        transitionsBuilder: (_, animation, __, child) {
          final offset = delta > 0
              ? const Offset(1.0, 0.0)
              : const Offset(-1.0, 0.0);
          return SlideTransition(
            position: Tween(begin: offset, end: Offset.zero)
                .animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            )),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '📋',
            style: const TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune activite ce jour',
            style: AppTextStyles.heading3.copyWith(
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pas de duty programme',
            style: AppTextStyles.body.copyWith(
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(List<RosterDuty> duties) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: duties.length,
      itemBuilder: (context, index) {
        final duty = duties[index];
        final isLast = index == duties.length - 1;
        return _TimelineEntry(
          duty: duty,
          isLast: isLast,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Day Navigation Header
// ---------------------------------------------------------------------------

class _DayNavHeader extends StatelessWidget {
  final DateTime date;
  final String fullDayName;
  final String monthName;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _DayNavHeader({
    required this.date,
    required this.fullDayName,
    required this.monthName,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    final isToday = dateOnly == today;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        border: Border(
          bottom: BorderSide(
            color: AppColors.neonCyan.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left, color: AppColors.neonCyan),
          ),
          Expanded(
            child: Column(
              children: [
                if (isToday)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: AppColors.neonCyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.neonCyan.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'Aujourd\'hui',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.neonCyan,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                Text(
                  fullDayName,
                  style: AppTextStyles.heading2.copyWith(
                    color: isToday ? AppColors.neonCyan : Colors.white,
                    shadows: isToday
                        ? [
                            Shadow(
                              color:
                                  AppColors.neonCyan.withValues(alpha: 0.6),
                              blurRadius: 6,
                            ),
                          ]
                        : null,
                  ),
                ),
                Text(
                  '${date.day} $monthName ${date.year}',
                  style: AppTextStyles.body.copyWith(
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right, color: AppColors.neonCyan),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Timeline Entry
// ---------------------------------------------------------------------------

class _TimelineEntry extends StatelessWidget {
  final RosterDuty duty;
  final bool isLast;

  const _TimelineEntry({
    required this.duty,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final glowColor = _neonColorForDuty(duty);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line and dot
          SizedBox(
            width: 32,
            child: Column(
              children: [
                // Dot
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: glowColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: glowColor.withValues(alpha: 0.5),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                // Line
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            glowColor.withValues(alpha: 0.5),
                            glowColor.withValues(alpha: 0.1),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Card content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildCard(glowColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Color glowColor) {
    if (duty.isFlight) {
      return _buildFlightCard(glowColor);
    }
    return _buildActivityCard(glowColor);
  }

  Widget _buildFlightCard(Color glowColor) {
    final dep = duty.departure ?? '';
    final arr = duty.arrival ?? '';
    final depName = dep.isNotEmpty ? RosterParser.airportName(dep) : '';
    final arrName = arr.isNotEmpty ? RosterParser.airportName(arr) : '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: glowColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.15),
            blurRadius: 12,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Flight number badge
          Row(
            children: [
              Text(
                _dutyEmoji(duty),
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: glowColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: glowColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  duty.flightNumber ?? 'Vol',
                  style: AppTextStyles.bodyBold.copyWith(
                    color: glowColor,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Vol',
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Route: departure -> arrival
          if (dep.isNotEmpty && arr.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.backgroundDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  // Departure
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.flight_takeoff,
                              size: 16,
                              color: glowColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              dep,
                              style: AppTextStyles.heading3.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          depName,
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                        if (duty.checkIn != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _formatTime(duty.checkIn!),
                            style: AppTextStyles.bodyBold.copyWith(
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Arrow
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      children: [
                        Icon(
                          Icons.arrow_forward,
                          color: glowColor.withValues(alpha: 0.5),
                          size: 20,
                        ),
                        if (duty.checkIn != null && duty.checkOut != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _flightDuration(duty.checkIn!, duty.checkOut!),
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Arrival
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              arr,
                              style: AppTextStyles.heading3.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.flight_land,
                              size: 16,
                              color: AppColors.neonGreen,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          arrName,
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                        if (duty.checkOut != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _formatTime(duty.checkOut!),
                            style: AppTextStyles.bodyBold.copyWith(
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Notes
          if (duty.notes != null && duty.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              duty.notes!,
              style: AppTextStyles.caption.copyWith(
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActivityCard(Color glowColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: glowColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.15),
            blurRadius: 12,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _dutyEmoji(duty),
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 8),
              // Activity code badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: glowColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: glowColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  duty.activityCode ?? duty.type.label,
                  style: AppTextStyles.bodyBold.copyWith(color: glowColor),
                ),
              ),
              const Spacer(),
              Text(
                duty.type.label,
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),

          // Description / notes
          if (duty.notes != null && duty.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              duty.notes!,
              style: AppTextStyles.body.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],

          // Time range for standby
          if (duty.checkIn != null || duty.checkOut != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.backgroundDark,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  if (duty.checkIn != null)
                    Column(
                      children: [
                        Text(
                          'Debut',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                        Text(
                          _formatTime(duty.checkIn!),
                          style: AppTextStyles.bodyBold.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  if (duty.checkIn != null && duty.checkOut != null)
                    Container(
                      width: 1,
                      height: 30,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  if (duty.checkOut != null)
                    Column(
                      children: [
                        Text(
                          'Fin',
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                        Text(
                          _formatTime(duty.checkOut!),
                          style: AppTextStyles.bodyBold.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _flightDuration(DateTime start, DateTime end) {
    final duration = end.difference(start);
    final h = duration.inHours;
    final m = duration.inMinutes % 60;
    return '${h}h${m.toString().padLeft(2, '0')}';
  }
}
