import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../dashboard/domain/entities/flight_status.dart';
import '../../../dashboard/presentation/providers/flight_status_provider.dart';
import '../../../roster/presentation/providers/roster_provider.dart';

class KidsModePage extends ConsumerStatefulWidget {
  const KidsModePage({super.key});

  @override
  ConsumerState<KidsModePage> createState() => _KidsModePageState();
}

class _KidsModePageState extends ConsumerState<KidsModePage>
    with TickerProviderStateMixin {
  late final AnimationController _planeController;
  late final AnimationController _heartController;
  late final AnimationController _pulseController;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _planeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Refresh countdown every minute
    _countdownTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _planeController.dispose();
    _heartController.dispose();
    _pulseController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roster = ref.watch(rosterProvider);
    final status = ref.watch(rosterFlightStatusProvider);

    if (roster == null) {
      return _buildNoRoster(context);
    }

    final phase = status?.phase ?? FlightPhase.repos;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 800),
        decoration: BoxDecoration(
          gradient: _gradientForPhase(phase, context),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Animated plane when en vol
              if (phase == FlightPhase.enVol) _buildAnimatedPlane(),

              // Stars and hearts for repos
              if (phase == FlightPhase.repos) _buildHeartEffect(),

              // Main content
              _buildMainContent(context, status, phase),

              // Back button
              Positioned(
                top: 8,
                left: 8,
                child: _buildBackButton(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoRoster(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF1A1A2E), const Color(0xFF0A0A1A)]
                : [const Color(0xFFE8EAF6), const Color(0xFFC5CAE9)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 8,
                left: 8,
                child: _buildBackButton(context),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '📋',
                        style: TextStyle(fontSize: 80),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Aucun roster charge',
                        style: AppTextStyles.heading1.copyWith(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 28,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Demande a Maman ou Papa\nde charger le planning !',
                        style: AppTextStyles.body.copyWith(
                          color: isDark
                              ? Colors.white70
                              : Colors.black54,
                          fontSize: 20,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return Material(
      color: Colors.black26,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => Navigator.of(context).pop(),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
              SizedBox(width: 6),
              Text(
                'Retour',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    FlightStatus? status,
    FlightPhase phase,
  ) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Big emoji with gentle pulse
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale = 1.0 + _pulseController.value * 0.08;
                return Transform.scale(
                  scale: scale,
                  child: Text(
                    _emojiForPhase(phase),
                    style: const TextStyle(fontSize: 100),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Phase name in very large text
            Text(
              phase.label,
              style: AppTextStyles.heading1.copyWith(
                fontSize: 42,
                color: Colors.white,
                shadows: [
                  const Shadow(
                    color: Colors.black26,
                    blurRadius: 8,
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Kid-friendly description
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _descriptionForPhase(phase),
                style: AppTextStyles.heading2.copyWith(
                  fontSize: 24,
                  color: Colors.white,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),

            // Countdown or home message
            if (status != null) _buildCountdownOrHome(context, status, phase),

            // Flight info for kids
            if (status?.flightNumber != null &&
                phase != FlightPhase.repos) ...[
              const SizedBox(height: 24),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('✈️', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 10),
                    Text(
                      'Vol ${status!.flightNumber}',
                      style: AppTextStyles.heading3.copyWith(
                        fontSize: 22,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCountdownOrHome(
    BuildContext context,
    FlightStatus status,
    FlightPhase phase,
  ) {
    if (phase == FlightPhase.repos) {
      return AnimatedBuilder(
        animation: _heartController,
        builder: (context, child) {
          final scale = 1.0 + _heartController.value * 0.15;
          return Transform.scale(
            scale: scale,
            child: Column(
              children: [
                const Text(
                  '❤️',
                  style: TextStyle(fontSize: 60),
                ),
                const SizedBox(height: 8),
                Text(
                  'Papa est la !',
                  style: AppTextStyles.heading1.copyWith(
                    fontSize: 32,
                    color: Colors.white,
                    shadows: [
                      const Shadow(color: Colors.black26, blurRadius: 8),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    final remaining = status.timeUntilAvailable;
    if (remaining == null || remaining == Duration.zero) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'Papa arrive bientot !',
          style: AppTextStyles.heading2.copyWith(
            fontSize: 28,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Text(
            'Papa rentre dans',
            style: AppTextStyles.heading3.copyWith(
              fontSize: 22,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hours > 0) ...[
                _buildTimeUnit(context, '$hours', 'h'),
                const SizedBox(width: 12),
              ],
              _buildTimeUnit(context, '$minutes', 'min'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeUnit(BuildContext context, String value, String unit) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: AppTextStyles.countdown.copyWith(
              fontSize: 52,
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            unit,
            style: AppTextStyles.heading2.copyWith(
              fontSize: 24,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedPlane() {
    return AnimatedBuilder(
      animation: _planeController,
      builder: (context, child) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        final x = _planeController.value * (screenWidth + 80) - 80;
        final y = screenHeight * 0.15 +
            sin(_planeController.value * pi * 2) * 30;

        return Positioned(
          left: x,
          top: y,
          child: Transform.rotate(
            angle: sin(_planeController.value * pi * 2) * 0.15,
            child: const Text(
              '✈️',
              style: TextStyle(fontSize: 48),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeartEffect() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        final random = Random(42); // Fixed seed for consistent positions

        return Stack(
          children: List.generate(8, (index) {
            final baseX = random.nextDouble() * screenWidth;
            final baseY = random.nextDouble() * screenHeight;
            final offset =
                sin((_pulseController.value + index / 8) * pi * 2) * 10;
            final opacity = 0.2 + (_pulseController.value * 0.3);
            final size = 20.0 + (index % 3) * 10;

            return Positioned(
              left: baseX,
              top: baseY + offset,
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Text(
                  index.isEven ? '⭐' : '❤️',
                  style: TextStyle(fontSize: size),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  String _emojiForPhase(FlightPhase phase) => switch (phase) {
        FlightPhase.enVol => '✈️',
        FlightPhase.escale => '🏨',
        FlightPhase.retour => '🚗',
        FlightPhase.repos => '🏠',
      };

  String _descriptionForPhase(FlightPhase phase) => switch (phase) {
        FlightPhase.enVol => 'Papa est dans l\'avion ! 🛫',
        FlightPhase.escale => 'Papa se repose a l\'hotel ✨',
        FlightPhase.retour =>
          'Papa est en route !\nIl arrive bientot ! 🎉',
        FlightPhase.repos => 'Papa est a la maison ! 🥳',
      };

  LinearGradient _gradientForPhase(FlightPhase phase, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final colors = switch (phase) {
      FlightPhase.enVol => isDark
          ? [const Color(0xFF0D1B3E), const Color(0xFF1A3A5C)]
          : [const Color(0xFF87CEEB), const Color(0xFF4A90D9)],
      FlightPhase.escale => isDark
          ? [const Color(0xFF3E2A0D), const Color(0xFF5C3A1A)]
          : [const Color(0xFFFFCC80), const Color(0xFFFF9800)],
      FlightPhase.retour => isDark
          ? [const Color(0xFF2A0D3E), const Color(0xFF3D1A5C)]
          : [const Color(0xFFCE93D8), const Color(0xFF9C27B0)],
      FlightPhase.repos => isDark
          ? [const Color(0xFF0D3E1A), const Color(0xFF1A5C2A)]
          : [const Color(0xFF81C784), const Color(0xFF4CAF50)],
    };

    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colors,
    );
  }
}
