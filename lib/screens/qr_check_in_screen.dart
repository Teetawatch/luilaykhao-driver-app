import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../providers/trip_provider.dart';
import '../theme/app_theme.dart';

class QrCheckInScreen extends StatefulWidget {
  const QrCheckInScreen({super.key});

  @override
  State<QrCheckInScreen> createState() => _QrCheckInScreenState();
}

class _QrCheckInScreenState extends State<QrCheckInScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _processing = false;
  CheckInResult? _lastResult;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleDetect(BarcodeCapture capture) async {
    if (_processing) return;
    String? code;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.trim().isNotEmpty) {
        code = value;
        break;
      }
    }
    if (code == null) return;

    setState(() => _processing = true);
    final provider = context.read<TripProvider>();
    await _scannerController.stop();

    final result = await provider.checkInQr(code);
    if (!mounted) return;

    setState(() {
      _lastResult = result;
      _processing = false;
    });
  }

  Future<void> _scanAgain() async {
    setState(() => _lastResult = null);
    await _scannerController.start();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TripProvider>();
    final trip = provider.selectedSchedule;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('สแกน QR เช็กอิน'),
        actions: [
          IconButton(
            tooltip: 'เปิด/ปิดไฟฉาย',
            onPressed: _scannerController.toggleTorch,
            icon: const Icon(Icons.flashlight_on_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _handleDetect,
          ),
          _ScannerFrame(tripTitle: trip?.title ?? 'ยังไม่ได้เลือกรอบเดินทาง'),
          if (_processing || provider.isCheckingIn)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),
          if (_lastResult != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: _ResultSheet(
                result: _lastResult!,
                onScanAgain: _scanAgain,
              ),
            ),
        ],
      ),
    );
  }
}

class _ScannerFrame extends StatelessWidget {
  final String tripTitle;

  const _ScannerFrame({required this.tripTitle});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.62),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_seat_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tripTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.anuphan(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'จัด QR Code ให้อยู่ในกรอบ',
              style: GoogleFonts.anuphan(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _ResultSheet extends StatelessWidget {
  final CheckInResult result;
  final VoidCallback onScanAgain;

  const _ResultSheet({required this.result, required this.onScanAgain});

  @override
  Widget build(BuildContext context) {
    final booking = result.booking ?? const <String, dynamic>{};
    final passengers = booking['passengers'] is List
        ? List<dynamic>.from(booking['passengers'] as List)
        : const <dynamic>[];
    final firstPassenger = passengers.isNotEmpty && passengers.first is Map
        ? Map<String, dynamic>.from(passengers.first as Map)
        : const <String, dynamic>{};
    final passengerName = [
      firstPassenger['title']?.toString(),
      firstPassenger['name']?.toString(),
    ].where((text) => text != null && text.isNotEmpty).join(' ');

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  result.success
                      ? Icons.check_circle_rounded
                      : Icons.error_rounded,
                  color: result.success
                      ? AppTheme.successColor
                      : AppTheme.errorColor,
                  size: 32,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    result.message,
                    style: GoogleFonts.anuphan(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textMain,
                    ),
                  ),
                ),
              ],
            ),
            if (result.success) ...[
              const SizedBox(height: 14),
              _ResultRow(
                label: 'หมายเลขการจอง',
                value: booking['booking_ref']?.toString() ?? '-',
              ),
              _ResultRow(
                label: 'ผู้เดินทาง',
                value: passengerName.isEmpty
                    ? '${passengers.length} คน'
                    : passengerName,
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onScanAgain,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('สแกนรายการถัดไป'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;

  const _ResultRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: GoogleFonts.anuphan(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.anuphan(
                color: AppTheme.textMain,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
