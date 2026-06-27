import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/demo_data.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/caps_card.dart';
import '../../../../core/widgets/countdown_display.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../domain/entities/flight_status.dart';
import '../providers/flight_status_provider.dart';
import '../widgets/status_update_sheet.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final householdId = DemoData.householdId;
    final isPilot = DemoData.pilot.isPilot;
    final statusAsync = ref.watch(currentFlightStatusProvider(householdId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('C.A.P.S.'),
      ),
      body: statusAsync.when(
        data: (status) => _DashboardContent(
          status: status,
          isPilot: isPilot,
          householdId: householdId,
        ),
        loading: () => const LoadingIndicator(
          message: 'Chargement du statut...',
        ),
        error: (e, _) => Center(child: Text('Erreur: $e')),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final FlightStatus? status;
  final bool isPilot;
  final String householdId;

  const _DashboardContent({
    required this.status,
    required this.isPilot,
    required this.householdId,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CapsCard(
            child: Column(
              children: [
                Text('Statut actuel', style: AppTextStyles.heading3),
                const SizedBox(height: 12),
                if (status != null) ...[
                  StatusBadge(phase: status!.phase),
                  const SizedBox(height: 16),
                  if (status!.flightNumber != null)
                    Text('Vol ${status!.flightNumber}',
                        style: AppTextStyles.body),
                  if (status!.destination != null)
                    Text(status!.destination!, style: AppTextStyles.caption),
                  if (status!.currentLocation != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.location_on, size: 16),
                        const SizedBox(width: 4),
                        Text(status!.currentLocation!,
                            style: AppTextStyles.caption),
                      ],
                    ),
                  ],
                ] else
                  Text('Aucun statut', style: AppTextStyles.body),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (status?.estimatedEndTime != null)
            CapsCard(
              child: CountdownDisplay(
                targetTime: status!.estimatedEndTime!,
                label: status!.phase == FlightPhase.repos
                    ? 'Repos restant'
                    : 'Disponible dans',
              ),
            ),
          const SizedBox(height: 16),
          if (status?.notes != null && status!.notes!.isNotEmpty)
            CapsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Notes', style: AppTextStyles.heading3),
                  const SizedBox(height: 8),
                  Text(status!.notes!, style: AppTextStyles.body),
                ],
              ),
            ),
          if (isPilot) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showStatusUpdateSheet(context),
              icon: const Icon(Icons.edit),
              label: const Text('Mettre à jour le statut'),
            ),
          ],
        ],
      ),
    );
  }

  void _showStatusUpdateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatusUpdateSheet(
        currentStatus: status,
        householdId: householdId,
      ),
    );
  }
}
