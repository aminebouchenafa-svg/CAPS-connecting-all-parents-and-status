import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/ical_export.dart';
import '../../data/roster_parser.dart';
import '../../data/roster_share.dart';
import '../../domain/entities/roster_duty.dart';
import '../providers/roster_provider.dart';
import '../widgets/roster_upload_widget.dart';
import 'roster_stats_page.dart';
import 'roster_week_page.dart';

const _dayNamesFull = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
const _monthNames = ['', 'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];

const _availableColors = <String, Color>{
  'Cyan': Color(0xFF00E5FF),
  'Vert néon': Color(0xFF00FF88),
  'Orange néon': Color(0xFFFF6B35),
  'Rouge néon': Color(0xFFFF1744),
  'Violet néon': Color(0xFFBB86FC),
  'Magenta': Color(0xFFFF00E5),
  'Jaune néon': Color(0xFFFFE500),
  'Bleu néon': Color(0xFF3D5AFE),
  'Turquoise': Color(0xFF1ABC9C),
  'Rose': Color(0xFFE91E63),
  'Corail': Color(0xFFFF7043),
  'Doré': Color(0xFFFFB300),
  'Lime': Color(0xFF76FF03),
  'Indigo': Color(0xFF536DFE),
  'Ambre': Color(0xFFFFC400),
  'Teal': Color(0xFF00BFA5),
};

class RosterPage extends ConsumerWidget {
  const RosterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roster = ref.watch(rosterProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Mon Roster',
          style: TextStyle(
            color: AppColors.neonCyan,
            shadows: [Shadow(color: AppColors.neonCyan.withValues(alpha: 0.5), blurRadius: 8)],
          ),
        ),
        backgroundColor: AppColors.backgroundDark,
        actions: [
          if (roster != null) ...[
            IconButton(
              icon: const Icon(Icons.calendar_view_week),
              tooltip: 'Vue Semaine',
              color: AppColors.neonPurple,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RosterWeekPage()),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.bar_chart),
              tooltip: 'Statistiques',
              color: AppColors.neonGreen,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RosterStatsPage()),
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: AppColors.neonCyan),
              color: AppColors.surfaceDark,
              onSelected: (value) {
                switch (value) {
                  case 'export':
                    _exportICal(context, roster);
                  case 'share':
                    _shareRoster(context, roster);
                  case 'replace':
                    _showUploadSheet(context);
                  case 'delete':
                    _confirmDelete(context, ref);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 18, color: AppColors.neonCyan),
                      const SizedBox(width: 8),
                      const Text('Export iCal'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(Icons.share, size: 18, color: AppColors.neonMagenta),
                      const SizedBox(width: 8),
                      const Text('Partager'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'replace',
                  child: Row(
                    children: [
                      Icon(Icons.swap_horiz, size: 18, color: AppColors.neonOrange),
                      const SizedBox(width: 8),
                      const Text('Remplacer'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18, color: AppColors.neonRed),
                      const SizedBox(width: 8),
                      const Text('Effacer'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      backgroundColor: AppColors.backgroundDark,
      body: roster == null
          ? const _EmptyRoster()
          : _RosterCalendar(roster: roster),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: AppColors.neonCyan.withValues(alpha: 0.4), blurRadius: 16, spreadRadius: -2),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => _showUploadSheet(context),
          backgroundColor: AppColors.cardDark,
          foregroundColor: AppColors.neonCyan,
          shape: CircleBorder(side: BorderSide(color: AppColors.neonCyan.withValues(alpha: 0.5))),
          child: const Icon(Icons.upload_file),
        ),
      ),
    );
  }

  void _showUploadSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const RosterUploadWidget(),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: Text('Effacer le roster ?', style: TextStyle(color: AppColors.neonRed)),
        content: const Text('Le roster actuel sera supprimé.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: TextStyle(color: AppColors.neonCyan)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.neonRed),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      ref.read(rosterProvider.notifier).state = null;
    }
  }

  void _exportICal(BuildContext context, Roster roster) {
    final ical = ICalExport.generateICalString(roster);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: Row(
          children: [
            Icon(Icons.calendar_today, color: AppColors.neonCyan),
            const SizedBox(width: 8),
            Text('Export iCal', style: TextStyle(color: AppColors.neonCyan)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Le fichier iCal a été généré. Copiez le contenu pour l\'importer dans votre calendrier.'),
            const SizedBox(height: 12),
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: AppColors.backgroundDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.2)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(8),
                child: SelectableText(
                  ical,
                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Fermer', style: TextStyle(color: AppColors.neonCyan)),
          ),
        ],
      ),
    );
  }

  void _shareRoster(BuildContext context, Roster roster) {
    final text = RosterShare.generateTextSummary(roster);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: Row(
          children: [
            Icon(Icons.share, color: AppColors.neonMagenta),
            const SizedBox(width: 8),
            Text('Partager', style: TextStyle(color: AppColors.neonMagenta)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Copiez le résumé pour le partager avec votre famille.'),
            const SizedBox(height: 12),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: AppColors.backgroundDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.neonMagenta.withValues(alpha: 0.2)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(8),
                child: SelectableText(text, style: const TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Fermer', style: TextStyle(color: AppColors.neonCyan)),
          ),
        ],
      ),
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
            Icon(Icons.flight, size: 64, color: AppColors.neonCyan.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'Aucun roster chargé',
              style: AppTextStyles.heading2.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Uploadez votre planning eCrew (PDF) pour voir vos rotations.',
              style: AppTextStyles.body.copyWith(color: Colors.white54),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: _buildHeader(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Row(
            children: [
              _MiniStat(label: 'Vols', value: '${roster.flightDays}j', color: AppColors.neonCyan),
              const SizedBox(width: 6),
              _MiniStat(label: 'Repos', value: '${roster.offDays}j', color: AppColors.neonGreen),
              const SizedBox(width: 6),
              _MiniStat(label: 'Block', value: '${roster.totalBlockHours.toStringAsFixed(0)}h', color: AppColors.neonOrange),
              const SizedBox(width: 6),
              _MiniStat(label: 'Atterr.', value: '${roster.totalLandings}', color: AppColors.neonPurple),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: GestureDetector(
            onTap: () => _showTotalsAndCodes(context, ref),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.neonCyan.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.3)),
                boxShadow: [BoxShadow(color: AppColors.neonCyan.withValues(alpha: 0.1), blurRadius: 8)],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bar_chart, size: 16, color: AppColors.neonCyan),
                  const SizedBox(width: 6),
                  Text(
                    'Totaux & Codes',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.neonCyan,
                      shadows: [Shadow(color: AppColors.neonCyan.withValues(alpha: 0.5), blurRadius: 4)],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
                style: AppTextStyles.bodyBold.copyWith(color: Colors.white),
              ),
              Text(
                '${roster.aircraft} • Base ${roster.base}',
                style: AppTextStyles.caption.copyWith(color: Colors.white54),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.neonCyan.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.5)),
            boxShadow: [BoxShadow(color: AppColors.neonCyan.withValues(alpha: 0.2), blurRadius: 8)],
          ),
          child: Text(
            '${_monthNames[roster.periodStart.month]} ${roster.periodStart.year}',
            style: TextStyle(
              color: AppColors.neonCyan,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              shadows: [Shadow(color: AppColors.neonCyan.withValues(alpha: 0.5), blurRadius: 4)],
            ),
          ),
        ),
      ],
    );
  }

  void _showTotalsAndCodes(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark,
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
                  decoration: BoxDecoration(
                    color: AppColors.neonCyan.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Icon(Icons.bar_chart, size: 22, color: AppColors.neonCyan),
                  const SizedBox(width: 8),
                  Text(
                    'TOTAUX',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.neonCyan,
                      shadows: [Shadow(color: AppColors.neonCyan.withValues(alpha: 0.5), blurRadius: 6)],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (roster.allStats.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.15)),
                    boxShadow: [BoxShadow(color: AppColors.neonCyan.withValues(alpha: 0.05), blurRadius: 12)],
                  ),
                  child: Column(
                    children: roster.allStats.entries.toList().asMap().entries.map((entry) {
                      final idx = entry.key;
                      final stat = entry.value;
                      final isHours = stat.value.contains(':');
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          border: idx > 0
                              ? Border(top: BorderSide(color: AppColors.neonCyan.withValues(alpha: 0.08)))
                              : null,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(stat.key, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white70)),
                            ),
                            Text(
                              stat.value,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: isHours ? AppColors.neonCyan : AppColors.neonOrange,
                                shadows: [
                                  Shadow(
                                    color: (isHours ? AppColors.neonCyan : AppColors.neonOrange).withValues(alpha: 0.5),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                )
              else
                Text('Aucun total disponible', style: TextStyle(color: Colors.white38)),

              const SizedBox(height: 24),

              Row(
                children: [
                  Icon(Icons.info_outline, size: 22, color: AppColors.neonMagenta),
                  const SizedBox(width: 8),
                  Text(
                    'CODES',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.neonMagenta,
                      shadows: [Shadow(color: AppColors.neonMagenta.withValues(alpha: 0.5), blurRadius: 6)],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (roster.codeExplanations.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.neonMagenta.withValues(alpha: 0.15)),
                    boxShadow: [BoxShadow(color: AppColors.neonMagenta.withValues(alpha: 0.05), blurRadius: 12)],
                  ),
                  child: Column(
                    children: roster.codeExplanations.entries.toList().asMap().entries.map((entry) {
                      final idx = entry.key;
                      final code = entry.value;
                      final codeColor = _colorForCode(code.key);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          border: idx > 0
                              ? Border(top: BorderSide(color: AppColors.neonMagenta.withValues(alpha: 0.08)))
                              : null,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 60,
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: codeColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: codeColor.withValues(alpha: 0.4)),
                                boxShadow: [BoxShadow(color: codeColor.withValues(alpha: 0.2), blurRadius: 4)],
                              ),
                              child: Text(
                                code.key,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: codeColor,
                                  shadows: [Shadow(color: codeColor.withValues(alpha: 0.5), blurRadius: 4)],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                code.value,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                )
              else
                Text('Aucun code disponible', style: TextStyle(color: Colors.white38)),

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

    final rappelColors = [
      AppColors.neonCyan, AppColors.neonRed, AppColors.neonOrange,
      AppColors.neonGreen, AppColors.neonPurple, AppColors.neonMagenta,
      const Color(0xFF1ABC9C),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark,
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
                      decoration: BoxDecoration(
                        color: AppColors.neonCyan.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: currentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: currentColor),
                          boxShadow: [BoxShadow(color: currentColor.withValues(alpha: 0.3), blurRadius: 8)],
                        ),
                        child: Text(
                          '${date.day}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: currentColor,
                            shadows: [Shadow(color: currentColor.withValues(alpha: 0.6), blurRadius: 6)],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dayName, style: AppTextStyles.heading3.copyWith(color: Colors.white)),
                          Text('${_monthNames[date.month]} ${date.year}', style: AppTextStyles.caption.copyWith(color: Colors.white54)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (duties.isEmpty)
                    _infoBox(Icons.event_busy, 'Pas d\'activité programmée', Colors.white38)
                  else
                    ...duties.map((duty) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _dutyDetailCard(duty),
                    )),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Icon(Icons.palette, size: 20, color: AppColors.neonCyan),
                      const SizedBox(width: 8),
                      Text('Couleur du bloc', style: AppTextStyles.bodyBold.copyWith(color: Colors.white)),
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
                                boxShadow: isSelected
                                    ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)]
                                    : [],
                              ),
                              child: isSelected
                                  ? Icon(Icons.check, size: 20, color: color)
                                  : null,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              label.split(' ').first,
                              style: TextStyle(fontSize: 9, color: Colors.white54),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),
                  Divider(color: AppColors.neonCyan.withValues(alpha: 0.15)),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Icon(Icons.notifications_active, size: 20, color: AppColors.neonOrange),
                      const SizedBox(width: 8),
                      Text('Rappels', style: AppTextStyles.bodyBold.copyWith(color: Colors.white)),
                      const Spacer(),
                      if (localTasks.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.neonOrange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.neonOrange.withValues(alpha: 0.4)),
                          ),
                          child: Text('${localTasks.length}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.neonOrange)),
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
                                title: Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
                                trailing: GestureDetector(
                                  onTap: () => setSheetState(() => localTasks.removeAt(idx)),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: AppColors.neonRed.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(Icons.delete_outline, size: 18, color: AppColors.neonRed),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 6),
                  Text('Ajouter rapidement', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white54)),
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
                          final c = colorIdx < rappelColors.length ? rappelColors[colorIdx] : rappelColors[0];
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
                                color: alreadyAdded ? Colors.white10 : c.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: alreadyAdded ? Colors.white24 : c.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(alreadyAdded ? Icons.check : icon, size: 14, color: alreadyAdded ? Colors.white38 : c),
                                  const SizedBox(width: 5),
                                  Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: alreadyAdded ? Colors.white38 : c,
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
                  Text('Ou ajouter un rappel personnalisé', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white54)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (int ci = 0; ci < rappelColors.length; ci++)
                        GestureDetector(
                          onTap: () => setSheetState(() => selectedRappelColor = ci),
                          child: Container(
                            width: 28,
                            height: 28,
                            margin: const EdgeInsets.only(right: 5),
                            decoration: BoxDecoration(
                              color: rappelColors[ci].withValues(alpha: selectedRappelColor == ci ? 1.0 : 0.3),
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(
                                color: selectedRappelColor == ci ? rappelColors[ci] : Colors.transparent,
                                width: selectedRappelColor == ci ? 2 : 0,
                              ),
                              boxShadow: selectedRappelColor == ci
                                  ? [BoxShadow(color: rappelColors[ci].withValues(alpha: 0.5), blurRadius: 6)]
                                  : [],
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
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Mon rappel...',
                            hintStyle: TextStyle(color: Colors.white30, fontSize: 14),
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
                            color: AppColors.neonCyan.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.5)),
                            boxShadow: [BoxShadow(color: AppColors.neonCyan.withValues(alpha: 0.2), blurRadius: 6)],
                          ),
                          child: Icon(Icons.add, color: AppColors.neonCyan, size: 24),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Icon(Icons.edit_note, size: 20, color: AppColors.neonYellow),
                      const SizedBox(width: 8),
                      Text('Note', style: AppTextStyles.bodyBold.copyWith(color: Colors.white)),
                      const SizedBox(width: 6),
                      Text('(mémo perso)', style: TextStyle(fontSize: 11, color: Colors.white38)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteController,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Ex: Sortie dîner, anniversaire...',
                      hintStyle: TextStyle(color: Colors.white30, fontSize: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 16),

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
    final color = _colorForDuty(duty);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: color.withValues(alpha: 0.5)),
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 4)],
                ),
                child: Text(
                  duty.isFlight ? 'Vol' : (duty.activityCode ?? duty.type.label),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    shadows: [Shadow(color: color.withValues(alpha: 0.5), blurRadius: 4)],
                  ),
                ),
              ),
              if (duty.flightNumber != null) ...[
                const SizedBox(width: 8),
                Text(duty.flightNumber!, style: AppTextStyles.bodyBold.copyWith(color: Colors.white)),
              ],
            ],
          ),
          if (duty.isFlight) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.flight_takeoff, size: 16, color: color),
                const SizedBox(width: 6),
                Text('${RosterParser.airportName(duty.departure ?? '')} (${duty.departure})', style: AppTextStyles.body.copyWith(color: Colors.white)),
                if (duty.checkIn != null) ...[
                  const Spacer(),
                  Text(
                    _fmtTime(duty.checkIn!),
                    style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 13, shadows: [Shadow(color: color.withValues(alpha: 0.5), blurRadius: 4)]),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.flight_land, size: 16, color: AppColors.neonGreen),
                const SizedBox(width: 6),
                Text('${RosterParser.airportName(duty.arrival ?? '')} (${duty.arrival})', style: AppTextStyles.body.copyWith(color: Colors.white)),
                if (duty.checkOut != null) ...[
                  const Spacer(),
                  Text(
                    _fmtTime(duty.checkOut!),
                    style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.neonGreen, fontSize: 13, shadows: [Shadow(color: AppColors.neonGreen.withValues(alpha: 0.5), blurRadius: 4)]),
                  ),
                ],
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
              Text(duty.notes!, style: AppTextStyles.body.copyWith(color: Colors.white70)),
            ],
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
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(children: [Icon(icon, color: color), const SizedBox(width: 8), Text(text, style: AppTextStyles.body.copyWith(color: Colors.white70))]),
    );
  }

  Color _defaultDutyColor(List<RosterDuty> duties) {
    if (duties.isEmpty) return Colors.grey;
    return _colorForDuty(duties.first);
  }

  static Color _colorForCode(String code) {
    final upper = code.toUpperCase();
    if (['/RH', '//', 'RH', '#'].contains(upper)) return AppColors.neonGreen;
    if (['/', 'OFF', 'DO', 'JA'].contains(upper)) return AppColors.neonRed;
    if (['CGET'].contains(upper)) return AppColors.neonYellow;
    if (['ING1', 'ING2', 'ING3', 'ING4', 'ING5', 'ENG1', 'ENG2', 'ENG3', 'ENG4', 'ENG5', 'ESIM', 'INST'].contains(upper)) return AppColors.neonPurple;
    if (['GRTS', 'ESTG', 'ESSP', 'ELRN', 'BFGS', 'BFGE', 'CONV'].contains(upper)) return AppColors.neonBlue;
    if (['HS', 'SBY', 'STBY', 'STANDBY'].contains(upper)) return AppColors.neonOrange;
    if (['ARRT', 'DEPL'].contains(upper)) return AppColors.neonOrange;
    if (['ABS', 'C/O', 'REPOS', 'REST'].contains(upper)) return AppColors.neonGreen;
    return const Color(0xFF78909C);
  }

  static Color _colorForDuty(RosterDuty duty) {
    if (duty.isFlight) return AppColors.neonCyan;
    final code = duty.activityCode?.toUpperCase() ?? '';
    if (['/RH', '//', 'RH', '#'].contains(code)) return AppColors.neonGreen;
    if (['/', 'OFF', 'DO', 'JA'].contains(code)) return AppColors.neonRed;
    if (['CGET'].contains(code)) return AppColors.neonYellow;
    if (['ING1', 'ING2', 'ING3', 'ING4', 'ING5', 'ENG1', 'ENG2', 'ENG3', 'ENG4', 'ENG5', 'ESIM', 'INST'].contains(code)) return AppColors.neonPurple;
    if (['GRTS', 'ESTG', 'ESSP', 'ELRN', 'BFGS', 'BFGE', 'CONV'].contains(code)) return AppColors.neonBlue;
    if (['HS', 'SBY', 'STBY', 'STANDBY'].contains(code)) return AppColors.neonOrange;
    if (['ARRT', 'DEPL'].contains(code)) return AppColors.neonOrange;
    if (['ABS', 'C/O', 'REPOS', 'REST'].contains(code)) return AppColors.neonGreen;
    return switch (duty.type) {
      DutyType.flight => AppColors.neonCyan,
      DutyType.standby => AppColors.neonOrange,
      DutyType.rest => AppColors.neonGreen,
      DutyType.off => AppColors.neonRed,
      DutyType.training || DutyType.simulator => AppColors.neonPurple,
      DutyType.deadhead => AppColors.neonOrange,
    };
  }

  String _fmtTime(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}h${dt.minute.toString().padLeft(2, '0')}';
}

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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 140,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isToday ? color : color.withValues(alpha: 0.3),
            width: isToday ? 2.5 : 1,
          ),
          boxShadow: isToday
              ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 16, spreadRadius: -2)]
              : [BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 8)],
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Column(
                children: [
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: color,
                      shadows: [Shadow(color: color.withValues(alpha: 0.6), blurRadius: 6)],
                    ),
                  ),
                  Text(
                    dayName,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: color.withValues(alpha: 0.4)),
                        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 4)],
                      ),
                      child: Text(
                        _label(),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          shadows: [Shadow(color: color.withValues(alpha: 0.5), blurRadius: 4)],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 5),

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
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white60),
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
                                style: TextStyle(fontSize: 10, color: Colors.white38),
                              ),
                          ],
                        ),
                      )),
                    ] else if (duties.isNotEmpty && duties.first.type == DutyType.standby) ...[
                      const SizedBox(height: 6),
                      Icon(Icons.access_time, size: 24, color: color),
                      const SizedBox(height: 2),
                      Text('Astreinte', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
                      if (duties.first.checkIn != null && duties.first.checkOut != null)
                        Text(
                          '${_fmtTime(duties.first.checkIn!)} - ${_fmtTime(duties.first.checkOut!)}',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white38),
                        ),
                    ] else ...[
                      const SizedBox(height: 6),
                      Icon(
                        duties.isEmpty ? Icons.event_busy : Icons.home,
                        size: 24,
                        color: color,
                      ),
                    ],

                    if (tasks != null && tasks!.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      ...tasks!.take(2).map((task) {
                        final rappelColors = [
                          AppColors.neonCyan, AppColors.neonRed, AppColors.neonOrange,
                          AppColors.neonGreen, AppColors.neonPurple, AppColors.neonMagenta,
                          const Color(0xFF1ABC9C),
                        ];
                        final cIdx = task['color'] as int? ?? 0;
                        final c = cIdx < rappelColors.length ? rappelColors[cIdx] : rappelColors[0];
                        final text = task['text'] as String? ?? '';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Row(
                            children: [
                              Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle, boxShadow: [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 3)])),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white70), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        );
                      }),
                      if (tasks!.length > 2)
                        Text('+${tasks!.length - 2} rappels', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white38)),
                    ],

                    if (note != null || (tasks != null && tasks!.isNotEmpty)) ...[
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (note != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.neonYellow.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.neonYellow.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.sticky_note_2, size: 12, color: AppColors.neonYellow),
                                  const SizedBox(width: 3),
                                  Text('Note', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.neonYellow)),
                                ],
                              ),
                            ),
                          if (note != null && tasks != null && tasks!.isNotEmpty)
                            const SizedBox(width: 4),
                          if (tasks != null && tasks!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.neonCyan.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.notifications_active, size: 12, color: AppColors.neonCyan),
                                  const SizedBox(width: 3),
                                  Text('${tasks!.length}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.neonCyan)),
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
    if (duties.isEmpty) return const Color(0xFF78909C);
    return _RosterCalendar._colorForDuty(duties.first);
  }

  String _label() {
    if (duties.isEmpty) return 'Libre';
    final duty = duties.first;
    if (duty.isFlight) return 'Vol';
    final code = duty.activityCode;
    if (code != null && code.isNotEmpty) return code;
    return duty.type.label;
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
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 6)],
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
                shadows: [Shadow(color: color.withValues(alpha: 0.5), blurRadius: 4)],
              ),
            ),
            Text(label, style: AppTextStyles.caption.copyWith(color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}
