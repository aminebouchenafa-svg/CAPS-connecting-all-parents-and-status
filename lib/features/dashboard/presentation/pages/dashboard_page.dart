import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/demo_data.dart';
import '../../../../core/theme/app_colors.dart';
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
          // Header familial
          CapsCard(
            backgroundColor: AppColors.primary.withValues(alpha: 0.05),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary,
                  child: const Text('A', style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  )),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Amine', style: AppTextStyles.heading3),
                      Text(
                        status != null
                            ? _phaseDescription(status!.phase)
                            : 'Statut inconnu',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (status != null)
                  StatusBadge(phase: status!.phase, compact: true),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Carte principale du vol
          if (status != null) ...[
            CapsCard(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        status!.phase.emoji,
                        style: const TextStyle(fontSize: 32),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Où est Papa ?',
                        style: AppTextStyles.heading2,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (status!.flightNumber != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Vol ${status!.flightNumber}',
                        style: AppTextStyles.bodyBold.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (status!.destination != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.flight_land,
                            size: 18, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Direction : ${status!.destination}',
                          style: AppTextStyles.body,
                        ),
                      ],
                    ),
                  if (status!.currentLocation != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_on,
                            size: 18, color: Colors.red[400]),
                        const SizedBox(width: 6),
                        Text(
                          'Actuellement : ${status!.currentLocation}',
                          style: AppTextStyles.body,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Countdown
            if (status!.estimatedEndTime != null)
              CapsCard(
                child: Column(
                  children: [
                    Text(
                      status!.phase == FlightPhase.repos
                          ? 'Papa est disponible encore'
                          : 'Papa sera disponible dans',
                      style: AppTextStyles.heading3.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    CountdownDisplay(
                      targetTime: status!.estimatedEndTime!,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),

            // Notes
            if (status!.notes != null && status!.notes!.isNotEmpty)
              CapsCard(
                backgroundColor: AppColors.accent.withValues(alpha: 0.05),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.message,
                            size: 18, color: AppColors.accent),
                        const SizedBox(width: 8),
                        Text('Message de Papa',
                            style: AppTextStyles.heading3.copyWith(
                              color: AppColors.accent,
                            )),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(status!.notes!, style: AppTextStyles.body),
                  ],
                ),
              ),
          ],

          // Bouton pilote
          if (isPilot) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showStatusUpdateSheet(context),
              icon: const Icon(Icons.edit),
              label: const Text('Mettre à jour mon statut'),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _phaseDescription(FlightPhase phase) => switch (phase) {
        FlightPhase.enVol => 'En vol vers sa destination',
        FlightPhase.escale => 'En escale entre deux vols',
        FlightPhase.repos => 'À la maison, disponible',
        FlightPhase.retour => 'En route vers la maison',
      };

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
