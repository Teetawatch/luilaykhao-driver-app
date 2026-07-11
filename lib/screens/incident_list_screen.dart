import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/incident_model.dart';
import '../providers/trip_provider.dart';
import '../theme/app_theme.dart';
import 'report_incident_screen.dart';

/// Log of on-trip incidents for a schedule, with a shortcut to report a new
/// one and to mark an open incident resolved.
class IncidentListScreen extends StatefulWidget {
  final int scheduleId;
  final String scheduleTitle;

  const IncidentListScreen({
    super.key,
    required this.scheduleId,
    this.scheduleTitle = '',
  });

  @override
  State<IncidentListScreen> createState() => _IncidentListScreenState();
}

const _severityColors = <String, Color>{
  'minor': AppTheme.successColor,
  'moderate': AppTheme.warningColor,
  'severe': Color(0xFFEA580C),
  'critical': AppTheme.errorColor,
};

class _IncidentListScreenState extends State<IncidentListScreen> {
  List<Incident> _incidents = [];
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
      final incidents =
          await context.read<TripProvider>().fetchIncidents(widget.scheduleId);
      if (!mounted) return;
      setState(() {
        _incidents = incidents;
        _loading = false;
      });
    } on IncidentException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _report() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReportIncidentScreen(
          scheduleId: widget.scheduleId,
          scheduleTitle: widget.scheduleTitle,
        ),
      ),
    );
    if (created == true) _load();
  }

  Future<void> _resolve(Incident incident) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('ปิดเคสนี้?'),
        content: const Text('ยืนยันว่าเหตุการณ์นี้ได้รับการจัดการเรียบร้อยแล้ว'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ปิดเคส'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final updated =
          await context.read<TripProvider>().resolveIncident(incident.id);
      if (!mounted) return;
      setState(() {
        _incidents = [
          for (final i in _incidents) i.id == updated.id ? updated : i,
        ];
      });
    } on IncidentException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppTheme.errorColor),
        );
      }
    }
  }

  Future<void> _openMap(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('แจ้งเหตุระหว่างทาง'),
        actions: [
          IconButton(
            tooltip: 'รีเฟรช',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _report,
        backgroundColor: AppTheme.errorColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.report_rounded),
        label: Text(
          'แจ้งเหตุใหม่',
          style: GoogleFonts.anuphan(fontWeight: FontWeight.w800),
        ),
      ),
      body: _buildBody(),
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

    if (_incidents.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            const SizedBox(height: 80),
            const Icon(
              Icons.verified_rounded,
              size: 56,
              color: AppTheme.successColor,
            ),
            const SizedBox(height: 12),
            Text(
              'ยังไม่มีการแจ้งเหตุในรอบนี้',
              textAlign: TextAlign.center,
              style: GoogleFonts.anuphan(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'แตะ "แจ้งเหตุใหม่" เมื่อเกิดอุบัติเหตุ บาดเจ็บ หรือรถติด',
              textAlign: TextAlign.center,
              style: GoogleFonts.anuphan(
                fontSize: 13,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: _incidents.length,
        itemBuilder: (context, index) => _IncidentCard(
          incident: _incidents[index],
          onResolve: () => _resolve(_incidents[index]),
          onOpenMap: _openMap,
        ),
      ),
    );
  }
}

class _IncidentCard extends StatelessWidget {
  final Incident incident;
  final VoidCallback onResolve;
  final Future<void> Function(String url) onOpenMap;

  const _IncidentCard({
    required this.incident,
    required this.onResolve,
    required this.onOpenMap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _severityColors[incident.severity] ?? AppTheme.warningColor;
    final time = incident.createdAt != null
        ? DateFormat('d MMM • HH:mm').format(incident.createdAt!.toLocal())
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppTheme.softShadow,
        border: Border.all(
          color: incident.isResolved
              ? const Color(0xFFE5E7EB)
              : color.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  incident.severityLabel.isEmpty
                      ? incident.severity
                      : incident.severityLabel,
                  style: GoogleFonts.anuphan(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
              const Spacer(),
              if (incident.isResolved)
                _StatusPill(
                  label: 'ปิดเคสแล้ว',
                  color: AppTheme.successColor,
                  icon: Icons.check_circle_rounded,
                )
              else
                _StatusPill(
                  label: 'เปิดอยู่',
                  color: AppTheme.errorColor,
                  icon: Icons.error_rounded,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            incident.description,
            style: GoogleFonts.anuphan(
              fontSize: 14.5,
              height: 1.4,
              color: AppTheme.textMain,
            ),
          ),
          if ((incident.passengerName ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            _MetaRow(
              icon: Icons.person_rounded,
              text: 'ผู้ประสบเหตุ: ${incident.passengerName}',
            ),
          ],
          if (incident.photoUrl != null && incident.photoUrl!.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                incident.photoUrl!,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 14,
                color: AppTheme.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                time,
                style: GoogleFonts.anuphan(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                ),
              ),
              if ((incident.reportedByName ?? '').isNotEmpty) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'โดย ${incident.reportedByName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.anuphan(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
              ] else
                const Spacer(),
              if (incident.mapUrl != null)
                GestureDetector(
                  onTap: () => onOpenMap(incident.mapUrl!),
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
                          'ตำแหน่ง',
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
          if (!incident.isResolved) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onResolve,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.successColor,
                  side: const BorderSide(color: AppTheme.successColor),
                ),
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: Text(
                  'ทำเครื่องหมายว่าจัดการแล้ว',
                  style: GoogleFonts.anuphan(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ] else if (incident.resolvedByName != null) ...[
            const SizedBox(height: 8),
            _MetaRow(
              icon: Icons.verified_user_rounded,
              text: 'ปิดโดย ${incident.resolvedByName}',
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _StatusPill({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
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
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppTheme.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.anuphan(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
