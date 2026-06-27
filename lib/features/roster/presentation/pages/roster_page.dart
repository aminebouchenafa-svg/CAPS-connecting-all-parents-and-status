import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/caps_card.dart';
import '../../data/roster_parser.dart';
import '../../domain/entities/roster_duty.dart';
import '../providers/roster_provider.dart';
import '../widgets/roster_upload_widget.dart';

const _dayNames = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
const _dayNamesFull = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];

class RosterPage extends ConsumerWidget {
  const RosterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roster = ref.watch(rosterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Roster'),
        actions: [
          if (roster != null) ...[
            IconButton(
              icon: const Icon(Icons.swap_horiz),
              tooltip: 'Remplacer',
              onPressed: () => _showUploadSheet(context),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Effacer',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Effacer le roster ?'),
                    content: const Text(
                      'Le roster actuel sera supprimé.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Annuler'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Effacer'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  ref.read(rosterProvider.notifier).state = null;
                }
              },
            ),
          ],
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

class _RosterContent extends ConsumerWidget {
  final Roster roster;

  const _RosterContent({required this.roster});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(dutyNotesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header compact
          CapsCard(
            backgroundColor: AppColors.primary.withValues(alpha: 0.08),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        roster.pilotName.isNotEmpty ? roster.pilotName : 'Pilote',
                        style: AppTextStyles.bodyBold,
                      ),
                      Text(
                        '${roster.aircraft} • Base ${roster.base}',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_formatDate(roster.periodStart)} — ${_formatDate(roster.periodEnd)}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Stats row
          Row(
            children: [
              _StatChip(label: 'Vols', value: '${roster.flightDays}j', color: AppColors.statusEnVol),
              const SizedBox(width: 6),
              _StatChip(label: 'Repos', value: '${roster.offDays}j', color: AppColors.statusRepos),
              const SizedBox(width: 6),
              _StatChip(label: 'Block', value: '${roster.totalBlockHours.toStringAsFixed(0)}h', color: AppColors.accent),
              const SizedBox(width: 6),
              _StatChip(label: 'Atterr.', value: '${roster.totalLandings}', color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 16),

          // Calendar grid
          _buildCalendarGrid(context, ref, notes),
          const SizedBox(height: 12),

          // Legend
          _buildLegend(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(BuildContext context, WidgetRef ref, Map<String, String> notes) {
    final start = roster.periodStart;
    final end = roster.periodEnd;
    final daysInMonth = end.day;

    // Day name headers
    final firstDayWeekday = DateTime(start.year, start.month, 1).weekday;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Programme du mois', style: AppTextStyles.heading3),
        const SizedBox(height: 8),

        // Weekday headers
        Row(
          children: List.generate(7, (i) => Expanded(
            child: Center(
              child: Text(
                _dayNames[i],
                style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          )),
        ),
        const SizedBox(height: 4),

        // Calendar grid
        ..._buildWeeks(context, ref, notes, start.year, start.month, daysInMonth, firstDayWeekday),
      ],
    );
  }

  List<Widget> _buildWeeks(BuildContext context, WidgetRef ref, Map<String, String> notes, int year, int month, int daysInMonth, int firstDayWeekday) {
    final weeks = <Widget>[];
    int day = 1;

    for (int week = 0; week < 6 && day <= daysInMonth; week++) {
      final cells = <Widget>[];

      for (int weekday = 1; weekday <= 7; weekday++) {
        if ((week == 0 && weekday < firstDayWeekday) || day > daysInMonth) {
          cells.add(const Expanded(child: SizedBox(height: 58)));
        } else {
          final currentDay = day;
          final date = DateTime(year, month, currentDay);
          final duties = roster.dutiesForDate(date);
          final noteKey = '${year}-${month}-${currentDay}';
          final hasNote = notes.containsKey(noteKey);

          cells.add(Expanded(
            child: GestureDetector(
              onTap: () => _showDayDetail(context, ref, date, duties, notes),
              child: Container(
                height: 58,
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: _dayColor(duties),
                  borderRadius: BorderRadius.circular(8),
                  border: _isToday(date)
                      ? Border.all(color: AppColors.primary, width: 2.5)
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$currentDay',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: _isToday(date) ? FontWeight.w900 : FontWeight.w600,
                        color: _dayTextColor(duties),
                      ),
                    ),
                    if (duties.isNotEmpty && duties.first.isFlight)
                      Text(
                        _shortFlightLabel(duties.first),
                        style: TextStyle(fontSize: 8, color: _dayTextColor(duties), fontWeight: FontWeight.w500),
                      ),
                    if (hasNote)
                      Icon(Icons.comment, size: 10, color: _dayTextColor(duties).withValues(alpha: 0.7)),
                  ],
                ),
              ),
            ),
          ));
          day++;
        }
      }

      weeks.add(Row(children: cells));
    }

    return weeks;
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  Color _dayColor(List<RosterDuty> duties) {
    if (duties.isEmpty) return Colors.grey[100]!;
    final type = duties.first.type;
    return switch (type) {
      DutyType.flight => AppColors.statusEnVol.withValues(alpha: 0.2),
      DutyType.standby => AppColors.statusEscale.withValues(alpha: 0.2),
      DutyType.rest || DutyType.off => AppColors.statusRepos.withValues(alpha: 0.2),
      DutyType.training || DutyType.simulator => AppColors.statusRetour.withValues(alpha: 0.2),
      DutyType.deadhead => AppColors.accent.withValues(alpha: 0.2),
    };
  }

  Color _dayTextColor(List<RosterDuty> duties) {
    if (duties.isEmpty) return Colors.grey[600]!;
    final type = duties.first.type;
    return switch (type) {
      DutyType.flight => AppColors.statusEnVol,
      DutyType.standby => AppColors.statusEscale,
      DutyType.rest || DutyType.off => AppColors.statusRepos,
      DutyType.training || DutyType.simulator => AppColors.statusRetour,
      DutyType.deadhead => AppColors.accent,
    };
  }

  String _shortFlightLabel(RosterDuty duty) {
    if (duty.arrival != null) return duty.arrival!;
    if (duty.flightNumber != null) return duty.flightNumber!.replaceAll('AH ', '');
    return '';
  }

  void _showDayDetail(BuildContext context, WidgetRef ref, DateTime date, List<RosterDuty> duties, Map<String, String> existingNotes) {
    final noteKey = '${date.year}-${date.month}-${date.day}';
    final dayName = _dayNamesFull[date.weekday - 1];
    final controller = TextEditingController(text: existingNotes[noteKey] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Text(
              '$dayName ${date.day}/${date.month}/${date.year}',
              style: AppTextStyles.heading2,
            ),
            const SizedBox(height: 12),

            // Duty info
            if (duties.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.event_busy, color: Colors.grey[400]),
                    const SizedBox(width: 8),
                    Text('Pas d\'activité programmée', style: AppTextStyles.body),
                  ],
                ),
              )
            else
              ...duties.map((duty) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _dayColor([duty]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _dayTextColor([duty]).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 4, height: 40,
                      decoration: BoxDecoration(
                        color: _dayTextColor([duty]),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            duty.type.label,
                            style: AppTextStyles.bodyBold.copyWith(
                              color: _dayTextColor([duty]),
                            ),
                          ),
                          if (duty.isFlight && duty.flightNumber != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${duty.flightNumber}  •  '
                              '${RosterParser.airportName(duty.departure ?? '')} → '
                              '${RosterParser.airportName(duty.arrival ?? '')}',
                              style: AppTextStyles.body,
                            ),
                          ],
                          if (duty.checkIn != null && duty.checkOut != null)
                            Text(
                              'Départ ${_formatTime(duty.checkIn!)} — Arrivée ${_formatTime(duty.checkOut!)}',
                              style: AppTextStyles.caption.copyWith(color: Colors.grey[600]),
                            ),
                          if (duty.notes != null && !duty.isFlight)
                            Text(duty.notes!, style: AppTextStyles.caption),
                        ],
                      ),
                    ),
                  ],
                ),
              )),

            const SizedBox(height: 16),

            // Note input
            Text('Ma note personnelle', style: AppTextStyles.bodyBold),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Ex: Emmener les enfants au sport ce soir...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  final text = controller.text.trim();
                  final currentNotes = Map<String, String>.from(
                    ref.read(dutyNotesProvider),
                  );
                  if (text.isEmpty) {
                    currentNotes.remove(noteKey);
                  } else {
                    currentNotes[noteKey] = text;
                  }
                  ref.read(dutyNotesProvider.notifier).state = currentNotes;
                  Navigator.pop(ctx);
                },
                icon: const Icon(Icons.save),
                label: const Text('Enregistrer'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        _legendItem(AppColors.statusEnVol, 'Vol'),
        _legendItem(AppColors.statusRepos, 'Repos / OFF'),
        _legendItem(AppColors.statusEscale, 'Standby'),
        _legendItem(AppColors.statusRetour, 'Formation'),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14, height: 14,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}h${dt.minute.toString().padLeft(2, '0')}';
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
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
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
