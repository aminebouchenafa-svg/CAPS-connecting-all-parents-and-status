import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../../core/constants/demo_data.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/roster_parser.dart';
import '../../domain/entities/roster_duty.dart';
import '../providers/roster_provider.dart';

class RosterUploadWidget extends ConsumerStatefulWidget {
  const RosterUploadWidget({super.key});

  @override
  ConsumerState<RosterUploadWidget> createState() => _RosterUploadWidgetState();
}

class _RosterUploadWidgetState extends ConsumerState<RosterUploadWidget> {
  bool _loading = false;
  String? _error;

  String _extractTextFromPdf(Uint8List bytes) {
    final document = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(document);

    final allCells = <({double x, double y, String text})>[];

    for (int page = 0; page < document.pages.count; page++) {
      try {
        final lines = extractor.extractTextLines(
          startPageIndex: page,
          endPageIndex: page,
        );
        for (final line in lines) {
          if (line.text.trim().isEmpty) continue;
          final y = line.bounds.top + page * 10000;
          final words = line.wordCollection;
          if (words.isNotEmpty) {
            for (final word in words) {
              final text = word.text.trim();
              if (text.isEmpty) continue;
              allCells.add((x: word.bounds.left, y: y, text: text));
            }
          } else {
            allCells.add((x: line.bounds.left, y: y, text: line.text.trim()));
          }
        }
      } catch (_) {
        allCells.add((
          x: 0,
          y: page * 10000.0,
          text: extractor.extractText(
            startPageIndex: page,
            endPageIndex: page,
          ),
        ));
      }
    }

    document.dispose();
    if (allCells.isEmpty) return '';

    final rows = <int, List<({double x, String text})>>{};
    for (final cell in allCells) {
      final yKey = (cell.y / 8).round();
      rows.putIfAbsent(yKey, () => []);
      rows[yKey]!.add((x: cell.x, text: cell.text));
    }
    final sortedKeys = rows.keys.toList()..sort();

    // Find the day-number row: standalone numbers 1-31 in left-to-right order
    Map<int, double>? dayPositions;
    int bestDayCount = 0;

    for (final key in sortedKeys) {
      final rowCells = rows[key]!;
      if (rowCells.length < 10) continue;

      final candidates = <int, double>{};
      for (final cell in rowCells) {
        final trimmed = cell.text.trim();
        if (!RegExp(r'^\d{1,2}$').hasMatch(trimmed)) continue;
        final d = int.parse(trimmed);
        if (d >= 1 && d <= 31 && !candidates.containsKey(d)) {
          candidates[d] = cell.x;
        }
      }

      if (candidates.length <= bestDayCount || candidates.length < 10) continue;

      final sorted = candidates.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));
      bool ordered = true;
      for (int i = 1; i < sorted.length; i++) {
        if (sorted[i].key <= sorted[i - 1].key) {
          ordered = false;
          break;
        }
      }
      if (ordered) {
        bestDayCount = candidates.length;
        dayPositions = candidates;
      }
    }

    if (dayPositions != null && dayPositions.length >= 10) {
      final sortedDays = dayPositions.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));

      final avgGap = (sortedDays.last.value - sortedDays.first.value) /
          (sortedDays.length - 1);

      final colBounds = <({int day, double left, double right})>[];
      for (int i = 0; i < sortedDays.length; i++) {
        final x = sortedDays[i].value;
        colBounds.add((
          day: sortedDays[i].key,
          left: (i == 0)
              ? (x - avgGap / 2)
              : (sortedDays[i - 1].value + x) / 2,
          right: (i == sortedDays.length - 1)
              ? double.infinity
              : (x + sortedDays[i + 1].value) / 2,
        ));
      }

      final sb = StringBuffer();
      for (final key in sortedKeys) {
        final cells = rows[key]!..sort((a, b) => a.x.compareTo(b.x));

        final preCol = <String>[];
        final dayContent = <int, List<String>>{};

        for (final cell in cells) {
          int? assignedDay;
          for (final col in colBounds) {
            if (cell.x >= col.left && cell.x < col.right) {
              assignedDay = col.day;
              break;
            }
          }
          if (assignedDay != null) {
            dayContent.putIfAbsent(assignedDay, () => []);
            dayContent[assignedDay]!.add(cell.text);
          } else {
            preCol.add(cell.text);
          }
        }

        final parts = <String>[preCol.join(' ')];
        for (final entry in sortedDays) {
          parts.add((dayContent[entry.key] ?? []).join(' '));
        }
        sb.writeln(parts.join('\t'));
      }

      return sb.toString();
    }

    final sb = StringBuffer();
    for (final key in sortedKeys) {
      final cells = rows[key]!..sort((a, b) => a.x.compareTo(b.x));
      sb.writeln(cells.map((c) => c.text).join('\t'));
    }
    return sb.toString();
  }

  Future<void> _pickAndLoadPdf() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      final file = result.files.first;
      final Uint8List? bytes = file.bytes;

      if (bytes == null || bytes.isEmpty) {
        setState(() {
          _error = 'Impossible de lire le fichier.';
          _loading = false;
        });
        return;
      }

      final text = _extractTextFromPdf(bytes);

      if (text.trim().isEmpty) {
        setState(() {
          _error = 'Aucun texte trouvé dans le PDF.';
          _loading = false;
        });
        return;
      }

      final parser = ref.read(rosterParserProvider);
      final roster = parser.parse(text);

      ref.read(rosterProvider.notifier).update(roster);
      ref.read(rosterDebugProvider.notifier).state = parser.lastDebugInfo;
      ref.read(rosterRawTextProvider.notifier).update(text);

      if (mounted) {
        Navigator.of(context).pop();

        final flightCount = roster.duties.where((d) => d.isFlight).length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Roster de ${roster.pilotName} chargé ! '
              '$flightCount vols trouvés.',
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 3),
          ),
        );
        // Debug dialog available via rosterDebugProvider if needed
      }
    } catch (e) {
      setState(() {
        _error = 'Erreur : $e';
        _loading = false;
      });
    }
  }

  void _loadDemoRoster() {
    ref.read(rosterProvider.notifier).update(DemoData.demoRoster);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Roster démo Juin 2026 chargé !'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _showRawTextDialog(
      BuildContext ctx, String rawText, Roster roster, String? debugInfo) {
    final flightCount = roster.duties.where((d) => d.isFlight).length;
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollCtrl) => Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            controller: scrollCtrl,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.neonCyan.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                flightCount > 0
                    ? 'Debug Parser ($flightCount vols)'
                    : 'Aucun vol détecté',
                style: AppTextStyles.heading2.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Le PDF a été lu (${rawText.length} caractères). '
                'Stats: ${roster.flightDays}j vols, ${roster.offDays}j repos, '
                '${roster.totalLandings} atterrissages.\n\n'
                'Faites une capture de ce texte et envoyez-la '
                'pour corriger le parser.',
                style: AppTextStyles.caption.copyWith(color: Colors.white54),
              ),
              if (debugInfo != null) ...[
                const SizedBox(height: 12),
                Text('Parser Debug :', style: AppTextStyles.bodyBold.copyWith(color: Colors.white)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundDark,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.2)),
                  ),
                  child: SelectableText(
                    debugInfo,
                    style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: Colors.white70),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text('Texte extrait du PDF :', style: AppTextStyles.bodyBold.copyWith(color: Colors.white)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.backgroundDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.neonCyan.withValues(alpha: 0.2)),
                ),
                child: SelectableText(
                  rawText,
                  style: const TextStyle(fontSize: 9, fontFamily: 'monospace', color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasRoster = ref.read(rosterProvider) != null;

    return Container(
      color: AppColors.surfaceDark,
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.neonCyan.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Icon(Icons.upload_file, size: 48, color: AppColors.neonCyan),
          const SizedBox(height: 12),
          Text(
            hasRoster ? 'Remplacer le roster' : 'Importer mon roster',
            style: AppTextStyles.heading2.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Sélectionnez votre fichier PDF eCrew\ndepuis vos fichiers.',
            style: AppTextStyles.caption.copyWith(color: Colors.white54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (_loading)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  CircularProgressIndicator(color: AppColors.neonCyan),
                  const SizedBox(height: 12),
                  const Text('Lecture du PDF en cours...', style: TextStyle(color: Colors.white70)),
                ],
              ),
            )
          else ...[
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _pickAndLoadPdf,
                icon: const Icon(Icons.picture_as_pdf, size: 24),
                label: const Text(
                  'Charger mon roster (PDF)',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _loadDemoRoster,
              icon: Icon(Icons.auto_awesome, size: 16, color: AppColors.neonPurple),
              label: Text(
                'Charger le roster démo',
                style: AppTextStyles.caption.copyWith(color: AppColors.neonPurple),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.neonRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.neonRed.withValues(alpha: 0.3)),
              ),
              child: Text(
                _error!,
                style: AppTextStyles.caption.copyWith(color: AppColors.neonRed),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
