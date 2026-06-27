import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/roster_parser.dart';
import '../../domain/entities/roster_duty.dart';
import '../providers/roster_provider.dart';
import '../widgets/roster_upload_widget.dart';

const _dayNamesFull = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
const _monthNames = ['', 'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];

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
                    content: const Text('Le roster actuel sera supprimé.'),
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
          : _RosterCalendar(roster: roster),
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
            Text('Aucun roster chargé', style: AppTextStyles.heading2, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Uploadez votre planning eCrew (PDF) pour voir vos rotations.',
              style: AppTextStyles.body.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _RosterCalendar extends ConsumerWidget {
  final Roster roster;

  const _RosterCalendar({required this.roster});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(dutyNotesProvider);
    final start = roster.periodStart;
    final end = roster.periodEnd;

    final days = <DateTime>[];
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      days.add(d);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
      itemCount: days.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildHeader(ref);
        }
        final date = days[index - 1];
        final duties = roster.dutiesForDate(date);
        final noteKey = '${date.year}-${date.month}-${date.day}';
        final note = notes[noteKey];

        return _DayBlock(
          date: date,
          duties: duties,
          note: note,
          onTap: () => _showDayDetail(context, ref, date, duties, notes),
        );
      },
    );
  }

  Widget _buildHeader(WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_monthNames[roster.periodStart.month]} ${roster.periodStart.year}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _MiniStat(label: 'Vols', value: '${roster.flightDays}j', color: AppColors.statusEnVol),
              const SizedBox(width: 6),
              _MiniStat(label: 'Repos', value: '${roster.offDays}j', color: AppColors.statusRepos),
              const SizedBox(width: 6),
              _MiniStat(label: 'Block', value: '${roster.totalBlockHours.toStringAsFixed(0)}h', color: AppColors.accent),
              const SizedBox(width: 6),
              _MiniStat(label: 'Atterr.', value: '${roster.totalLandings}', color: AppColors.primary),
            ],
          ),
        ],
      ),
    );
  }

  void _showDayDetail(BuildContext context, WidgetRef ref, DateTime date, List<RosterDuty> duties, Map<String, String> existingNotes) {
    final noteKey = '${date.year}-${date.month}-${date.day}';
    final dayName = _dayNamesFull[date.weekday - 1];
    final noteController = TextEditingController(text: existingNotes[noteKey] ?? '');
    final taskController = TextEditingController();

    final existingTasks = List<String>.from(
      ref.read(dutyTasksProvider)[noteKey] ?? <String>[],
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
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
                const SizedBox(height: 12),

                // Day header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _dutyColor(duties).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${date.day}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: _dutyColor(duties),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(dayName, style: AppTextStyles.heading3),
                        Text(
                          '${_monthNames[date.month]} ${date.year}',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Duties
                if (duties.isEmpty)
                  _infoBox(Icons.event_busy, 'Pas d\'activité programmée', Colors.grey)
                else
                  ...duties.map((duty) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _dutyDetailCard(duty),
                  )),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),

                // Tasks
                Row(
                  children: [
                    Icon(Icons.checklist, size: 20, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text('Tâches', style: AppTextStyles.bodyBold),
                  ],
                ),
                const SizedBox(height: 8),

                ...existingTasks.asMap().entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, size: 18, color: AppColors.statusRepos),
                      const SizedBox(width: 8),
                      Expanded(child: Text(entry.value, style: AppTextStyles.body)),
                      GestureDetector(
                        onTap: () {
                          setSheetState(() => existingTasks.removeAt(entry.key));
                        },
                        child: Icon(Icons.close, size: 16, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                )),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: taskController,
                        decoration: InputDecoration(
                          hintText: 'Ajouter une tâche...',
                          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () {
                        if (taskController.text.trim().isNotEmpty) {
                          setSheetState(() {
                            existingTasks.add(taskController.text.trim());
                            taskController.clear();
                          });
                        }
                      },
                      icon: Icon(Icons.add_circle, color: AppColors.primary, size: 32),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Note
                Row(
                  children: [
                    Icon(Icons.edit_note, size: 20, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Text('Note', style: AppTextStyles.bodyBold),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: noteController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Ex: Emmener les enfants au sport...',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 16),

                // Save
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Save note
                      final currentNotes = Map<String, String>.from(ref.read(dutyNotesProvider));
                      final noteText = noteController.text.trim();
                      if (noteText.isEmpty) {
                        currentNotes.remove(noteKey);
                      } else {
                        currentNotes[noteKey] = noteText;
                      }
                      ref.read(dutyNotesProvider.notifier).state = currentNotes;

                      // Save tasks
                      final currentTasks = Map<String, List<String>>.from(ref.read(dutyTasksProvider));
                      if (existingTasks.isEmpty) {
                        currentTasks.remove(noteKey);
                      } else {
                        currentTasks[noteKey] = existingTasks;
                      }
                      ref.read(dutyTasksProvider.notifier).state = currentTasks;

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
        ),
      ),
    );
  }

  Widget _dutyDetailCard(RosterDuty duty) {
    final color = _dutyColorSingle(duty.type);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  duty.type.label,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
              if (duty.flightNumber != null) ...[
                const SizedBox(width: 8),
                Text(duty.flightNumber!, style: AppTextStyles.bodyBold),
              ],
            ],
          ),
          if (duty.isFlight) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.flight_takeoff, size: 16, color: color),
                const SizedBox(width: 6),
                Text(
                  '${RosterParser.airportName(duty.departure ?? '')} (${duty.departure})',
                  style: AppTextStyles.body,
                ),
                if (duty.checkIn != null) ...[
                  const Spacer(),
                  Text(
                    _formatTime(duty.checkIn!),
                    style: AppTextStyles.bodyBold.copyWith(color: color),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.flight_land, size: 16, color: AppColors.statusRepos),
                const SizedBox(width: 6),
                Text(
                  '${RosterParser.airportName(duty.arrival ?? '')} (${duty.arrival})',
                  style: AppTextStyles.body,
                ),
                if (duty.checkOut != null) ...[
                  const Spacer(),
                  Text(
                    _formatTime(duty.checkOut!),
                    style: AppTextStyles.bodyBold.copyWith(color: AppColors.statusRepos),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoBox(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color.withValues(alpha: 0.5)),
          const SizedBox(width: 8),
          Text(text, style: AppTextStyles.body),
        ],
      ),
    );
  }

  Color _dutyColor(List<RosterDuty> duties) {
    if (duties.isEmpty) return Colors.grey;
    return _dutyColorSingle(duties.first.type);
  }

  Color _dutyColorSingle(DutyType type) => switch (type) {
    DutyType.flight => AppColors.statusEnVol,
    DutyType.standby => AppColors.statusEscale,
    DutyType.rest || DutyType.off => AppColors.statusRepos,
    DutyType.training || DutyType.simulator => AppColors.statusRetour,
    DutyType.deadhead => AppColors.accent,
  };

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}h${dt.minute.toString().padLeft(2, '0')}';
}

