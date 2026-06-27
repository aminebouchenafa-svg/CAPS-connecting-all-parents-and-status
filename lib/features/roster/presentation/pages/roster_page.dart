import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/caps_card.dart';
import '../../data/roster_parser.dart';
import '../../domain/entities/roster_duty.dart';
import '../providers/roster_provider.dart';
import '../widgets/roster_upload_widget.dart';

const _dayNames = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

class RosterPage extends ConsumerWidget {
  const RosterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roster = ref.watch(rosterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Roster'),
        actions: [
          if (roster != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Recharger',
              onPressed: () {
                ref.read(rosterProvider.notifier).state = null;
              },
            ),
        ],
      ),
      body: roster == null
          ? const _EmptyRoster()
          : _RosterContent(roster: roster),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showUploadSheet(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.upload_file),
      ),
    );
  }

  void _showUploadSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const RosterUploadWidget(),
    );
  }
}

class _EmptyRoster extends StatelessWidget {
  const _EmptyRoster();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flight, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Aucun roster chargé',
              style: AppTextStyles.heading2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Uploadez votre planning eCrew (PDF) '
              'pour voir vos rotations ici.\n\n'
              'Appuyez sur le bouton + en bas à droite.',
              style: AppTextStyles.body.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _RosterContent extends StatelessWidget {
  final Roster roster;

  const _RosterContent({required this.roster});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          CapsCard(
            backgroundColor: AppColors.primary.withValues(alpha: 0.08),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person, size: 20, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        roster.pilotName.isNotEmpty
                            ? roster.pilotName
                            : 'Pilote',
                        style: AppTextStyles.heading2,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                if (roster.pilotId.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'ID ${roster.pilotId}',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${roster.aircraft} • Base ${roster.base}',
                    style: AppTextStyles.bodyBold.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_formatDate(roster.periodStart)} — ${_formatDate(roster.periodEnd)}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Stats
          Row(
            children: [
              _StatChip(
                label: 'Vols',
                value: '${roster.flightDays}j',
                color: AppColors.statusEnVol,
              ),
              const SizedBox(width: 8),
              _StatChip(
                label: 'Repos',
                value: '${roster.offDays}j',
                color: AppColors.statusRepos,
              ),
              const SizedBox(width: 8),
              _StatChip(
                label: 'Block',
                value: '${roster.totalBlockHours.toStringAsFixed(0)}h',
                color: AppColors.accent,
              ),
              const SizedBox(width: 8),
              _StatChip(
                label: 'Atterr.',
                value: '${roster.totalLandings}',
                color: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Duties list
          Text('Planning détaillé', style: AppTextStyles.heading3),
          const SizedBox(height: 8),
          ...roster.duties.map((duty) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _DutyCard(duty: duty),
              )),

          if (roster.duties.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Le parsing du roster est en cours d\'amélioration. '
                'Les statistiques sont correctes, le détail jour par jour arrive bientôt.',
                style: AppTextStyles.caption.copyWith(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(value, style: AppTextStyles.heading3.copyWith(color: color)),
            Text(label, style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}

class _DutyCard extends StatelessWidget {
  final RosterDuty duty;

  const _DutyCard({required this.duty});

  @override
  Widget build(BuildContext context) {
    return CapsCard(
      child: Row(
        children: [
          Container(
            width: 4,
            height: 48,
            decoration: BoxDecoration(
              color: _dutyColor(duty.type),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${_dayNames[duty.date.weekday - 1]} ${duty.date.day}/${duty.date.month}',
                      style: AppTextStyles.bodyBold,
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _dutyColor(duty.type).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        duty.type.label,
                        style: AppTextStyles.caption.copyWith(
                          color: _dutyColor(duty.type),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (duty.flightNumber != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${duty.flightNumber} : '
                    '${RosterParser.airportName(duty.departure ?? '')} → '
                    '${RosterParser.airportName(duty.arrival ?? '')}',
                    style: AppTextStyles.caption,
                  ),
                ],
                if (duty.notes != null)
                  Text(duty.notes!, style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _dutyColor(DutyType type) => switch (type) {
        DutyType.flight => AppColors.statusEnVol,
        DutyType.standby => AppColors.statusEscale,
        DutyType.rest || DutyType.off => AppColors.statusRepos,
        DutyType.training || DutyType.simulator => AppColors.statusRetour,
        DutyType.deadhead => AppColors.accent,
      };
}
