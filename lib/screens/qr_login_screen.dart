import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../providers/trip_provider.dart';
import '../theme/app_theme.dart';

/// Scans the single-use QR an admin generates, so a driver can sign in without
/// typing their PIN. Accepts either a live camera scan or a saved screenshot
/// picked from the gallery.
class QrLoginScreen extends StatefulWidget {
  const QrLoginScreen({super.key});

  @override
  State<QrLoginScreen> createState() => _QrLoginScreenState();
}

class _QrLoginScreenState extends State<QrLoginScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _handling = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _firstCode(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.errorColor),
    );
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final code = _firstCode(capture);
    if (code == null) return;
    await _submit(code, pauseCamera: true);
  }

  /// Drivers often screenshot the QR the admin sends them — read it straight
  /// out of the gallery instead of making them scan a second screen.
  Future<void> _pickFromGallery() async {
    if (_handling) return;

    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;

    setState(() => _handling = true);
    try {
      final capture = await _controller.analyzeImage(
        file.path,
        formats: const [BarcodeFormat.qrCode],
      );
      final code = capture == null ? null : _firstCode(capture);

      if (code == null) {
        _showError('ไม่พบ QR ในรูปนี้ ลองเลือกรูปอื่นอีกครั้ง');
        if (mounted) setState(() => _handling = false);
        return;
      }

      await _submit(code, pauseCamera: false);
    } catch (e) {
      _showError('อ่านรูปไม่สำเร็จ กรุณาลองใหม่');
      if (mounted) setState(() => _handling = false);
    }
  }

  Future<void> _submit(String code, {required bool pauseCamera}) async {
    final provider = context.read<TripProvider>();
    if (!_handling) setState(() => _handling = true);
    if (pauseCamera) await _controller.stop();

    final success = await provider.loginWithQrCode(code);
    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
      return;
    }

    // Failed — say why and let them try another code.
    _showError(provider.statusMessage);
    if (pauseCamera) await _controller.start();
    if (mounted) setState(() => _handling = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('สแกน QR เข้าสู่ระบบ'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: GoogleFonts.anuphan(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          // Viewfinder
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          if (_handling)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 40,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'เล็งกล้องไปที่ QR ที่แอดมินเปิดให้ หรือเลือกรูปที่บันทึกไว้',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.anuphan(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _handling ? null : _pickFromGallery,
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text('เลือกรูป QR จากคลังภาพ'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.textMain,
                    textStyle: GoogleFonts.anuphan(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
