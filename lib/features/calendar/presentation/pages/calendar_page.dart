import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../domain/entities/calendar_event.dart';
import '../providers/calendar_provider.dart';
import '../widgets/add_event_sheet.dart';

class CalendarPage extends ConsumerWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final events = ref.watch(eventsForDateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Calendrier Familial',
          style: TextStyle(
            color: isDark ? AppColors.neonCyan : onSurface,
            shadows: isDark
                ? [Shadow(color: AppColors.neonCyan.withValues(alpha: 0.5), blurRadius: 8)]
                : [],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            tooltip: isDark ? 'Mode Clair' : 'Mode Sombre',
            color: isDark ? AppColors.neonYellow : Colors.blueGrey,
            onPressed: () {
              ref.read(themeModeProvider.notifier).toggle();
            },
          ),
        ],
      ),
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
          Divider(
            height: 1,
            color: isDark
                ? AppColors.neonCyan.withValues(alpha: 0.15)
                : Theme.of(context).dividerColor,
          ),
          Expanded(
            child: _EventsList(events: events),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEventSheet(context),
        backgroundColor: isDark ? AppColors.neonCyan : Theme.of(context).colorScheme.primary,
        foregroundColor: isDark ? AppColors.backgroundDark : Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddEventSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const AddEventSheet(),
    );
  }
}

class _EventsList extends ConsumerWidget {
  final List<CalendarEvent> events;

  const _EventsList({required this.events});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_available, size: 48, color: onSurface.withValues(alpha: 0.35)),
            const SizedBox(height: 8),
            Text(
              'Aucun événement ce jour',
              style: AppTextStyles.body.copyWith(color: onSurface.withValues(alpha: 0.5)),
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
        final isRoster = event.createdByUid == 'roster';
        final color = _eventColor(event.type);

        Widget card = Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border(
              left: BorderSide(color: color, width: 4),
            ),
            boxShadow: isDark
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.12),
                      blurRadius: 10,
                      spreadRadius: -2,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  isRoster ? Icons.flight : _eventIcon(event.type),
                  color: color,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              event.title,
                              style: AppTextStyles.bodyBold.copyWith(
                                color: isDark ? Colors.white : onSurface,
                              ),
                            ),
                          ),
                          _TypeBadge(
                            label: event.type.label,
                            color: color,
                            isDark: isDark,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        event.isAllDay
                            ? 'Toute la journée'
                            : '${_formatTime(event.startDate)} - ${_formatTime(event.endDate)}',
                        style: AppTextStyles.caption.copyWith(
                          color: isDark ? Colors.white70 : onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      if (event.description != null && event.description!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            event.description!,
                            style: AppTextStyles.caption.copyWith(
                              color: isDark ? Colors.white54 : onSurface.withValues(alpha: 0.5),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (isRoster)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Roster (lecture seule)',
                            style: AppTextStyles.caption.copyWith(
                              color: color.withValues(alpha: 0.7),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (!isRoster)
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: onSurface.withValues(alpha: 0.4), size: 20),
                    tooltip: 'Supprimer',
                    onPressed: () {
                      ref.read(calendarEventsNotifierProvider.notifier).removeEvent(event.id);
                    },
                  ),
              ],
            ),
          ),
        );

        // Swipe-to-delete for non-roster events
        if (!isRoster) {
          card = Dismissible(
            key: ValueKey(event.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 24),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppColors.neonRed.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.delete, color: AppColors.neonRed, size: 28),
            ),
            confirmDismiss: (direction) async {
              return await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Supprimer'),
                  content: Text('Supprimer "${event.title}" ?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Annuler'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(
                        'Supprimer',
                        style: TextStyle(color: AppColors.neonRed),
                      ),
                    ),
                  ],
                ),
              );
            },
            onDismissed: (_) {
              ref.read(calendarEventsNotifierProvider.notifier).removeEvent(event.id);
            },
          );
        }

        return card;
      },
    );
  }

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

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

class _TypeBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool isDark;

  const _TypeBadge({
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}
