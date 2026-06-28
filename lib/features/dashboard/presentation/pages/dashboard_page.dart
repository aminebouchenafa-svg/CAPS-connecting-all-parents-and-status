import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../domain/entities/flight_status.dart';
import '../providers/flight_status_provider.dart';
import '../../../kids/presentation/pages/kids_mode_page.dart';
import '../../../roster/presentation/providers/roster_provider.dart';
import '../../../roster/domain/entities/roster_duty.dart';
import '../../../roster/data/roster_parser.dart';

const _dayNames = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

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

Color _statusColor(FlightPhase phase) => switch (phase) {
      FlightPhase.enVol => AppColors.statusEnVol,
      FlightPhase.escale => AppColors.statusEscale,
      FlightPhase.repos => AppColors.statusRepos,
      FlightPhase.retour => AppColors.statusRetour,
    };

String _formatTime(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}h${dt.minute.toString().padLeft(2, '0')}';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(rosterFlightStatusProvider);
    final roster = ref.watch(rosterProvider);
    final isDark = ref.watch(isDarkModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'C.A.P.S.',
          style: AppTextStyles.heading2.copyWith(
            color: isDark ? AppColors.neonCyan : Colors.white,
            shadows: isDark
                ? [Shadow(color: AppColors.neonCyan.withValues(alpha: 0.6), blurRadius: 6)]
                : null,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
              color: isDark ? AppColors.neonYellow : Colors.white,
            ),
            tooltip: isDark ? 'Mode Clair' : 'Mode Sombre',
            onPressed: () {
              ref.read(themeModeProvider.notifier).toggle();
            },
          ),
        ],
      ),
      body: roster != null
          ? _DashboardContent(status: status, roster: roster)
          : const _NoRosterPrompt(),
    );
  }
}

