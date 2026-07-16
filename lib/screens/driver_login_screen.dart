import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/trip_provider.dart';
import '../theme/app_theme.dart';
import 'qr_login_screen.dart';

class DriverLoginScreen extends StatefulWidget {
  const DriverLoginScreen({super.key});

  @override
  State<DriverLoginScreen> createState() => _DriverLoginScreenState();
}

class _DriverLoginScreenState extends State<DriverLoginScreen> {
  String _pin = '';

  Future<void> _submit() async {
    if (_pin.length < 4) return;
    final provider = context.read<TripProvider>();
    final success = await provider.loginWithDriverPin(_pin);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.statusMessage),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      setState(() => _pin = '');
    }
  }

  void _press(String value) {
    if (_pin.length >= 8) return;
    setState(() => _pin += value);
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TripProvider>();

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Container(
                width: 76,
                height: 76,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.directions_bus_filled_rounded,
                  color: Colors.white,
                  size: 42,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'กรอกรหัสคนขับ',
                textAlign: TextAlign.center,
                style: GoogleFonts.anuphan(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textMain,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'รหัส 4-8 หลักที่แอดมินเตรียมไว้ให้',
                textAlign: TextAlign.center,
                style: GoogleFonts.anuphan(
                  fontSize: 16,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 28),
              _PinDots(length: _pin.length),
              const SizedBox(height: 28),
              if (provider.isLoggingIn)
                const Center(child: CircularProgressIndicator())
              else
                _NumberPad(onPress: _press, onBackspace: _backspace),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _pin.length >= 4 && !provider.isLoggingIn
                    ? _submit
                    : null,
                icon: const Icon(Icons.login_rounded),
                label: const Text('เข้าใช้งาน'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 58),
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  textStyle: GoogleFonts.anuphan(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: provider.isLoggingIn
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const QrLoginScreen(),
                        ),
                      ),
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('สแกน QR แทนการกรอกรหัส'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  textStyle: GoogleFonts.anuphan(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'มีปัญหาเข้าระบบ ให้ติดต่อแอดมินเพื่อขอรหัสใหม่',
                textAlign: TextAlign.center,
                style: GoogleFonts.anuphan(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinDots extends StatelessWidget {
  final int length;

  const _PinDots({required this.length});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(8, (index) {
        final filled = index < length;
        final visible = index < 4 || filled;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: visible ? 18 : 8,
          height: visible ? 18 : 8,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: filled ? AppTheme.primaryColor : Colors.transparent,
            border: Border.all(
              color: filled ? AppTheme.primaryColor : AppTheme.textMuted,
              width: 2,
            ),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}

class _NumberPad extends StatelessWidget {
  final ValueChanged<String> onPress;
  final VoidCallback onBackspace;

  const _NumberPad({required this.onPress, required this.onBackspace});

  @override
  Widget build(BuildContext context) {
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9'];

    return Column(
      children: [
        for (var row = 0; row < 3; row++) ...[
          Row(
            children: [
              for (final key in keys.skip(row * 3).take(3)) ...[
                Expanded(
                  child: _NumberKey(label: key, onTap: () => onPress(key)),
                ),
                if (key != keys[row * 3 + 2]) const SizedBox(width: 12),
              ],
            ],
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            const Expanded(child: SizedBox(height: 70)),
            const SizedBox(width: 12),
            Expanded(
              child: _NumberKey(label: '0', onTap: () => onPress('0')),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 70,
                child: IconButton(
                  onPressed: onBackspace,
                  icon: const Icon(Icons.backspace_rounded),
                  iconSize: 30,
                  color: AppTheme.textMain,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NumberKey extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _NumberKey({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 70,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.textMain,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: GoogleFonts.anuphan(
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
