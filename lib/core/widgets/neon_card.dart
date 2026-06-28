import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class NeonCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color glowColor;
  final double glowIntensity;
  final bool animate;

  const NeonCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.glowColor = AppColors.neonCyan,
    this.glowIntensity = 0.3,
    this.animate = false,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: glowColor.withValues(alpha: glowIntensity),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: glowIntensity * 0.4),
            blurRadius: 12,
            spreadRadius: -2,
          ),
          BoxShadow(
            color: glowColor.withValues(alpha: glowIntensity * 0.15),
            blurRadius: 24,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: glowColor.withValues(alpha: 0.1),
          highlightColor: glowColor.withValues(alpha: 0.05),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );

    if (!animate) return card;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: child,
        ),
      ),
      child: card,
    );
  }
}
