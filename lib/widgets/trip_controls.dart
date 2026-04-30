import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TripControls extends StatefulWidget {
  final bool isTracking;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const TripControls({
    super.key,
    required this.isTracking,
    required this.onStart,
    required this.onStop,
  });

  @override
  State<TripControls> createState() => _TripControlsState();
}

class _TripControlsState extends State<TripControls>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.isTracking) _buildLiveStatus(),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: widget.isTracking ? widget.onStop : widget.onStart,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            backgroundColor: widget.isTracking
                ? AppTheme.errorColor
                : AppTheme.successColor,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.isTracking
                    ? Icons.stop_rounded
                    : Icons.play_arrow_rounded,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                widget.isTracking ? 'หยุดการเดินทาง' : 'เริ่มการเดินทาง',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLiveStatus() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.successColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(
                    alpha: 0.3 + (0.7 * _pulseController.value),
                  ),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'กำลังแชร์ตำแหน่งแบบเรียลไทม์',
                style: TextStyle(
                  color: AppTheme.successColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
