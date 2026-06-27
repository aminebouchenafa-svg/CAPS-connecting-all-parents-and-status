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
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
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

  void _parseAndLoad(String text) {
    if (text.trim().isEmpty) {
      setState(() => _error = 'Le texte est vide.');
      return;
    }

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

  Future<void> _pickTextFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final bytes = result.files.first.bytes;
      if (bytes == null || bytes.isEmpty) {
        setState(() => _error = 'Impossible de lire le fichier.');
        return;
      }

      if (_isPdfBinary(bytes)) {
        setState(() {
          _error =
              'Les PDF ne peuvent pas être lus dans le navigateur.\n'
              'Ouvrez le PDF, sélectionnez tout le texte, '
              'copiez-le et collez-le dans la zone ci-dessus.';
        });
        return;
      }

      final text = utf8.decode(bytes, allowMalformed: true);
      _parseAndLoad(text);
    } catch (e) {
      setState(() => _error = 'Erreur : $e');
    }
  }

  bool _isPdfBinary(Uint8List bytes) {
    if (bytes.length >= 4) {
      return bytes[0] == 0x25 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x44 &&
          bytes[3] == 0x46;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final hasRoster = ref.read(rosterProvider) != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            hasRoster ? 'Remplacer le roster' : 'Importer mon roster',
            style: AppTextStyles.heading2,
          ),
          const SizedBox(height: 8),

          // Instructions
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  'Comment importer votre roster eCrew :',
                  style: AppTextStyles.bodyBold.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                _buildStep('1', 'Ouvrez votre roster PDF'),
                _buildStep('2', 'Sélectionnez tout le texte'),
                _buildStep('3', 'Copiez-le'),
                _buildStep('4', 'Collez-le ci-dessous'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            )
          else ...[
            // Text input area
            SizedBox(
              height: 150,
              child: TextField(
                controller: _textController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Collez le texte de votre roster ici...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Import button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _parseAndLoad(_textController.text),
                icon: const Icon(Icons.upload_file),
                label: const Text('Importer le roster'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Secondary options
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTextFile,
                    icon: const Icon(Icons.file_open, size: 18),
                    label: const Text('Fichier .txt'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loadDemoRoster,
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('Roster démo'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
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

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(text, style: AppTextStyles.body),
        ],
      ),
    );
  }
}
