import 'package:flutter/material.dart';

import '../../features/dashboard/domain/entities/flight_status.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class StatusBadge extends StatelessWidget {
  final FlightPhase phase;
  final bool compact;

  const StatusBadge({
    super.key,
    required this.phase,
    this.compact = false,
  });

  Color get _color => switch (phase) {
        FlightPhase.enVol => AppColors.statusEnVol,
        FlightPhase.escale => AppColors.statusEscale,
        FlightPhase.repos => AppColors.statusRepos,
        FlightPhase.retour => AppColors.statusRetour,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 16,
        vertical: compact ? 4 : 8,
      ),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(phase.emoji, style: TextStyle(fontSize: compact ? 14 : 18)),
          const SizedBox(width: 6),
          Text(
            phase.label,
            style: AppTextStyles.statusLabel.copyWith(color: _color),
          ),
        ],
      ),
    );
  }
}
