import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

final hasSeenOnboardingProvider = StateProvider<bool>((ref) => false);

class WelcomePage extends ConsumerWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: PageView(
          children: [
            _WelcomeSlide(
              icon: Icons.flight_takeoff,
              iconColor: AppColors.primary,
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
              iconColor: AppColors.statusEnVol,
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
              iconColor: AppColors.accent,
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
                ref.read(hasSeenOnboardingProvider.notifier).state = true;
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 72, color: iconColor),
          const SizedBox(height: 20),
          Text(title, style: AppTextStyles.heading1, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: AppTextStyles.bodyBold.copyWith(color: AppColors.accent),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                description,
                style: AppTextStyles.body.copyWith(height: 1.6),
                textAlign: TextAlign.left,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.arrow_back_ios, size: 12, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(
                'Glissez pour continuer',
                style: AppTextStyles.caption.copyWith(color: Colors.grey[400]),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey[400]),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_month, size: 72, color: AppColors.success),
          const SizedBox(height: 20),
          Text(
            'Calendrier familial',
            style: AppTextStyles.heading1,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Toute la famille sur la même page',
            style: AppTextStyles.bodyBold.copyWith(color: AppColors.accent),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          Expanded(
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
                style: AppTextStyles.body.copyWith(height: 1.6),
                textAlign: TextAlign.left,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.rocket_launch),
              label: const Text('C\'est parti !'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
