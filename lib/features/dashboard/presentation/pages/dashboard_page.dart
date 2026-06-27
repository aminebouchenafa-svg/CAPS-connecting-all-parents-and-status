import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/caps_card.dart';
import '../../../../core/widgets/countdown_display.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../domain/entities/flight_status.dart';
import '../providers/flight_status_provider.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(rosterFlightStatusProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('C.A.P.S.')),
      body: status != null
          ? _DashboardContent(status: status)
          : _NoRosterPrompt(),
    );
  }
}

class _NoRosterPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flight_takeoff, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Où est Papa ?',
              style: AppTextStyles.heading2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Chargez votre roster dans l\'onglet Roster '
              'pour voir automatiquement votre programme du jour.',
              style: AppTextStyles.body.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.goNamed('roster'),
              icon: const Icon(Icons.flight),
              label: const Text('Aller au Roster'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final FlightStatus status;

  const _DashboardContent({required this.status});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
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
                        _phaseDescription(status.phase),
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(phase: status.phase, compact: true),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Flight info
          CapsCard(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      status.phase.emoji,
                      style: const TextStyle(fontSize: 32),
                    ),
                    const SizedBox(width: 12),
                    Text('Où est Papa ?', style: AppTextStyles.heading2),
                  ],
                ),
                const SizedBox(height: 16),

                if (status.flightNumber != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Vol ${status.flightNumber}',
                      style: AppTextStyles.bodyBold.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildFlightRoute(),
                ],

                if (status.flightNumber == null &&
                    status.currentLocation != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_on,
                          size: 18, color: Colors.red[400]),
                      const SizedBox(width: 6),
                      Text(status.currentLocation!, style: AppTextStyles.body),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Countdown or available
          if (status.phase == FlightPhase.repos)
            CapsCard(
              backgroundColor: AppColors.statusRepos.withValues(alpha: 0.05),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle,
                      size: 48, color: AppColors.statusRepos),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Papa est à la maison',
                        style: AppTextStyles.heading3.copyWith(
                          color: AppColors.statusRepos,
                        ),
                      ),
                      Text('Disponible !', style: AppTextStyles.body),
                    ],
                  ),
                ],
              ),
            )
          else if (status.estimatedEndTime != null)
            CapsCard(
              child: Column(
                children: [
                  Text(
                    'Papa sera disponible dans',
                    style: AppTextStyles.heading3.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  CountdownDisplay(
                    targetTime: status.estimatedEndTime!,
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),

          // Notes
          if (status.notes != null && status.notes!.isNotEmpty)
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
                        status.phase == FlightPhase.repos
                            ? 'Prochain vol'
                            : 'Détails du vol',
                        style: AppTextStyles.heading3.copyWith(
                          color: AppColors.accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(status.notes!, style: AppTextStyles.body),
                ],
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildFlightRoute() {
    final notes = status.notes ?? '';
    final lines = notes.split('\n');

    String? departTime;
    String? arriveTime;
    for (final line in lines) {
      if (line.contains('Départ prévu')) {
        departTime = line.split(':').skip(1).join(':').trim();
      }
      if (line.contains('Arrivée prévue')) {
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
            Text(status.currentLocation ?? '', style: AppTextStyles.body),
          ],
        ),
        if (departTime != null)
          Text(departTime,
              style: AppTextStyles.caption.copyWith(color: Colors.grey)),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Icon(Icons.arrow_downward, size: 20, color: Colors.grey[400]),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flight_land, size: 18, color: AppColors.statusRepos),
            const SizedBox(width: 6),
            Text(status.destination ?? '', style: AppTextStyles.bodyBold),
          ],
        ),
        if (arriveTime != null)
          Text(arriveTime,
              style: AppTextStyles.caption.copyWith(color: Colors.grey)),
      ],
    );
  }

  String _phaseDescription(FlightPhase phase) => switch (phase) {
        FlightPhase.enVol => 'En vol vers sa destination',
        FlightPhase.escale => 'En escale entre deux vols',
        FlightPhase.repos => 'À la maison, disponible',
        FlightPhase.retour => 'En route vers la maison',
      };
}
