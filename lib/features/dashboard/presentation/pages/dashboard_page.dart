import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/demo_data.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/caps_card.dart';
import '../../../../core/widgets/countdown_display.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../roster/presentation/providers/roster_provider.dart';
import '../../domain/entities/flight_status.dart';
import '../providers/flight_status_provider.dart';
import '../widgets/status_update_sheet.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final householdId = DemoData.householdId;
    final isPilot = DemoData.pilot.isPilot;

    final rosterStatus = ref.watch(rosterFlightStatusProvider);
    final roster = ref.watch(rosterProvider);

    if (rosterStatus != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('C.A.P.S.')),
        body: _DashboardContent(
          status: rosterStatus,
          isPilot: isPilot,
          householdId: householdId,
          roster: roster,
        ),
      );
    }

    final statusAsync = ref.watch(currentFlightStatusProvider(householdId));
    return Scaffold(
      appBar: AppBar(title: const Text('C.A.P.S.')),
      body: statusAsync.when(
        data: (status) => _DashboardContent(
          status: status,
          isPilot: isPilot,
          householdId: householdId,
          roster: roster,
        ),
        loading: () => const Center(
          child: CircularProgressIndicator(),
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
  final dynamic roster;

  const _DashboardContent({
    required this.status,
    required this.isPilot,
    required this.householdId,
    this.roster,
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
                            : 'Aucun vol programmé aujourd\'hui',
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

          if (status != null) ...[
            // Flight info card
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
                      Text('Où est Papa ?', style: AppTextStyles.heading2),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (status!.flightNumber != null) ...[
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
                  ],

                  // Flight route with departure → arrival
                  if (status!.flightNumber != null && status!.destination != null)
                    _buildFlightRoute(),

                  if (status!.currentLocation != null &&
                      status!.flightNumber == null) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_on,
                            size: 18, color: Colors.red[400]),
                        const SizedBox(width: 6),
                        Text(
                          status!.currentLocation!,
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
                          ? 'Papa est à la maison'
                          : 'Papa sera disponible dans',
                      style: AppTextStyles.heading3.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (status!.phase == FlightPhase.repos)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle,
                              size: 48, color: AppColors.statusRepos),
                          const SizedBox(width: 12),
                          Text(
                            'Disponible !',
                            style: AppTextStyles.heading2.copyWith(
                              color: AppColors.statusRepos,
                            ),
                          ),
                        ],
                      )
                    else
                      CountdownDisplay(
                        targetTime: status!.estimatedEndTime!,
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 12),

            // Notes / Flight details
            if (status!.notes != null && status!.notes!.isNotEmpty)
              CapsCard(
                backgroundColor: AppColors.accent.withValues(alpha: 0.05),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 18, color: AppColors.accent),
                        const SizedBox(width: 8),
                        Text(
                          status!.phase == FlightPhase.repos
                              ? 'Prochain vol'
                              : 'Détails du vol',
                          style: AppTextStyles.heading3.copyWith(
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(status!.notes!, style: AppTextStyles.body),
                  ],
                ),
              ),
          ] else ...[
            // No status
            CapsCard(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.flight_takeoff,
                        size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text(
                      'Aucun vol aujourd\'hui',
                      style: AppTextStyles.heading3,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Chargez votre roster dans l\'onglet Roster '
                      'pour voir automatiquement votre programme.',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
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

  Widget _buildFlightRoute() {
    final notes = status!.notes ?? '';
    final lines = notes.split('\n');

    String? departTime;
    String? arriveTime;
    for (final line in lines) {
      if (line.startsWith('Départ prévu')) {
        departTime = line.split(':').skip(1).join(':').trim();
      }
      if (line.startsWith('Arrivée prévue')) {
        arriveTime = line.split(':').skip(1).join(':').trim();
      }
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flight_takeoff, size: 18, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              status!.currentLocation ?? '',
              style: AppTextStyles.body,
            ),
          ],
        ),
        if (departTime != null)
          Text(
            departTime,
            style: AppTextStyles.caption.copyWith(color: Colors.grey),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Icon(Icons.arrow_downward,
              size: 20, color: Colors.grey[400]),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flight_land, size: 18, color: AppColors.statusRepos),
            const SizedBox(width: 6),
            Text(
              status!.destination ?? '',
              style: AppTextStyles.bodyBold,
            ),
          ],
        ),
        if (arriveTime != null)
          Text(
            arriveTime,
            style: AppTextStyles.caption.copyWith(color: Colors.grey),
          ),
      ],
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