class _NoRosterPrompt extends StatelessWidget {
  const _NoRosterPrompt();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? AppColors.neonCyan.withValues(alpha: 0.15)
                  : Colors.grey.shade200,
            ),
            boxShadow: isDark
                ? [BoxShadow(color: AppColors.neonCyan.withValues(alpha: 0.1), blurRadius: 12)]
                : [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.flight_takeoff,
                size: 64,
                color: AppColors.neonCyan.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 16),
              Text(
                'Bienvenue Capitaine',
                style: AppTextStyles.heading2.copyWith(color: onSurface),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Chargez votre roster dans l\'onglet Roster '
                'pour voir automatiquement votre programme.',
                style: AppTextStyles.body.copyWith(
                  color: onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => context.goNamed('roster'),
                icon: const Icon(Icons.flight),
                label: const Text('Aller au Roster'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardContent extends ConsumerWidget {
  final FlightStatus? status;
  final Roster roster;

  const _DashboardContent({required this.status, required this.roster});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TodayCard(status: status, roster: roster),
          const SizedBox(height: 16),
          if (_findNextFlight(roster) case final nextFlight?)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _NextFlightCard(
                nextFlight: nextFlight,
              ),
            ),
          _WeekPreview(roster: roster),
          const SizedBox(height: 16),
          _QuickStats(roster: roster),
          const SizedBox(height: 16),
          const _KidModeButton(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  RosterDuty? _findNextFlight(Roster roster) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (final duty in roster.duties) {
      if (duty.isFlight && duty.date.isAfter(today)) {
        return duty;
      }
      if (duty.isFlight &&
          duty.date.year == today.year &&
          duty.date.month == today.month &&
          duty.date.day == today.day &&
          duty.checkIn != null &&
          duty.checkIn!.isAfter(now)) {
        return duty;
      }
    }
    return null;
  }
}

class _TodayCard extends StatelessWidget {
  final FlightStatus? status;
  final Roster roster;

  const _TodayCard({required this.status, required this.roster});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayDuties = roster.dutiesForDate(today);

    if (status != null) {
      return _buildStatusCard(context, status!);
    }

    if (todayDuties.isNotEmpty) {
      return _buildDutyCard(context, todayDuties.first);
    }

    return _buildEmptyCard(context);
  }

  Widget _buildStatusCard(BuildContext context, FlightStatus status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final glowColor = _statusColor(status.phase);
    final phaseDesc = switch (status.phase) {
      FlightPhase.enVol => 'En vol vers sa destination',
      FlightPhase.escale => 'En escale entre deux vols',
      FlightPhase.repos => 'A la maison',
      FlightPhase.retour => 'En route vers la maison',
    };

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: glowColor.withValues(alpha: 0.3)),
        boxShadow: isDark
            ? [BoxShadow(color: glowColor.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: -2)]
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Text(status.phase.emoji, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 8),
          Text(
            status.phase.label,
            style: AppTextStyles.heading2.copyWith(
              color: glowColor,
              shadows: isDark
                  ? [Shadow(color: glowColor.withValues(alpha: 0.6), blurRadius: 6)]
                  : null,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            phaseDesc,
            style: AppTextStyles.body.copyWith(
              color: onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          if (status.flightNumber != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: glowColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: glowColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                'Vol ${status.flightNumber}',
                style: AppTextStyles.bodyBold.copyWith(color: glowColor),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (status.currentLocation != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on, size: 18, color: glowColor),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    status.currentLocation!,
                    style: AppTextStyles.body.copyWith(color: onSurface),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (status.destination != null &&
              status.phase != FlightPhase.repos) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.flight_land, size: 18, color: AppColors.neonGreen),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    status.destination!,
                    style: AppTextStyles.bodyBold.copyWith(
                      color: AppColors.neonGreen,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (status.phase != FlightPhase.repos &&
              status.estimatedEndTime != null) ...[
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 20),
            _CountdownSection(
              targetTime: status.estimatedEndTime!,
              glowColor: glowColor,
            ),
          ],
          if (status.phase == FlightPhase.repos) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, size: 24, color: AppColors.neonGreen),
                const SizedBox(width: 8),
                Text(
                  'Disponible !',
                  style: AppTextStyles.bodyBold.copyWith(
                    color: AppColors.neonGreen,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDutyCard(BuildContext context, RosterDuty duty) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final glowColor = _neonColorForDuty(duty);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: glowColor.withValues(alpha: 0.3)),
        boxShadow: isDark
            ? [BoxShadow(color: glowColor.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: -2)]
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Text(_dutyEmoji(duty), style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 8),
          Text(
            duty.type.label,
            style: AppTextStyles.heading2.copyWith(
              color: glowColor,
              shadows: isDark
                  ? [Shadow(color: glowColor.withValues(alpha: 0.6), blurRadius: 6)]
                  : null,
            ),
          ),
          if (duty.activityCode != null) ...[
            const SizedBox(height: 4),
            Text(
              duty.activityCode!,
              style: AppTextStyles.body.copyWith(
                color: onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
          if (duty.notes != null && duty.notes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              duty.notes!,
              style: AppTextStyles.caption.copyWith(
                color: onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.neonCyan.withValues(alpha: 0.15)
              : Colors.grey.shade200,
        ),
        boxShadow: isDark
            ? [BoxShadow(color: AppColors.neonCyan.withValues(alpha: 0.1), blurRadius: 12)]
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          const Text('📋', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 8),
          Text(
            'Aucune activite aujourd\'hui',
            style: AppTextStyles.heading3.copyWith(color: onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            'Pas de duty programme pour cette journee',
            style: AppTextStyles.body.copyWith(
              color: onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
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
}

class _CountdownSection extends StatefulWidget {
  final DateTime targetTime;
  final Color glowColor;

  const _CountdownSection({
    required this.targetTime,
    required this.glowColor,
  });

  @override
  State<_CountdownSection> createState() => _CountdownSectionState();
}

class _CountdownSectionState extends State<_CountdownSection>
    with TickerProviderStateMixin {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  late AnimationController _arrivalController;
  late Animation<double> _arrivalScale;

  bool _hasArrived = false;

  @override
  void initState() {
    super.initState();

    // Pulsing glow animation
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Arrival bounce animation
    _arrivalController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _arrivalScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _arrivalController, curve: Curves.elasticOut),
    );

    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemaining();
    });
  }

  void _updateRemaining() {
    final diff = widget.targetTime.difference(DateTime.now());
    setState(() {
      if (diff.isNegative || diff == Duration.zero) {
        _remaining = Duration.zero;
        if (!_hasArrived) {
          _hasArrived = true;
          _glowController.stop();
          _arrivalController.forward();
        }
      } else {
        _remaining = diff;
        _hasArrived = false;
      }
    });
  }

  @override
  void didUpdateWidget(covariant _CountdownSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetTime != widget.targetTime) {
      _hasArrived = false;
      _arrivalController.reset();
      if (!_glowController.isAnimating) {
        _glowController.repeat(reverse: true);
      }
      _updateRemaining();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _glowController.dispose();
    _arrivalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_hasArrived) {
      return ScaleTransition(
        scale: _arrivalScale,
        child: Column(
          children: [
            Container(
              decoration: isDark
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.neonGreen.withValues(alpha: 0.5),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    )
                  : null,
              child: Icon(
                Icons.check_circle,
                size: 48,
                color: AppColors.neonGreen,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Papa est arrivé !',
              style: AppTextStyles.heading2.copyWith(
                color: AppColors.neonGreen,
                shadows: isDark
                    ? [Shadow(color: AppColors.neonGreen.withValues(alpha: 0.6), blurRadius: 8)]
                    : null,
              ),
            ),
          ],
        ),
      );
    }

    final hours = _remaining.inHours;
    final minutes = _remaining.inMinutes % 60;
    final seconds = _remaining.inSeconds % 60;

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Column(
          children: [
            Text(
              'Papa rentre dans',
              style: AppTextStyles.heading3.copyWith(
                color: isDark
                    ? widget.glowColor
                    : _darkenColor(widget.glowColor, 0.3),
                fontWeight: FontWeight.w600,
                shadows: isDark
                    ? [
                        Shadow(
                          color: widget.glowColor.withValues(
                            alpha: 0.4 * _glowAnimation.value,
                          ),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTimeBlock(
                  hours.toString().padLeft(2, '0'),
                  'heures',
                  isDark,
                ),
                _buildSeparator(isDark),
                _buildTimeBlock(
                  minutes.toString().padLeft(2, '0'),
                  'minutes',
                  isDark,
                ),
                _buildSeparator(isDark),
                _buildTimeBlock(
                  seconds.toString().padLeft(2, '0'),
                  'secondes',
                  isDark,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildTimeBlock(String value, String label, bool isDark) {
    final color = isDark ? widget.glowColor : _darkenColor(widget.glowColor, 0.3);
    final glowIntensity = _glowAnimation.value;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: widget.glowColor.withValues(alpha: isDark ? 0.1 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.glowColor.withValues(
            alpha: isDark ? 0.2 + 0.2 * glowIntensity : 0.25,
          ),
          width: 1.5,
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: widget.glowColor.withValues(alpha: 0.15 * glowIntensity),
                  blurRadius: 12 * glowIntensity,
                  spreadRadius: -2,
                ),
                BoxShadow(
                  color: widget.glowColor.withValues(alpha: 0.08 * glowIntensity),
                  blurRadius: 24 * glowIntensity,
                  spreadRadius: -4,
                ),
              ]
            : [
                BoxShadow(
                  color: widget.glowColor.withValues(alpha: 0.12),
                  blurRadius: 6,
                  spreadRadius: -1,
                ),
              ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: AppTextStyles.countdown.copyWith(
              color: color,
              shadows: isDark
                  ? [
                      Shadow(
                        color: widget.glowColor.withValues(alpha: 0.7 * glowIntensity),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: color.withValues(alpha: 0.7),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeparator(bool isDark) {
    final color = isDark ? widget.glowColor : _darkenColor(widget.glowColor, 0.3);
    final glowIntensity = _glowAnimation.value;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Opacity(
        opacity: 0.4 + 0.6 * glowIntensity,
        child: Text(
          ':',
          style: AppTextStyles.countdown.copyWith(
            color: color,
            shadows: isDark
                ? [
                    Shadow(
                      color: widget.glowColor.withValues(alpha: 0.6 * glowIntensity),
                      blurRadius: 6,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }

  /// Darken a color for light mode display
  static Color _darkenColor(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .withSaturation((hsl.saturation * 0.85).clamp(0.0, 1.0))
        .toColor();
  }
}

class _NextFlightCard extends StatelessWidget {
  final RosterDuty nextFlight;

  const _NextFlightCard({required this.nextFlight});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final now = DateTime.now();
    final flightDate = nextFlight.date;
    final daysUntil = DateTime(flightDate.year, flightDate.month, flightDate.day)
        .difference(DateTime(now.year, now.month, now.day))
        .inDays;

    final dep = nextFlight.departure ?? '';
    final arr = nextFlight.arrival ?? '';
    final depName = RosterParser.airportName(dep);
    final arrName = RosterParser.airportName(arr);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.neonCyan.withValues(alpha: 0.2)
              : Colors.grey.shade200,
        ),
        boxShadow: isDark
            ? [BoxShadow(color: AppColors.neonCyan.withValues(alpha: 0.15), blurRadius: 12, spreadRadius: -2)]
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flight_takeoff, size: 20, color: AppColors.neonCyan),
              const SizedBox(width: 8),
              Text(
                'Prochain Vol',
                style: AppTextStyles.heading3.copyWith(
                  color: AppColors.neonCyan,
                  shadows: isDark
                      ? [Shadow(color: AppColors.neonCyan.withValues(alpha: 0.6), blurRadius: 6)]
                      : null,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.neonCyan.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.neonCyan.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  daysUntil == 0
                      ? 'Aujourd\'hui'
                      : daysUntil == 1
                          ? 'Demain'
                          : 'J-$daysUntil',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.neonCyan,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (nextFlight.flightNumber != null)
            Text(
              nextFlight.flightNumber!,
              style: AppTextStyles.heading2.copyWith(color: onSurface),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dep, style: AppTextStyles.heading3.copyWith(color: onSurface)),
                    Text(depName, style: AppTextStyles.caption.copyWith(color: onSurface.withValues(alpha: 0.6))),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.arrow_forward, color: AppColors.neonCyan.withValues(alpha: 0.6), size: 20),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(arr, style: AppTextStyles.heading3.copyWith(color: onSurface)),
                    Text(arrName, style: AppTextStyles.caption.copyWith(color: onSurface.withValues(alpha: 0.6))),
                  ],
                ),
              ),
            ],
          ),
          if (nextFlight.checkIn != null || nextFlight.checkOut != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (nextFlight.checkIn != null)
                  Expanded(
                    child: Text(
                      'Depart: ${_formatTime(nextFlight.checkIn!)}',
                      style: AppTextStyles.caption.copyWith(
                        color: onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                if (nextFlight.checkOut != null)
                  Expanded(
                    child: Text(
                      'Arrivee: ${_formatTime(nextFlight.checkOut!)}',
                      style: AppTextStyles.caption.copyWith(
                        color: onSurface.withValues(alpha: 0.5),
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WeekPreview extends StatelessWidget {
  final Roster roster;

  const _WeekPreview({required this.roster});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = List.generate(7, (i) => today.add(Duration(days: i)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Semaine a venir',
            style: AppTextStyles.heading3.copyWith(color: onSurface),
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 7,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final date = days[index];
              final duties = roster.dutiesForDate(date);
              final isToday = index == 0;
              return _DayBlock(date: date, duties: duties, isToday: isToday);
            },
          ),
        ),
      ],
    );
  }
}

class _DayBlock extends StatelessWidget {
  final DateTime date;
  final List<RosterDuty> duties;
  final bool isToday;

  const _DayBlock({
    required this.date,
    required this.duties,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final dayName = _dayNames[date.weekday - 1];
    final hasDuties = duties.isNotEmpty;
    final primaryDuty = hasDuties ? duties.first : null;
    final glowColor =
        primaryDuty != null ? _neonColorForDuty(primaryDuty) : AppColors.neonCyan;

    final label = primaryDuty != null
        ? (primaryDuty.isFlight
            ? (primaryDuty.flightNumber ?? 'Vol')
            : (primaryDuty.activityCode ?? primaryDuty.type.label))
        : '-';

    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: isToday
            ? glowColor.withValues(alpha: 0.15)
            : (isDark ? AppColors.cardDark : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isToday
              ? glowColor.withValues(alpha: 0.5)
              : (isDark ? glowColor.withValues(alpha: 0.15) : Colors.grey.shade200),
        ),
        boxShadow: isToday
            ? (isDark
                ? [BoxShadow(color: glowColor.withValues(alpha: 0.2), blurRadius: 8, spreadRadius: -2)]
                : [BoxShadow(color: glowColor.withValues(alpha: 0.15), blurRadius: 6)])
            : (isDark
                ? null
                : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)]),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            dayName,
            style: AppTextStyles.caption.copyWith(
              color: onSurface.withValues(alpha: 0.6),
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${date.day}',
            style: AppTextStyles.heading3.copyWith(
              color: isToday ? glowColor : onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: glowColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              label.length > 6 ? label.substring(0, 6) : label,
              style: AppTextStyles.caption.copyWith(
                color: glowColor,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickStats extends StatelessWidget {
  final Roster roster;

  const _QuickStats({required this.roster});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Statistiques du mois',
            style: AppTextStyles.heading3.copyWith(color: onSurface),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Block',
                value: '${roster.totalBlockHours.toStringAsFixed(1)}h',
                icon: Icons.access_time,
                color: AppColors.neonCyan,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                label: 'Vols',
                value: '${roster.flightDays}',
                icon: Icons.flight,
                color: AppColors.neonMagenta,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                label: 'OFF',
                value: '${roster.offDays}',
                icon: Icons.weekend,
                color: AppColors.neonGreen,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                label: 'Ldg',
                value: '${roster.totalLandings}',
                icon: Icons.flight_land,
                color: AppColors.neonOrange,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? color.withValues(alpha: 0.2) : Colors.grey.shade200,
        ),
        boxShadow: isDark
            ? [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 8, spreadRadius: -2)]
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTextStyles.heading3.copyWith(
              color: color,
              shadows: isDark
                  ? [Shadow(color: color.withValues(alpha: 0.6), blurRadius: 6)]
                  : null,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: onSurface.withValues(alpha: 0.6),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _KidModeButton extends StatelessWidget {
  const _KidModeButton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final buttonColor = AppColors.neonMagenta;

    return Material(
      color: isDark ? AppColors.cardDark : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const KidsModePage(),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: buttonColor.withValues(alpha: isDark ? 0.3 : 0.2),
            ),
            boxShadow: isDark
                ? [
                    BoxShadow(
                      color: buttonColor.withValues(alpha: 0.15),
                      blurRadius: 12,
                      spreadRadius: -2,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.child_care,
                size: 28,
                color: buttonColor,
              ),
              const SizedBox(width: 12),
              Text(
                'Mode Enfant 👶',
                style: AppTextStyles.heading3.copyWith(
                  color: buttonColor,
                  shadows: isDark
                      ? [
                          Shadow(
                            color: buttonColor.withValues(alpha: 0.6),
                            blurRadius: 6,
                          ),
                        ]
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