// --- Day Block Widget ---

class _DayBlock extends StatelessWidget {
  final DateTime date;
  final List<RosterDuty> duties;
  final String? note;
  final VoidCallback onTap;

  const _DayBlock({
    required this.date,
    required this.duties,
    required this.note,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _blockColor();
    final isToday = _isToday();
    final dayName = _dayNamesFull[date.weekday - 1];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isToday ? color : color.withValues(alpha: 0.3),
            width: isToday ? 2.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Date column
            Container(
              width: 50,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                  Text(
                    dayName.substring(0, 3),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Info column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Duty type badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _blockLabel(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      if (_hasMultipleFlights()) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${duties.where((d) => d.isFlight).length} vols',
                            style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Flight info
                  if (_firstFlight() != null) ...[
                    const SizedBox(height: 6),
                    ...duties.where((d) => d.isFlight).map((flight) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        children: [
                          Text(
                            flight.flightNumber ?? '',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: color,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${RosterParser.airportName(flight.departure ?? '')} → ${RosterParser.airportName(flight.arrival ?? '')}',
                            style: const TextStyle(fontSize: 13),
                          ),
                          const Spacer(),
                          if (flight.checkIn != null)
                            Text(
                              _formatTime(flight.checkIn!),
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                        ],
                      ),
                    )),
                  ],

                  // Note preview
                  if (note != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.sticky_note_2, size: 12, color: AppColors.accent),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            note!,
                            style: TextStyle(fontSize: 12, color: AppColors.accent, fontStyle: FontStyle.italic),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Arrow
            Icon(Icons.chevron_right, color: color.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  bool _isToday() {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  Color _blockColor() {
    if (duties.isEmpty) return Colors.grey;
    return switch (duties.first.type) {
      DutyType.flight => AppColors.statusEnVol,
      DutyType.standby => AppColors.statusEscale,
      DutyType.rest || DutyType.off => AppColors.statusRepos,
      DutyType.training || DutyType.simulator => AppColors.statusRetour,
      DutyType.deadhead => AppColors.accent,
    };
  }

  String _blockLabel() {
    if (duties.isEmpty) return 'Libre';
    return duties.first.type.label;
  }

  RosterDuty? _firstFlight() {
    for (final d in duties) {
      if (d.isFlight) return d;
    }
    return null;
  }

  bool _hasMultipleFlights() => duties.where((d) => d.isFlight).length > 1;

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}h${dt.minute.toString().padLeft(2, '0')}';
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}
