import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class CapsCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? glowColor;

  const CapsCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.backgroundColor,
    this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    final glow = glowColor ?? AppColors.neonCyan;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: 0.15),
            blurRadius: 12,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Card(
        color: backgroundColor ?? AppColors.cardDark,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: glow.withValues(alpha: 0.1),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}
