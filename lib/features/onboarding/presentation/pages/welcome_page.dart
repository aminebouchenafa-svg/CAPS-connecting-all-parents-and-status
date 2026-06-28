import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

final hasSeenOnboardingProvider =
    StateNotifierProvider<HasSeenOnboardingNotifier, bool>((ref) {
  return HasSeenOnboardingNotifier();
});

class HasSeenOnboardingNotifier extends StateNotifier<bool> {
  HasSeenOnboardingNotifier() : super(StorageService.getOnboardingSeen());

  void markSeen() {
    state = true;
    StorageService.saveOnboardingSeen(true);
  }
}

class WelcomePage extends ConsumerWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: PageView(
          children: [
            _WelcomeSlide(
              icon: Icons.flight_takeoff,
              iconColor: AppColors.neonCyan,
              title: 'Bienvenue sur C.A.P.S.',
              subtitle: 'Cockpit Familial',
              description:
                  'Amine est pilote basé à Alger. '
                  'Quand il part en rotation, sa famille peut '
                  'suivre en temps réel :\n\n'
                  '• Où il se trouve\n'
                  '• Dans quelle phase de vol il est\n'
                  '• Quand il sera de retour\n'
                  '• Ses messages pour la famille\n\n'
                  'Amina, Ilyane et Yanis restent connectés '
                  'même quand Papa est loin.',
            ),
            _WelcomeSlide(
              icon: Icons.radar,
              iconColor: AppColors.neonCyan,
              title: '4 phases de vol',
              subtitle: 'Pour savoir où est Papa',
              description:
                  '✈️  EN VOL\n'
                  'Amine est dans le cockpit, en route.\n\n'
                  '🏨  ESCALE\n'
                  'Amine est à l\'hôtel, entre deux vols.\n\n'
                  '🚗  RETOUR\n'
                  'Amine est en route vers la maison.\n\n'
                  '🏠  REPOS\n'
                  'Amine est à la maison. Disponible !',
            ),
            _WelcomeSlide(
              icon: Icons.timer,
              iconColor: AppColors.neonMagenta,
              title: 'Compte à rebours',
              subtitle: 'Papa rentre dans combien de temps ?',
              description:
                  'Un compteur décompte en temps réel '
                  'le temps restant avant qu\'Amine soit disponible.\n\n'
                  'Ilyane et Yanis peuvent regarder '
                  'le compteur descendre et savoir '
                  'exactement quand Papa sera là.\n\n'
                  'Plus besoin de demander 10 fois par jour !',
            ),
            _LastSlide(
              onStart: () {
                ref.read(hasSeenOnboardingProvider.notifier).markSeen();
                context.go('/');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeSlide extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String description;

  const _WelcomeSlide({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final cardBg = isDark ? AppColors.cardDark : Colors.white;
    final subtextColor = isDark ? Colors.white70 : Colors.black54;
    final hintColor = isDark ? AppColors.neonCyan.withValues(alpha: 0.4) : Colors.grey;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withValues(alpha: 0.1),
              border: Border.all(color: iconColor.withValues(alpha: 0.3)),
              boxShadow: isDark
                  ? [BoxShadow(color: iconColor.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: -4)]
                  : [],
            ),
            child: Icon(icon, size: 56, color: iconColor),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: AppTextStyles.heading1.copyWith(
              color: onSurface,
              shadows: isDark ? [Shadow(color: AppColors.neonCyan.withValues(alpha: 0.4), blurRadius: 8)] : [],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: AppTextStyles.bodyBold.copyWith(
              color: AppColors.neonMagenta,
              shadows: isDark ? [Shadow(color: AppColors.neonMagenta.withValues(alpha: 0.5), blurRadius: 6)] : [],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.neonCyan.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.2),
                ),
                boxShadow: isDark
                    ? []
                    : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
              ),
              child: SingleChildScrollView(
                child: Text(
                  description,
                  style: AppTextStyles.body.copyWith(
                    height: 1.6,
                    color: subtextColor,
                  ),
                  textAlign: TextAlign.left,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.arrow_back_ios, size: 12, color: hintColor),
              const SizedBox(width: 4),
              Text(
                'Glissez pour continuer',
                style: AppTextStyles.caption.copyWith(color: hintColor),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios, size: 12, color: hintColor),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _LastSlide extends StatelessWidget {
  final VoidCallback onStart;

  const _LastSlide({required this.onStart});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final cardBg = isDark ? AppColors.cardDark : Colors.white;
    final subtextColor = isDark ? Colors.white70 : Colors.black54;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.neonGreen.withValues(alpha: 0.1),
              border: Border.all(color: AppColors.neonGreen.withValues(alpha: 0.3)),
              boxShadow: isDark
                  ? [BoxShadow(color: AppColors.neonGreen.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: -4)]
                  : [],
            ),
            child: Icon(Icons.calendar_month, size: 56, color: AppColors.neonGreen),
          ),
          const SizedBox(height: 24),
          Text(
            'Calendrier familial',
            style: AppTextStyles.heading1.copyWith(
              color: onSurface,
              shadows: isDark ? [Shadow(color: AppColors.neonGreen.withValues(alpha: 0.4), blurRadius: 8)] : [],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Toute la famille sur la même page',
            style: AppTextStyles.bodyBold.copyWith(
              color: AppColors.neonMagenta,
              shadows: isDark ? [Shadow(color: AppColors.neonMagenta.withValues(alpha: 0.5), blurRadius: 6)] : [],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.neonGreen.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.2),
                ),
                boxShadow: isDark
                    ? []
                    : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
              ),
              child: SingleChildScrollView(
                child: Text(
                  'Les rotations d\'Amine et les événements '
                  'familiaux au même endroit :\n\n'
                  '✈️  Rotations — Vols d\'Amine\n\n'
                  '📚  École — Spectacles, réunions\n\n'
                  '🏥  Médical — RDV pédiatre, vaccins\n\n'
                  '🎂  Famille — Anniversaires, sorties\n\n'
                  '⚽  Activités — Sport, loisirs\n\n'
                  'Tout le monde sait ce qui se passe, '
                  'même quand Amine est en vol.',
                  style: AppTextStyles.body.copyWith(
                    height: 1.6,
                    color: subtextColor,
                  ),
                  textAlign: TextAlign.left,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.rocket_launch),
              label: const Text('C\'est parti !', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
