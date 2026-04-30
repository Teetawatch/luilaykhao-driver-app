import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SpeedIndicator extends StatelessWidget {
  final double speed;

  const SpeedIndicator({super.key, required this.speed});

  @override
  Widget build(BuildContext context) {
    final displaySpeed = speed.clamp(0, 200).toInt();

    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        shape: BoxShape.circle,
        boxShadow: AppTheme.softShadow,
        border: Border.all(
          color: _getSpeedColor(displaySpeed.toDouble()).withValues(alpha: 0.5),
          width: 3,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$displaySpeed',
            style: TextStyle(
              color: _getSpeedColor(displaySpeed.toDouble()),
              fontSize: 24,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
          const Text(
            'กม/ชม',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getSpeedColor(double speed) {
    if (speed < 40) return AppTheme.successColor;
    if (speed < 90) return AppTheme.accentColor;
    if (speed < 110) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }
}
