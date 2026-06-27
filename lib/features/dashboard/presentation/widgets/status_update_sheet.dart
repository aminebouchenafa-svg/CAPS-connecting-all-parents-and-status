import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/demo_data.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/flight_status.dart';
import '../providers/flight_status_provider.dart';

class StatusUpdateSheet extends ConsumerStatefulWidget {
  final FlightStatus? currentStatus;
  final String householdId;

  const StatusUpdateSheet({
    super.key,
    this.currentStatus,
    required this.householdId,
  });

  @override
  ConsumerState<StatusUpdateSheet> createState() => _StatusUpdateSheetState();
}

class _StatusUpdateSheetState extends ConsumerState<StatusUpdateSheet> {
  late FlightPhase _selectedPhase;
  final _flightNumberController = TextEditingController();
  final _destinationController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _estimatedEndTime;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedPhase = widget.currentStatus?.phase ?? FlightPhase.repos;
    _flightNumberController.text = widget.currentStatus?.flightNumber ?? '';
    _destinationController.text = widget.currentStatus?.destination ?? '';
    _locationController.text = widget.currentStatus?.currentLocation ?? '';
    _notesController.text = widget.currentStatus?.notes ?? '';
    _estimatedEndTime = widget.currentStatus?.estimatedEndTime;
  }

  @override
  void dispose() {
    _flightNumberController.dispose();
    _destinationController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveStatus() async {
    setState(() => _isSaving = true);

    final status = FlightStatus(
      id: widget.currentStatus?.id ?? const Uuid().v4(),
      pilotUid: DemoData.pilot.uid,
      householdId: widget.householdId,
      phase: _selectedPhase,
      startTime: DateTime.now(),
      estimatedEndTime: _estimatedEndTime,
      currentLocation: _locationController.text.isNotEmpty
          ? _locationController.text
          : null,
      flightNumber: _flightNumberController.text.isNotEmpty
          ? _flightNumberController.text
          : null,
      destination: _destinationController.text.isNotEmpty
          ? _destinationController.text
          : null,
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      updatedAt: DateTime.now(),
    );

    final result = await ref
        .read(flightStatusRepositoryProvider)
        .updateStatus(status);

    if (!mounted) return;

    result.when(
      success: (_) => Navigator.of(context).pop(),
      failure: (failure) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      },
    );
  }

  Future<void> _pickEstimatedEndTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _estimatedEndTime ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
          _estimatedEndTime ?? DateTime.now()),
    );
    if (time == null) return;

    setState(() {
      _estimatedEndTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Mettre à jour le statut', style: AppTextStyles.heading2),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: FlightPhase.values.map((phase) {
                final isSelected = phase == _selectedPhase;
                return ChoiceChip(
                  label: Text('${phase.emoji} ${phase.label}'),
                  selected: isSelected,
                  selectedColor: _phaseColor(phase).withValues(alpha: 0.2),
                  onSelected: (_) => setState(() => _selectedPhase = phase),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            if (_selectedPhase == FlightPhase.enVol) ...[
              TextField(
                controller: _flightNumberController,
                decoration: const InputDecoration(
                  labelText: 'Numéro de vol',
                  prefixIcon: Icon(Icons.flight),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _destinationController,
                decoration: const InputDecoration(
                  labelText: 'Destination',
                  prefixIcon: Icon(Icons.place),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Localisation actuelle',
                prefixIcon: Icon(Icons.location_on),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickEstimatedEndTime,
              icon: const Icon(Icons.schedule),
              label: Text(
                _estimatedEndTime != null
                    ? 'Fin estimée: ${_estimatedEndTime!.day}/${_estimatedEndTime!.month} à ${_estimatedEndTime!.hour}h${_estimatedEndTime!.minute.toString().padLeft(2, '0')}'
                    : 'Définir la fin estimée',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes pour la famille',
                prefixIcon: Icon(Icons.note),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSaving ? null : _saveStatus,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  Color _phaseColor(FlightPhase phase) => switch (phase) {
        FlightPhase.enVol => AppColors.statusEnVol,
        FlightPhase.escale => AppColors.statusEscale,
        FlightPhase.repos => AppColors.statusRepos,
        FlightPhase.retour => AppColors.statusRetour,
      };
}
