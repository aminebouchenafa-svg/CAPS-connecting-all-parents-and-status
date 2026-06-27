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
    final text = extractor.extractText();
    document.dispose();
    return text;
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

      ref.read(rosterProvider.notifier).state = roster;

      if (mounted) {
        Navigator.of(context).pop();

        final flightCount = roster.duties.where((d) => d.isFlight).length;
        if (roster.duties.isEmpty) {
          _showRawTextDialog(context, text, roster);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Roster de ${roster.pilotName} chargé ! '
                '$flightCount vols trouvés.',
              ),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Erreur : $e';
        _loading = false;
      });
    }
  }

  void _loadDemoRoster() {
    ref.read(rosterProvider.notifier).state = DemoData.demoRoster;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Roster démo Juin 2026 chargé !'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _showRawTextDialog(BuildContext ctx, String rawText, Roster roster) {
    showDialog(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('Roster chargé - aucun vol détecté'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Le PDF a été lu mais le parser n\'a pas trouvé de vols. '
                  'Stats: ${roster.flightDays}j vols, ${roster.offDays}j repos.',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 12),
                Text('Texte extrait du PDF :', style: AppTextStyles.bodyBold),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    rawText.length > 2000
                        ? rawText.substring(0, 2000)
                        : rawText,
                    style: const TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasRoster = ref.read(rosterProvider) != null;

    return Padding(
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
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          Icon(
            Icons.upload_file,
            size: 48,
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),

          Text(
            hasRoster ? 'Remplacer le roster' : 'Importer mon roster',
            style: AppTextStyles.heading2,
          ),
          const SizedBox(height: 8),
          Text(
            'Sélectionnez votre fichier PDF eCrew\ndepuis vos fichiers.',
            style: AppTextStyles.caption.copyWith(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Lecture du PDF en cours...'),
                ],
              ),
            )
          else ...[
            // Big blue button
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Demo option
            TextButton.icon(
              onPressed: _loadDemoRoster,
              icon: Icon(Icons.auto_awesome, size: 16, color: Colors.grey[600]),
              label: Text(
                'Charger le roster démo',
                style: AppTextStyles.caption.copyWith(color: Colors.grey[600]),
              ),
            ),
          ],

          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Text(
                _error!,
                style: AppTextStyles.caption.copyWith(color: Colors.red[700]),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
