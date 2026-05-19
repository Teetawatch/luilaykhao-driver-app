import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/manifest_model.dart';
import '../models/trip_model.dart';
import '../providers/trip_provider.dart';
import '../theme/app_theme.dart';

class ManifestScreen extends StatefulWidget {
  final Trip schedule;

  const ManifestScreen({super.key, required this.schedule});

  @override
  State<ManifestScreen> createState() => _ManifestScreenState();
}

class _ManifestScreenState extends State<ManifestScreen> {
  TripManifest? _manifest;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final manifest = await context.read<TripProvider>().fetchManifest(
        widget.schedule.id,
      );
      if (!mounted) return;
      setState(() {
        _manifest = manifest;
        _loading = false;
      });
    } on ManifestException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถโทรออกได้จากเครื่องนี้')),
      );
    }
  }

  Future<void> _openMap(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถเปิดแผนที่ได้')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('รายชื่อผู้โดยสาร'),
        actions: [
          IconButton(
            tooltip: 'รีเฟรช',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: _load);
    }

    final manifest = _manifest!;
    if (manifest.entries.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            _ManifestHeader(schedule: widget.schedule, manifest: manifest),
            const SizedBox(height: 60),
            const Center(
              child: Icon(
                Icons.event_seat_rounded,
                size: 56,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'ยังไม่มีการจองที่ยืนยันแล้วในรอบนี้',
              textAlign: TextAlign.center,
              style: GoogleFonts.anuphan(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: manifest.entries.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _ManifestHeader(
              schedule: widget.schedule,
              manifest: manifest,
            );
          }
          final entry = manifest.entries[index - 1];
          return _BookingCard(
            entry: entry,
            index: index,
            onCall: _call,
            onOpenMap: _openMap,
          );
        },
      ),
    );
  }
}

class _ManifestHeader extends StatelessWidget {
  final Trip schedule;
  final TripManifest manifest;

