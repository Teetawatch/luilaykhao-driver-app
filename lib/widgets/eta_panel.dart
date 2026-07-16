import 'package:flutter/material.dart';
import '../models/trip_model.dart';
import '../theme/app_theme.dart';

class ETAPanel extends StatelessWidget {
  final Trip trip;

  const ETAPanel({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final eta = trip.getETAFormatted();
    final distance = trip.getRemainingDistance();
    final distanceText = distance != null
        ? distance >= 1
              ? '${distance.toStringAsFixed(1)} กม.'
              : '${(distance * 1000).toInt()} ม.'
        : '--';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.bgLight),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.flag_rounded,
                  color: AppTheme.errorColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'จุดหมายของคุณ',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      trip.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildInfoBlock(
                  icon: Icons.access_time_filled_rounded,
                  iconColor: AppTheme.accentColor,
                  label: 'จะถึงในประมาณ',
                  value: eta,
                  valueColor: AppTheme.accentColor,
                ),
              ),
              Container(width: 1, height: 40, color: AppTheme.bgLight),
              Expanded(
                child: _buildInfoBlock(
                  icon: Icons.straighten_rounded,
                  iconColor: AppTheme.textMain,
                  label: 'ระยะทางที่เหลือ',
                  value: distanceText,
                  valueColor: AppTheme.textMain,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBlock({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
