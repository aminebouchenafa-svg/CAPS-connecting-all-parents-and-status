import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class NeonBadge extends StatefulWidget {
  final String text;
  final Color color;
  final bool pulse;
  final double fontSize;

  const NeonBadge({
    super.key,
    required this.text,
    this.color = AppColors.neonCyan,
    this.pulse = false,
    this.fontSize = 12,
  });

  @override
  State<NeonBadge> createState() => _NeonBadgeState();
}

class _NeonBadgeState extends State<NeonBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _glowAnimation = Tween(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.pulse) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.pulse) {
      return _buildBadge(0.5);
    }
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, _) => _buildBadge(_glowAnimation.value),
    );
  }

  Widget _buildBadge(double intensity) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: widget.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.color.withValues(alpha: intensity),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.color.withValues(alpha: intensity * 0.4),
            blurRadius: 8,
            spreadRadius: -1,
          ),
        ],
      ),
      child: Text(
        widget.text,
        style: TextStyle(
          color: widget.color,
          fontSize: widget.fontSize,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          shadows: [
            Shadow(
              color: widget.color.withValues(alpha: intensity * 0.6),
              blurRadius: 6,
            ),
          ],
        ),
      ),
    );
  }
}
