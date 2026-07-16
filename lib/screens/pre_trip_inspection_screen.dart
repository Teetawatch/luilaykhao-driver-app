import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/inspection_model.dart';
import '../providers/trip_provider.dart';
import '../theme/app_theme.dart';

/// Pre-trip vehicle safety checklist. The driver confirms each item; a critical
/// item left unchecked warns before departure. Pops `true` once saved so the
/// caller can proceed to start tracking.
class PreTripInspectionScreen extends StatefulWidget {
  final int scheduleId;
  final String scheduleTitle;

  const PreTripInspectionScreen({
    super.key,
    required this.scheduleId,
    this.scheduleTitle = '',
  });

  @override
  State<PreTripInspectionScreen> createState() =>
      _PreTripInspectionScreenState();
}

class _PreTripInspectionScreenState extends State<PreTripInspectionScreen> {
  final _noteController = TextEditingController();

  List<InspectionItem> _items = [];
  final Map<String, bool> _checked = {};
  Inspection? _previous;
  bool _loading = true;
  String? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final state = await context.read<TripProvider>().fetchInspection(
        widget.scheduleId,
      );
      if (!mounted) return;
      setState(() {
        _items = state.template;
        _previous = state.latest;
        for (final item in state.template) {
          _checked[item.key] = false;
        }
        _loading = false;
      });
    } on InspectionException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  int get _passedCount => _checked.values.where((v) => v).length;

  bool get _allChecked =>
      _items.isNotEmpty && _items.every((i) => _checked[i.key] == true);

  void _setAll(bool value) {
    HapticFeedback.selectionClick();
    setState(() {
      for (final item in _items) {
        _checked[item.key] = value;
      }
    });
  }

  Future<void> _submit() async {
    final provider = context.read<TripProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final failedCritical = _items
        .where((i) => i.critical && _checked[i.key] != true)
        .toList();

    if (failedCritical.isNotEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text('มีรายการสำคัญยังไม่ผ่าน'),
          content: Text(
            'รายการความปลอดภัยที่ยังไม่ผ่าน: ${failedCritical.map((e) => e.label).join(', ')}\n\nยืนยันบันทึกและออกเดินทางทั้งที่มีความเสี่ยง?',
            style: GoogleFonts.anuphan(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('กลับไปตรวจ'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
              ),
              child: const Text('ยืนยันออกเดินทาง'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() => _submitting = true);
    try {
      double? lat;
      double? lng;
      final pos = await provider.locationService.getCurrentPosition();
      if (pos != null) {
        lat = pos.latitude;
        lng = pos.longitude;
      }
      await provider.submitInspection(
        scheduleId: widget.scheduleId,
        items: Map<String, bool>.from(_checked),
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        latitude: lat,
        longitude: lng,
      );
      if (!mounted) return;
      navigator.pop(true);
    } on InspectionException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppTheme.errorColor),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text('ตรวจสภาพรถก่อนออก')),
      body: _buildBody(),
      bottomNavigationBar: (_loading || _error != null)
          ? null
          : _buildSubmitBar(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
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
                _error!,
                textAlign: TextAlign.center,
                style: GoogleFonts.anuphan(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMain,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('ลองอีกครั้ง'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (widget.scheduleTitle.isNotEmpty) ...[
          Text(
            widget.scheduleTitle,
            style: GoogleFonts.anuphan(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_previous != null) _PreviousBanner(inspection: _previous!),
        Row(
          children: [
            Text(
              'ตรวจแล้ว $_passedCount/${_items.length}',
              style: GoogleFonts.anuphan(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: AppTheme.textMain,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _setAll(!_allChecked),
              icon: Icon(
                _allChecked
                    ? Icons.remove_done_rounded
                    : Icons.done_all_rounded,
                size: 18,
              ),
              label: Text(_allChecked ? 'ล้างทั้งหมด' : 'ผ่านทั้งหมด'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (final item in _items)
          _InspectionTile(
            item: item,
            value: _checked[item.key] ?? false,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              setState(() => _checked[item.key] = v);
            },
          ),
        const SizedBox(height: 16),
        Text(
          'หมายเหตุ (ถ้ามี)',
          style: GoogleFonts.anuphan(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _noteController,
          style: GoogleFonts.anuphan(fontSize: 14.5),
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'สภาพรถ ปัญหาที่พบ หรือสิ่งที่ต้องแจ้งอู่',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.verified_rounded),
            label: Text(
              _submitting ? 'กำลังบันทึก...' : 'บันทึกผลตรวจ • เริ่มเดินทาง',
              style: GoogleFonts.anuphan(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviousBanner extends StatelessWidget {
  final Inspection inspection;

  const _PreviousBanner({required this.inspection});

  @override
  Widget build(BuildContext context) {
    final time = inspection.createdAt != null
        ? DateFormat('d MMM HH:mm').format(inspection.createdAt!.toLocal())
        : '';
    final color = inspection.passed
        ? AppTheme.successColor
        : AppTheme.warningColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.history_rounded, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'ตรวจล่าสุด $time'
              '${inspection.inspectedByName != null ? ' • ${inspection.inspectedByName}' : ''}'
              '${inspection.passed ? ' • ผ่านทั้งหมด' : ' • มีรายการไม่ผ่าน'}',
              style: GoogleFonts.anuphan(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InspectionTile extends StatelessWidget {
  final InspectionItem item;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _InspectionTile({
    required this.item,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value
              ? AppTheme.successColor.withValues(alpha: 0.4)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    item.label,
                    style: GoogleFonts.anuphan(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMain,
                    ),
                  ),
                ),
                if (item.critical) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'สำคัญ',
                      style: GoogleFonts.anuphan(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.errorColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppTheme.successColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
