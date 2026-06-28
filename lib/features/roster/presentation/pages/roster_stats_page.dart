import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/roster_parser.dart';
import '../../domain/entities/roster_duty.dart';
import '../providers/roster_provider.dart';

class RosterStatsPage extends ConsumerWidget {
  const RosterStatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roster = ref.watch(rosterProvider);

    if (roster == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: AppBar(
          title: Text('Statistiques', style: AppTextStyles.heading2.copyWith(color: Colors.white)),
          backgroundColor: AppColors.surfaceDark,
          iconTheme: const IconThemeData(color: AppColors.neonCyan),
        ),
        body: Center(
          child: Text(
            'Aucun roster chargé',
            style: AppTextStyles.body.copyWith(color: Colors.white54),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: Text('Statistiques', style: AppTextStyles.heading2.copyWith(color: Colors.white)),
        backgroundColor: AppColors.surfaceDark,
        iconTheme: const IconThemeData(color: AppColors.neonCyan),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(roster),
            const SizedBox(height: 20),
            _buildSummaryGrid(roster),
            const SizedBox(height: 24),
            _buildSectionTitle('Répartition des activités'),
            const SizedBox(height: 12),
            _buildActivityBreakdown(roster),
            const SizedBox(height: 24),
            _buildSectionTitle('Top Destinations'),
            const SizedBox(height: 12),
            _buildDestinationStats(roster),
            const SizedBox(height: 24),
            _buildSectionTitle('Aperçu mensuel'),
            const SizedBox(height: 12),
            _buildMonthlyOverview(roster),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Roster roster) {
    final startStr = _formatDate(roster.periodStart);
    final endStr = _formatDate(roster.periodEnd);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person, color: AppColors.neonCyan, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  roster.pilotName,
                  style: AppTextStyles.heading3.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  '$startStr → $endStr  •  ${roster.aircraft}  •  ${roster.base}',
                  style: AppTextStyles.caption.copyWith(color: Colors.white54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid(Roster roster) {
    final cards = [
      _StatCardData(
        label: 'Block Hours',
        value: _formatHours(roster.totalBlockHours),
        icon: Icons.flight_takeoff,
        color: AppColors.neonCyan,
      ),
      _StatCardData(
        label: 'Duty Hours',
        value: _formatHours(roster.totalDutyHours),
        icon: Icons.schedule,
        color: AppColors.neonMagenta,
      ),
      _StatCardData(
        label: 'Landings',
        value: roster.totalLandings.toString(),
        icon: Icons.flight_land,
        color: AppColors.neonGreen,
      ),
      _StatCardData(
        label: 'Flight Days',
        value: roster.flightDays.toString(),
        icon: Icons.calendar_today,
        color: AppColors.neonOrange,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: cards.map((card) => _buildStatCard(card)).toList(),
    );
  }

  Widget _buildStatCard(_StatCardData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2235),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: data.color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: data.color.withValues(alpha: 0.15),
            blurRadius: 12,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(data.icon, color: data.color, size: 20),
              const Spacer(),
            ],
          ),
          const Spacer(),
          Text(
            data.value,
            style: AppTextStyles.heading2.copyWith(color: data.color),
          ),
          const SizedBox(height: 2),
          Text(
            data.label,
            style: AppTextStyles.caption.copyWith(color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTextStyles.heading3.copyWith(color: Colors.white),
    );
  }

  Widget _buildActivityBreakdown(Roster roster) {
    final counts = <DutyType, int>{};
    for (final duty in roster.duties) {
      counts[duty.type] = (counts[duty.type] ?? 0) + 1;
    }

    if (counts.isEmpty) {
      return _buildEmptyCard('Aucune activité');
    }

    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final maxCount = sorted.first.value;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2235),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: sorted.map((entry) {
          final color = _neonForType(entry.key);
          final fraction = maxCount > 0 ? entry.value / maxCount : 0.0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.key.label,
                      style: AppTextStyles.caption.copyWith(color: color),
                    ),
                    Text(
                      '${entry.value}',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        Container(
                          height: 8,
                          width: constraints.maxWidth,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        Container(
                          height: 8,
                          width: constraints.maxWidth * fraction,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            gradient: LinearGradient(
                              colors: [
                                color,
                                color.withValues(alpha: 0.6),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.4),
                                blurRadius: 6,
                                spreadRadius: -1,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDestinationStats(Roster roster) {
    final destinationCounts = <String, int>{};

    for (final duty in roster.duties) {
      if (duty.departure != null && duty.departure!.isNotEmpty) {
        destinationCounts[duty.departure!] =
            (destinationCounts[duty.departure!] ?? 0) + 1;
      }
      if (duty.arrival != null && duty.arrival!.isNotEmpty) {
        destinationCounts[duty.arrival!] =
            (destinationCounts[duty.arrival!] ?? 0) + 1;
      }
    }

    if (destinationCounts.isEmpty) {
      return _buildEmptyCard('Aucune destination');
    }

    final sorted = destinationCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topDestinations = sorted.take(10).toList();
    final maxCount = topDestinations.first.value;

    final barColors = [
      AppColors.neonCyan,
      AppColors.neonMagenta,
      AppColors.neonGreen,
      AppColors.neonOrange,
      AppColors.neonYellow,
      AppColors.neonPurple,
      AppColors.neonBlue,
      AppColors.neonRed,
      AppColors.neonCyan,
      AppColors.neonMagenta,
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2235),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neonMagenta.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: List.generate(topDestinations.length, (index) {
          final entry = topDestinations[index];
          final color = barColors[index % barColors.length];
          final fraction = maxCount > 0 ? entry.value / maxCount : 0.0;
          final airportFullName = RosterParser.airportName(entry.key);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${entry.key} • $airportFullName',
                        style: AppTextStyles.caption.copyWith(color: Colors.white70),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${entry.value}',
                      style: AppTextStyles.caption.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        Container(
                          height: 6,
                          width: constraints.maxWidth,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        Container(
                          height: 6,
                          width: constraints.maxWidth * fraction,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: color,
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.4),
                                blurRadius: 4,
                                spreadRadius: -1,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMonthlyOverview(Roster roster) {
    final stats = roster.allStats;

    if (stats.isEmpty) {
      return _buildEmptyCard('Aucune statistique');
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2235),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neonPurple.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: stats.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    entry.key,
                    style: AppTextStyles.caption.copyWith(color: Colors.white54),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.neonPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.neonPurple.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    entry.value,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.neonPurple,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2235),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Center(
        child: Text(
          message,
          style: AppTextStyles.caption.copyWith(color: Colors.white38),
        ),
      ),
    );
  }

  Color _neonForType(DutyType type) => switch (type) {
        DutyType.flight => const Color(0xFF00E5FF),
        DutyType.standby => const Color(0xFFFF6B35),
        DutyType.rest => const Color(0xFF00FF88),
        DutyType.training => const Color(0xFFBB86FC),
        DutyType.off => const Color(0xFF00FF88),
        DutyType.simulator => const Color(0xFFBB86FC),
        DutyType.deadhead => const Color(0xFFFF6B35),
      };

  String _formatHours(double hours) {
    final h = hours.truncate();
    final m = ((hours - h) * 60).round();
    return '${h}h${m.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}

class _StatCardData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCardData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}
