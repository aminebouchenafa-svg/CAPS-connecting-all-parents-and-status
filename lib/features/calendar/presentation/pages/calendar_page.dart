import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/demo_data.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/caps_card.dart';
import '../../domain/entities/calendar_event.dart';
import '../providers/calendar_provider.dart';
import '../widgets/add_event_sheet.dart';

class CalendarPage extends ConsumerWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final householdId = DemoData.householdId;
    final eventsAsync = ref.watch(calendarEventsProvider(householdId));
    final selectedDate = ref.watch(selectedDateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Calendrier Familial')),
      body: Column(
        children: [
          CalendarDatePicker(
            initialDate: selectedDate,
            firstDate: DateTime.now().subtract(const Duration(days: 365)),
            lastDate: DateTime.now().add(const Duration(days: 365)),
            onDateChanged: (date) {
              ref.read(selectedDateProvider.notifier).state = date;
            },
          ),
          const Divider(height: 1),
          Expanded(
            child: eventsAsync.when(
              data: (allEvents) {
                final dayEvents =
                    ref.watch(eventsForSelectedDateProvider(allEvents));
                return _EventsList(events: dayEvents);
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEventSheet(context, householdId),
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddEventSheet(BuildContext context, String householdId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AddEventSheet(householdId: householdId),
    );
  }
}

class _EventsList extends StatelessWidget {
  final List<CalendarEvent> events;

  const _EventsList({required this.events});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_available, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              'Aucun événement ce jour',
              style: AppTextStyles.body.copyWith(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: CapsCard(
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _eventColor(event.type),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.title, style: AppTextStyles.bodyBold),
                      const SizedBox(height: 2),
                      Text(
                        '${event.type.label} • ${_formatTime(event.startDate)} - ${_formatTime(event.endDate)}',
                        style: AppTextStyles.caption,
                      ),
                      if (event.description != null &&
                          event.description!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(event.description!,
                              style: AppTextStyles.caption),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  Color _eventColor(EventType type) => switch (type) {
        EventType.rotation => AppColors.statusEnVol,
        EventType.family => AppColors.accent,
        EventType.school => AppColors.info,
        EventType.medical => AppColors.error,
        EventType.activity => AppColors.success,
      };
}
