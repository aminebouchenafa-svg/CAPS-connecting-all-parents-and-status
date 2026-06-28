import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/demo_data.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/calendar_event.dart';
import '../providers/calendar_provider.dart';

class AddEventSheet extends ConsumerStatefulWidget {
  const AddEventSheet({super.key});

  @override
  ConsumerState<AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends ConsumerState<AddEventSheet> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  EventType _selectedType = EventType.family;
  late DateTime _startDate;
  late DateTime _endDate;
  bool _isAllDay = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day, now.hour + 1);
    _endDate = _startDate.add(const Duration(hours: 1));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final initialDate = isStart ? _startDate : _endDate;
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    if (_isAllDay) {
      setState(() {
        if (isStart) {
          _startDate = DateTime(date.year, date.month, date.day);
        } else {
          _endDate = DateTime(date.year, date.month, date.day, 23, 59);
        }
      });
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (time == null || !mounted) return;

    setState(() {
      final dt =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
      if (isStart) {
        _startDate = dt;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(hours: 1));
        }
      } else {
        _endDate = dt;
      }
    });
  }

  void _save() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le titre est obligatoire')),
      );
      return;
    }

    final event = CalendarEvent(
      id: const Uuid().v4(),
      householdId: DemoData.householdId,
      createdByUid: DemoData.pilot.uid,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
      type: _selectedType,
      startDate: _startDate,
      endDate: _endDate,
      isAllDay: _isAllDay,
      createdAt: DateTime.now(),
    );

    ref.read(calendarEventsNotifierProvider.notifier).addEvent(event);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;

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
            // Header
            Text(
              'Nouvel événement',
              style: AppTextStyles.heading2.copyWith(
                color: isDark ? AppColors.neonCyan : onSurface,
              ),
            ),
            const SizedBox(height: 20),

            // Title field
            TextField(
              controller: _titleController,
              style: TextStyle(color: onSurface),
              decoration: InputDecoration(
                labelText: 'Titre',
                prefixIcon: Icon(Icons.title, color: onSurface.withValues(alpha: 0.6)),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Description field
            TextField(
              controller: _descriptionController,
              maxLines: 2,
              style: TextStyle(color: onSurface),
              decoration: InputDecoration(
                labelText: 'Description (optionnel)',
                prefixIcon: Icon(Icons.notes, color: onSurface.withValues(alpha: 0.6)),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Event type selector
            Text(
              'Type',
              style: AppTextStyles.heading3.copyWith(color: onSurface),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: EventType.values
                  .where((t) => t != EventType.rotation) // rotation is roster-only
                  .map((type) {
                final isSelected = type == _selectedType;
                final color = _eventColor(type);
                return ChoiceChip(
                  avatar: Icon(_eventIcon(type), size: 16, color: isSelected ? color : onSurface.withValues(alpha: 0.5)),
                  label: Text(type.label),
                  selected: isSelected,
                  selectedColor: color.withValues(alpha: isDark ? 0.25 : 0.15),
                  labelStyle: TextStyle(
                    color: isSelected ? color : onSurface.withValues(alpha: 0.7),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  side: isSelected
                      ? BorderSide(color: color.withValues(alpha: 0.5))
                      : null,
                  onSelected: (_) => setState(() => _selectedType = type),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // All-day toggle
            SwitchListTile(
              title: Text('Toute la journée', style: TextStyle(color: onSurface)),
              value: _isAllDay,
              activeColor: isDark ? AppColors.neonCyan : Theme.of(context).colorScheme.primary,
              onChanged: (val) => setState(() => _isAllDay = val),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),

            // Date/time pickers
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDateTime(isStart: true),
                    icon: Icon(Icons.play_arrow, size: 18,
                        color: isDark ? AppColors.neonGreen : null),
                    label: Text(
                      _formatDateTime(_startDate),
                      style: TextStyle(fontSize: 12, color: onSurface),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDateTime(isStart: false),
                    icon: Icon(Icons.stop, size: 18,
                        color: isDark ? AppColors.neonRed : null),
                    label: Text(
                      _formatDateTime(_endDate),
                      style: TextStyle(fontSize: 12, color: onSurface),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Save button
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColors.neonCyan : Theme.of(context).colorScheme.primary,
                foregroundColor: isDark ? AppColors.backgroundDark : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final date = '${dt.day}/${dt.month.toString().padLeft(2, '0')}';
    if (_isAllDay) return date;
    return '$date ${dt.hour}h${dt.minute.toString().padLeft(2, '0')}';
  }

  Color _eventColor(EventType type) => switch (type) {
        EventType.rotation => AppColors.neonCyan,
        EventType.family => AppColors.neonMagenta,
        EventType.school => AppColors.neonPurple,
        EventType.medical => AppColors.neonRed,
        EventType.activity => AppColors.neonGreen,
      };

  IconData _eventIcon(EventType type) => switch (type) {
        EventType.rotation => Icons.flight,
        EventType.family => Icons.family_restroom,
        EventType.school => Icons.school,
        EventType.medical => Icons.local_hospital,
        EventType.activity => Icons.sports_soccer,
      };
}