  const _ManifestHeader({required this.schedule, required this.manifest});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            schedule.title,
            style: GoogleFonts.anuphan(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: AppTheme.textMain,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _StatBlock(
                value: '${manifest.checkedInCount}/${manifest.bookingCount}',
                label: 'เช็กอินแล้ว',
                color: AppTheme.successColor,
              ),
              Container(width: 1, height: 36, color: AppTheme.bgLight),
              _StatBlock(
                value: '${manifest.bookingCount}',
                label: 'การจอง',
                color: AppTheme.accentColor,
              ),
              Container(width: 1, height: 36, color: AppTheme.bgLight),
              _StatBlock(
                value: '${manifest.passengerCount}',
                label: 'ผู้โดยสาร',
                color: AppTheme.primaryColor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatBlock({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.anuphan(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.anuphan(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final ManifestEntry entry;
  final int index;
  final Future<void> Function(String phone) onCall;
  final Future<void> Function(String url) onOpenMap;

  const _BookingCard({
    required this.entry,
    required this.index,
    required this.onCall,
    required this.onOpenMap,
  });

  @override
  Widget build(BuildContext context) {
    final pickupLabel = entry.pickupLabel;
    final contactPhone = entry.contactPhone?.trim() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.softShadow,
        border: Border.all(
          color: entry.checkedIn
              ? AppTheme.successColor.withValues(alpha: 0.4)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$index. ${entry.bookingRef}',
                  style: GoogleFonts.anuphan(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textMain,
                  ),
                ),
              ),
              _CheckInChip(entry: entry),
            ],
          ),
          if (entry.isGroup && (entry.groupName ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.groups_rounded,
                  size: 15,
                  color: AppTheme.accentColor,
                ),
                const SizedBox(width: 6),
                Text(
                  'กรุ๊ป: ${entry.groupName}',
                  style: GoogleFonts.anuphan(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accentColor,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          _ContactRow(
            name: entry.contactName ?? 'ไม่ระบุชื่อผู้จอง',
            phone: contactPhone,
            onCall: onCall,
          ),
          if (pickupLabel != null) ...[
            const SizedBox(height: 8),
            _PickupRow(entry: entry, label: pickupLabel, onOpenMap: onOpenMap),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Text(
            'ผู้เดินทาง ${entry.passengerCount} คน',
            style: GoogleFonts.anuphan(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          for (final passenger in entry.passengers)
            _PassengerRow(passenger: passenger, onCall: onCall),
        ],
      ),
    );
  }
}

class _CheckInChip extends StatelessWidget {
  final ManifestEntry entry;

  const _CheckInChip({required this.entry});

  @override
  Widget build(BuildContext context) {
    final checkedIn = entry.checkedIn;
    final time = entry.checkedInAt;
    final label = checkedIn
        ? (time != null
              ? 'เช็กอิน ${DateFormat('HH:mm').format(time.toLocal())}'
              : 'เช็กอินแล้ว')
        : 'ยังไม่เช็กอิน';
    final color = checkedIn ? AppTheme.successColor : AppTheme.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            checkedIn ? Icons.check_circle_rounded : Icons.schedule_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.anuphan(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final String name;
  final String phone;
  final Future<void> Function(String phone) onCall;

  const _ContactRow({
    required this.name,
    required this.phone,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.person_rounded,
          size: 17,
          color: AppTheme.textSecondary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.anuphan(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppTheme.textMain,
            ),
          ),
        ),
        if (phone.isNotEmpty) _CallButton(phone: phone, onCall: onCall),
      ],
    );
  }
}

class _PickupRow extends StatelessWidget {
  final ManifestEntry entry;
  final String label;
  final Future<void> Function(String url) onOpenMap;

  const _PickupRow({
    required this.entry,
    required this.label,
    required this.onOpenMap,
  });

  @override
  Widget build(BuildContext context) {
    final mapUrl = entry.pickupMapUrl?.trim() ?? '';
    final notes = entry.pickupNotes?.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.location_on_rounded,
              size: 17,
              color: AppTheme.errorColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.anuphan(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            if (mapUrl.isNotEmpty)
              GestureDetector(
                onTap: () => onOpenMap(mapUrl),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.map_rounded,
                        size: 13,
                        color: AppTheme.accentColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'แผนที่',
                        style: GoogleFonts.anuphan(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        if (notes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 25, top: 2),
            child: Text(
              notes,
              style: GoogleFonts.anuphan(
                fontSize: 12,
                color: AppTheme.textMuted,
              ),
            ),
          ),
      ],
    );
  }
}

class _PassengerRow extends StatelessWidget {
  final ManifestPassenger passenger;
  final Future<void> Function(String phone) onCall;

  const _PassengerRow({required this.passenger, required this.onCall});

  @override
  Widget build(BuildContext context) {
    final phone = passenger.phone?.trim() ?? '';
    final nickname = passenger.nickname?.trim() ?? '';
    final name = nickname.isEmpty
        ? passenger.name
        : '${passenger.name} ($nickname)';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(
              Icons.fiber_manual_record,
              size: 7,
              color: AppTheme.textMuted,
            ),
          ),
          Expanded(
            child: Text(
              name.isEmpty ? 'ไม่ระบุชื่อ' : name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.anuphan(
                fontSize: 13,
                color: AppTheme.textMain,
              ),
            ),
          ),
          if (phone.isNotEmpty) _CallButton(phone: phone, onCall: onCall),
        ],
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  final String phone;
  final Future<void> Function(String phone) onCall;

  const _CallButton({required this.phone, required this.onCall});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onCall(phone),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.successColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.phone_rounded,
              size: 14,
              color: AppTheme.successColor,
            ),
            const SizedBox(width: 4),
            Text(
              phone,
              style: GoogleFonts.anuphan(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppTheme.successColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: AppTheme.errorColor,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.anuphan(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMain,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('ลองอีกครั้ง'),
              style: FilledButton.styleFrom(
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
