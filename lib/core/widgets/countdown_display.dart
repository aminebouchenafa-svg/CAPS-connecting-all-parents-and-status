import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class CountdownDisplay extends StatefulWidget {
  final DateTime targetTime;
  final String label;

  const CountdownDisplay({
    super.key,
    required this.targetTime,
    this.label = 'Disponible dans',
  });

  @override
  State<CountdownDisplay> createState() => _CountdownDisplayState();
}

class _CountdownDisplayState extends State<CountdownDisplay> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.targetTime.difference(DateTime.now());
    final isAvailable = remaining.isNegative;

    if (isAvailable) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: AppColors.success, size: 48),
          const SizedBox(height: 8),
          Text(
            'Disponible !',
            style: AppTextStyles.heading2.copyWith(color: AppColors.success),
          ),
        ],
      );
    }

    final hours = remaining.inHours;
    final minutes = remaining.inMinutes % 60;
    final seconds = remaining.inSeconds % 60;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.label, style: AppTextStyles.caption),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TimeUnit(value: hours, label: 'h'),
            Text(' : ', style: AppTextStyles.countdown),
            _TimeUnit(value: minutes, label: 'min'),
            Text(' : ', style: AppTextStyles.countdown),
            _TimeUnit(value: seconds, label: 'sec'),
          ],
        ),
      ],
    );
  }
}

class _TimeUnit extends StatelessWidget {
  final int value;
  final String label;

  const _TimeUnit({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value.toString().padLeft(2, '0'),
          style: AppTextStyles.countdown.copyWith(color: AppColors.primary),
        ),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}
