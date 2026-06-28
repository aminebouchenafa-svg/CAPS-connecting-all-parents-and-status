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

const _availableColors = <String, Color>{
  'Bleu (Vol)': Color(0xFF2980B9),
  'Vert (Repos)': Color(0xFF27AE60),
  'Orange (Standby)': Color(0xFFF39C12),
  'Rouge': Color(0xFFE74C3C),
  'Violet': Color(0xFF8E44AD),
  'Rose': Color(0xFFE91E63),
  'Gris': Color(0xFF95A5A6),
  'Turquoise': Color(0xFF1ABC9C),
};

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
    final tasks = ref.watch(dutyTasksProvider);
    final customColors = ref.watch(dutyColorsProvider);
    final start = roster.periodStart;
    final end = roster.periodEnd;

    final days = <DateTime>[];
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      days.add(d);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: _buildHeader(),
        ),

        // Stats
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Row(
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
        ),

        // Totals + Codes button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _showTotalsAndCodes(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bar_chart, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text('Totaux & Codes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Horizontal scrolling blocks
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: days.map((date) {
                final duties = roster.dutiesForDate(date);
                final noteKey = '${date.year}-${date.month}-${date.day}';
                final note = notes[noteKey];
                final dayTasks = tasks[noteKey];
                final customColor = customColors[noteKey];

                return _HorizontalDayBlock(
                  date: date,
                  duties: duties,
                  note: note,
                  tasks: dayTasks,
                  customColor: customColor,
                  onTap: () => _showDayDetail(context, ref, date, duties, notes, tasks, customColors),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                roster.pilotName.isNotEmpty ? roster.pilotName : 'Pilote',
                style: AppTextStyles.bodyBold,
              ),
              Text('${roster.aircraft} • Base ${roster.base}', style: AppTextStyles.caption),
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
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
      ],
    );
  }

  void _showTotalsAndCodes(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),

              // TOTALS section
              Row(
                children: [
                  Icon(Icons.bar_chart, size: 22, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text('TOTAUX', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.primary)),
                ],
              ),
              const SizedBox(height: 12),

              if (roster.allStats.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: roster.allStats.entries.toList().asMap().entries.map((entry) {
                      final idx = entry.key;
                      final stat = entry.value;
                      final isHours = stat.value.contains(':');
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: idx.isEven ? Colors.grey.withValues(alpha: 0.04) : Colors.transparent,
                          border: idx > 0 ? Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.15))) : null,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(stat.key, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                            ),
                            Text(
                              stat.value,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: isHours ? AppColors.primary : AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                )
              else
                Text('Aucun total disponible', style: TextStyle(color: Colors.grey[400])),

              const SizedBox(height: 24),

              // CODE EXPLANATIONS section
              Row(
                children: [
                  Icon(Icons.info_outline, size: 22, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Text('CODES', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.accent)),
                ],
              ),
              const SizedBox(height: 12),

              if (roster.codeExplanations.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: roster.codeExplanations.entries.toList().asMap().entries.map((entry) {
                      final idx = entry.key;
                      final code = entry.value;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: idx.isEven ? Colors.grey.withValues(alpha: 0.04) : Colors.transparent,
                          border: idx > 0 ? Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.15))) : null,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 60,
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                code.key,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.accent),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(code.value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                )
              else
                Text('Aucun code disponible', style: TextStyle(color: Colors.grey[400])),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showDayDetail(
    BuildContext context,
    WidgetRef ref,
    DateTime date,
    List<RosterDuty> duties,
    Map<String, String> existingNotes,
    Map<String, List<Map<String, dynamic>>> existingTasks,
    Map<String, int> existingColors,
  ) {
    final noteKey = '${date.year}-${date.month}-${date.day}';
    final dayName = _dayNamesFull[date.weekday - 1];
    final noteController = TextEditingController(text: existingNotes[noteKey] ?? '');
    final taskController = TextEditingController();
    final localTasks = List<Map<String, dynamic>>.from(
      (existingTasks[noteKey] ?? <Map<String, dynamic>>[]).map((t) => Map<String, dynamic>.from(t)),
    );
    int selectedRappelColor = 0;
    int? selectedColorIndex = existingColors[noteKey];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final currentColor = selectedColorIndex != null
              ? _availableColors.values.elementAt(selectedColorIndex!)
              : _defaultDutyColor(duties);

          return Padding(
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
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Day header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: currentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: currentColor),
                        ),
                        child: Text(
                          '${date.day}',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: currentColor),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dayName, style: AppTextStyles.heading3),
                          Text('${_monthNames[date.month]} ${date.year}', style: AppTextStyles.caption),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Duty info
                  if (duties.isEmpty)
                    _infoBox(Icons.event_busy, 'Pas d\'activité programmée', Colors.grey)
                  else
                    ...duties.map((duty) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _dutyDetailCard(duty),
                    )),

                  const SizedBox(height: 16),

                  // Color picker
                  Row(
                    children: [
                      Icon(Icons.palette, size: 20, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text('Couleur du bloc', style: AppTextStyles.bodyBold),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableColors.entries.toList().asMap().entries.map((entry) {
                      final idx = entry.key;
                      final color = entry.value.value;
                      final label = entry.value.key;
                      final isSelected = selectedColorIndex == idx;

                      return GestureDetector(
                        onTap: () => setSheetState(() => selectedColorIndex = isSelected ? null : idx),
                        child: Column(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: color,
                                  width: isSelected ? 3 : 1,
                                ),
                              ),
                              child: isSelected
                                  ? Icon(Icons.check, size: 20, color: color)
                                  : null,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              label.split(' ').first,
                              style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Rappels
                  Row(
                    children: [
                      Icon(Icons.notifications_active, size: 20, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text('Rappels', style: AppTextStyles.bodyBold),
                      const Spacer(),
                      if (localTasks.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('${localTasks.length}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (localTasks.isNotEmpty)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: localTasks.length,
                        itemBuilder: (_, idx) {
                          final task = localTasks[idx];
                          final text = task['text'] as String? ?? '';
                          final colorIdx = task['color'] as int? ?? 0;
                          final rappelColors = [
                            const Color(0xFF2980B9),
                            const Color(0xFFE74C3C),
                            const Color(0xFFF39C12),
                            const Color(0xFF27AE60),
                            const Color(0xFF8E44AD),
                            const Color(0xFFE91E63),
                            const Color(0xFF1ABC9C),
                          ];
                          final c = colorIdx < rappelColors.length ? rappelColors[colorIdx] : rappelColors[0];

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Container(
                              decoration: BoxDecoration(
                                color: c.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border(left: BorderSide(color: c, width: 4)),
                              ),
                              child: ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                visualDensity: VisualDensity.compact,
                                leading: Icon(Icons.circle, size: 12, color: c),
                                title: Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                trailing: GestureDetector(
                                  onTap: () => setSheetState(() => localTasks.removeAt(idx)),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(Icons.delete_outline, size: 18, color: Colors.red[400]),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  // Suggestions rapides
                  const SizedBox(height: 6),
                  Text('Ajouter rapidement', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          ('Payer électricité', Icons.bolt, 2),
                          ('Payer loyer', Icons.home, 1),
                          ('Payer internet', Icons.wifi, 0),
                          ('Payer assurance', Icons.shield, 4),
                          ('Courses', Icons.shopping_cart, 3),
                          ('RDV médecin', Icons.local_hospital, 1),
                          ('RDV dentiste', Icons.medical_services, 1),
                          ('Appeler plombier', Icons.plumbing, 2),
                          ('Appeler électricien', Icons.electrical_services, 2),
                          ('Récupérer enfants', Icons.child_care, 5),
                          ('Sport enfants', Icons.sports_soccer, 3),
                          ('École réunion', Icons.school, 4),
                          ('Anniversaire', Icons.cake, 5),
                          ('Fin abonnement', Icons.cancel, 1),
                          ('Renouveler abo', Icons.autorenew, 0),
                          ('Contrôle technique', Icons.car_repair, 2),
                          ('Vidange voiture', Icons.local_car_wash, 2),
                          ('Pressing', Icons.dry_cleaning, 4),
                          ('Colis à récupérer', Icons.inventory, 2),
                          ('Appel important', Icons.phone, 0),
                          ('Papiers admin', Icons.description, 4),
                          ('Visa / Passeport', Icons.flight, 0),
                        ].map((item) {
                          final label = item.$1;
                          final icon = item.$2;
                          final colorIdx = item.$3;
                          final rappelColorsList = [
                            const Color(0xFF2980B9), const Color(0xFFE74C3C),
                            const Color(0xFFF39C12), const Color(0xFF27AE60),
                            const Color(0xFF8E44AD), const Color(0xFFE91E63),
                            const Color(0xFF1ABC9C),
                          ];
                          final c = rappelColorsList[colorIdx];
                          final alreadyAdded = localTasks.any((t) => t['text'] == label);
                          return GestureDetector(
                            onTap: alreadyAdded ? null : () {
                              setSheetState(() {
                                localTasks.add({'text': label, 'color': colorIdx});
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: alreadyAdded ? Colors.grey.withValues(alpha: 0.1) : c.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: alreadyAdded ? Colors.grey.withValues(alpha: 0.3) : c.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(alreadyAdded ? Icons.check : icon, size: 14, color: alreadyAdded ? Colors.grey : c),
                                  const SizedBox(width: 5),
                                  Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: alreadyAdded ? Colors.grey : c,
                                      decoration: alreadyAdded ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Custom rappel: color picker + input
                  Text('Ou ajouter un rappel personnalisé', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (int ci = 0; ci < 7; ci++)
                        GestureDetector(
                          onTap: () => setSheetState(() => selectedRappelColor = ci),
                          child: Container(
                            width: 28,
                            height: 28,
                            margin: const EdgeInsets.only(right: 5),
                            decoration: BoxDecoration(
                              color: [
                                const Color(0xFF2980B9), const Color(0xFFE74C3C),
                                const Color(0xFFF39C12), const Color(0xFF27AE60),
                                const Color(0xFF8E44AD), const Color(0xFFE91E63),
                                const Color(0xFF1ABC9C),
                              ][ci].withValues(alpha: selectedRappelColor == ci ? 1.0 : 0.3),
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                color: selectedRappelColor == ci
                                    ? [
                                        const Color(0xFF2980B9), const Color(0xFFE74C3C),
                                        const Color(0xFFF39C12), const Color(0xFF27AE60),
                                        const Color(0xFF8E44AD), const Color(0xFFE91E63),
                                        const Color(0xFF1ABC9C),
                                      ][ci]
                                    : Colors.transparent,
                                width: selectedRappelColor == ci ? 2 : 0,
                              ),
                            ),
                            child: selectedRappelColor == ci
                                ? const Icon(Icons.check, size: 14, color: Colors.white)
                                : null,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: taskController,
                          decoration: InputDecoration(
                            hintText: 'Mon rappel...',
                            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          if (taskController.text.trim().isNotEmpty) {
                            setSheetState(() {
                              localTasks.add({
                                'text': taskController.text.trim(),
                                'color': selectedRappelColor,
                              });
                              taskController.clear();
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.add, color: Colors.white, size: 24),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Note (mémo libre)
                  Row(
                    children: [
                      Icon(Icons.edit_note, size: 20, color: Colors.amber[700]),
                      const SizedBox(width: 8),
                      Text('Note', style: AppTextStyles.bodyBold),
                      const SizedBox(width: 6),
                      Text('(mémo perso)', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Ex: Sortie dîner, anniversaire...',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Save
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final cn = Map<String, String>.from(ref.read(dutyNotesProvider));
                        final noteText = noteController.text.trim();
                        if (noteText.isEmpty) { cn.remove(noteKey); } else { cn[noteKey] = noteText; }
                        ref.read(dutyNotesProvider.notifier).state = cn;

                        final ct = Map<String, List<Map<String, dynamic>>>.from(ref.read(dutyTasksProvider));
                        if (localTasks.isEmpty) { ct.remove(noteKey); } else { ct[noteKey] = localTasks; }
                        ref.read(dutyTasksProvider.notifier).state = ct;

                        final cc = Map<String, int>.from(ref.read(dutyColorsProvider));
                        if (selectedColorIndex == null) { cc.remove(noteKey); } else { cc[noteKey] = selectedColorIndex!; }
                        ref.read(dutyColorsProvider.notifier).state = cc;

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
        },
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
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                child: Text(duty.type.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
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
                Text('${RosterParser.airportName(duty.departure ?? '')} (${duty.departure})', style: AppTextStyles.body),
                if (duty.checkIn != null) ...[const Spacer(), Text(_fmtTime(duty.checkIn!), style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 13))],
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.flight_land, size: 16, color: AppColors.statusRepos),
                const SizedBox(width: 6),
                Text('${RosterParser.airportName(duty.arrival ?? '')} (${duty.arrival})', style: AppTextStyles.body),
                if (duty.checkOut != null) ...[const Spacer(), Text(_fmtTime(duty.checkOut!), style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.statusRepos, fontSize: 13))],
              ],
            ),
          ] else if (!duty.isFlight && (duty.checkIn != null || duty.checkOut != null)) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: color),
                const SizedBox(width: 6),
                if (duty.checkIn != null) Text('Début: ${_fmtTime(duty.checkIn!)}', style: TextStyle(fontWeight: FontWeight.w600, color: color, fontSize: 13)),
                if (duty.checkIn != null && duty.checkOut != null) const SizedBox(width: 16),
                if (duty.checkOut != null) Text('Fin: ${_fmtTime(duty.checkOut!)}', style: TextStyle(fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.7), fontSize: 13)),
              ],
            ),
            if (duty.notes != null) ...[
              const SizedBox(height: 4),
              Text(duty.notes!, style: AppTextStyles.body),
            ],
          ],
        ],
      ),
    );
  }

  Widget _infoBox(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [Icon(icon, color: color.withValues(alpha: 0.5)), const SizedBox(width: 8), Text(text, style: AppTextStyles.body)]),
    );
  }

  Color _defaultDutyColor(List<RosterDuty> duties) {
    if (duties.isEmpty) return Colors.grey;
    return _dutyColorSingle(duties.first.type);
  }

  Color _dutyColorSingle(DutyType type) => switch (type) {
    DutyType.flight => const Color(0xFF2980B9),
    DutyType.standby => const Color(0xFFF39C12),
    DutyType.rest || DutyType.off => const Color(0xFF27AE60),
    DutyType.training || DutyType.simulator => const Color(0xFF8E44AD),
    DutyType.deadhead => const Color(0xFFF39C12),
  };

  String _fmtTime(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}h${dt.minute.toString().padLeft(2, '0')}';
}

// --- Horizontal Day Block ---

class _HorizontalDayBlock extends StatelessWidget {
  final DateTime date;
  final List<RosterDuty> duties;
  final String? note;
  final List<Map<String, dynamic>>? tasks;
  final int? customColor;
  final VoidCallback onTap;

  const _HorizontalDayBlock({
    required this.date,
    required this.duties,
    required this.note,
    required this.tasks,
    required this.customColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _resolveColor();
    final isToday = _isToday();
    final dayName = _dayNamesFull[date.weekday - 1].substring(0, 3);
    final flights = duties.where((d) => d.isFlight).toList();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isToday ? color : color.withValues(alpha: 0.4),
            width: isToday ? 3 : 1.5,
          ),
        ),
        child: Column(
          children: [
            // Date header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Column(
                children: [
                  Text(
                    '${date.day}',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: color),
                  ),
                  Text(
                    dayName,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  children: [
                    // Type badge
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _label(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 5),

                    // Flight details for each flight
                    if (flights.isNotEmpty) ...[
                      ...flights.map((flight) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Column(
                          children: [
                            Text(
                              flight.flightNumber ?? '',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  flight.departure ?? '',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.grey[700]),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 3),
                                  child: Icon(Icons.arrow_forward, size: 12, color: color),
                                ),
                                Text(
                                  flight.arrival ?? '',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
                                ),
                              ],
                            ),
                            if (flight.checkIn != null && flight.checkOut != null)
                              Text(
                                '${_fmtTime(flight.checkIn!)} - ${_fmtTime(flight.checkOut!)}',
                                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                              ),
                          ],
                        ),
                      )),
                    ] else if (duties.isNotEmpty && duties.first.type == DutyType.standby) ...[
                      const SizedBox(height: 6),
                      Icon(Icons.access_time, size: 24, color: color),
                      const SizedBox(height: 2),
                      Text('Astreinte', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
                    ] else ...[
                      const SizedBox(height: 6),
                      Icon(
                        duties.isEmpty ? Icons.event_busy : Icons.home,
                        size: 24,
                        color: color,
                      ),
                    ],

                    // Rappels visible in block
                    if (tasks != null && tasks!.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      ...tasks!.take(2).map((task) {
                        final rappelColors = [
                          const Color(0xFF2980B9), const Color(0xFFE74C3C),
                          const Color(0xFFF39C12), const Color(0xFF27AE60),
                          const Color(0xFF8E44AD), const Color(0xFFE91E63),
                          const Color(0xFF1ABC9C),
                        ];
                        final cIdx = task['color'] as int? ?? 0;
                        final c = cIdx < rappelColors.length ? rappelColors[cIdx] : rappelColors[0];
                        final text = task['text'] as String? ?? '';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Row(
                            children: [
                              Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey[800]), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        );
                      }),
                      if (tasks!.length > 2)
                        Text('+${tasks!.length - 2} rappels', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey[500])),
                    ],

                    // Note & rappels indicator
                    if (note != null || (tasks != null && tasks!.isNotEmpty)) ...[
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (note != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.sticky_note_2, size: 12, color: Colors.amber[800]),
                                  const SizedBox(width: 3),
                                  Text('Note', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.amber[800])),
                                ],
                              ),
                            ),
                          if (note != null && tasks != null && tasks!.isNotEmpty)
                            const SizedBox(width: 4),
                          if (tasks != null && tasks!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.notifications_active, size: 12, color: Colors.blue[700]),
                                  const SizedBox(width: 3),
                                  Text('${tasks!.length}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.blue[700])),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isToday() {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  Color _resolveColor() {
    if (customColor != null) {
      return _availableColors.values.elementAt(customColor!);
    }
    if (duties.isEmpty) return Colors.grey;
    return switch (duties.first.type) {
      DutyType.flight => const Color(0xFF2980B9),
      DutyType.standby => const Color(0xFFF39C12),
      DutyType.rest || DutyType.off => const Color(0xFF27AE60),
      DutyType.training || DutyType.simulator => const Color(0xFF8E44AD),
      DutyType.deadhead => const Color(0xFFF39C12),
    };
  }

  String _label() {
    if (duties.isEmpty) return 'Libre';
    return duties.first.type.label;
  }

  String _fmtTime(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}h${dt.minute.toString().padLeft(2, '0')}';
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
