import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/demo_data.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/roster_parser.dart';
import '../providers/roster_provider.dart';

class RosterUploadWidget extends ConsumerStatefulWidget {
  const RosterUploadWidget({super.key});

  @override
  ConsumerState<RosterUploadWidget> createState() => _RosterUploadWidgetState();
}

class _RosterUploadWidgetState extends ConsumerState<RosterUploadWidget> {
  bool _loading = false;
  String? _error;

  void _loadDemoRoster() {
    ref.read(rosterProvider.notifier).state = DemoData.demoRoster;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Roster de ${DemoData.demoRoster.pilotName} chargé !',
        ),
        backgroundColor: AppColors.success,
      ),
    );
  }

  bool _isPdfBinary(Uint8List bytes) {
    if (bytes.length >= 4) {
      // PDF files start with %PDF
      return bytes[0] == 0x25 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x44 &&
          bytes[3] == 0x46;
    }
    return false;
  }

  Future<void> _pickAndParseFile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'csv'],
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

      if (_isPdfBinary(bytes)) {
        setState(() {
          _error =
              'Les fichiers PDF ne peuvent pas être lus directement '
              'dans le navigateur.\n\n'
              'Utilisez plutôt le bouton "Coller le texte" :\n'
              '1. Ouvrez le PDF dans un lecteur\n'
              '2. Sélectionnez tout (Ctrl+A)\n'
              '3. Copiez (Ctrl+C)\n'
              '4. Collez ici';
          _loading = false;
        });
        return;
      }

      final text = utf8.decode(bytes, allowMalformed: true);

      if (text.trim().isEmpty) {
        setState(() {
          _error = 'Le fichier semble vide.';
          _loading = false;
        });
        return;
      }

      final parser = ref.read(rosterParserProvider);
      final roster = parser.parse(text);

      ref.read(rosterProvider.notifier).state = roster;

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Roster de ${roster.pilotName} chargé !'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Erreur lors du parsing : $e';
        _loading = false;
      });
    }
  }

  Future<void> _pasteRosterText() async {
    final controller = TextEditingController();

    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Coller le texte du roster'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: TextField(
            controller: controller,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            decoration: const InputDecoration(
              hintText:
                  'Ouvrez votre roster eCrew en PDF,\n'
                  'sélectionnez tout le texte (Ctrl+A),\n'
                  'copiez (Ctrl+C), puis collez ici...',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Importer'),
          ),
        ],
      ),
    );

    if (text == null || text.trim().isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final parser = ref.read(rosterParserProvider);
      final roster = parser.parse(text);

      ref.read(rosterProvider.notifier).state = roster;

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Roster de ${roster.pilotName} chargé !'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Erreur lors du parsing : $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
          Text('Importer mon roster', style: AppTextStyles.heading2),
          const SizedBox(height: 8),
          Text(
            'Chargez votre planning eCrew pour voir '
            'vos rotations dans l\'application.',
            style: AppTextStyles.caption.copyWith(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            )
          else ...[
            // Primary action: load demo roster
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loadDemoRoster,
                icon: const Icon(Icons.flight_takeoff),
                label: const Text('Charger mon roster Juin 2026'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'ou importer manuellement',
                    style: AppTextStyles.caption.copyWith(color: Colors.grey),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickAndParseFile,
                    icon: const Icon(Icons.upload_file, size: 18),
                    label: const Text('Fichier .txt'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pasteRosterText,
                    icon: const Icon(Icons.paste, size: 18),
                    label: const Text('Coller texte'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
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

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Le PDF ne peut pas être lu directement. '
                    'Utilisez "Coller texte" pour copier-coller '
                    'le contenu de votre roster eCrew.',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
