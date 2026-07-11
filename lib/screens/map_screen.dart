import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/manifest_model.dart';
import '../providers/trip_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/eta_panel.dart';
import '../widgets/speed_indicator.dart';
import '../widgets/trip_controls.dart';
import 'incident_list_screen.dart';
import 'manifest_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  bool _isMapReady = false;
  bool _isFollowing = true;
  Timer? _uiTicker;
  bool _breakPromptOpen = false;

  @override
  void initState() {
    super.initState();
    _initMap();
    // Refresh the driving-time chip while the trip runs.
    _uiTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _uiTicker?.cancel();
    super.dispose();
  }

  Future<void> _initMap() async {
    final provider = context.read<TripProvider>();
    final scheduleId = provider.currentTrip?.id ?? provider.selectedSchedule?.id;
    if (scheduleId != null) {
      provider.loadPickupGroups(scheduleId);
    }
    final pos = await provider.locationService.getCurrentPosition();
    if (pos != null && mounted) {
      _mapController.move(pos, 15);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TripProvider>(
      builder: (context, provider, _) {
        if (_isFollowing && provider.currentLocation != null && _isMapReady) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _mapController.move(
              provider.currentLocation!,
              _mapController.camera.zoom,
            );
          });
        }

        _maybeShowBreakPrompt(provider);

        return Scaffold(
          body: Stack(
            children: [
              _buildMap(provider),
              _buildTopBar(provider),
              if (!provider.isLocationShared) _buildNoVehicleBanner(),
              _buildFloatingControls(provider),
              _buildBottomPanel(provider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMap(TripProvider provider) {
    final center = provider.currentLocation ?? const LatLng(13.7563, 100.5018);

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 15,
        onMapReady: () => setState(() => _isMapReady = true),
        onPositionChanged: (pos, hasGesture) {
          if (hasGesture && _isFollowing) {
            setState(() => _isFollowing = false);
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.luilaykhao.driver_app',
        ),
        if (provider.currentTrip != null)
          MarkerLayer(markers: _pickupMarkers(provider)),
        if (provider.currentTrip != null)
          MarkerLayer(
            markers: [
              Marker(
                point: provider.currentTrip!.destination,
                width: 60,
                height: 60,
                child: const Icon(
                  Icons.location_on_rounded,
                  color: AppTheme.errorColor,
                  size: 40,
                ),
              ),
            ],
          ),
        if (provider.currentLocation != null)
          MarkerLayer(
            markers: [
              Marker(
                point: provider.currentLocation!,
                width: 60,
                height: 60,
                child: _buildDriverMarker(provider),
              ),
            ],
          ),
      ],
    );
  }

  /// Pickup markers driven by the fetched groups (which carry passengers +
  /// coords). Falls back to the schedule's bare pickup points, plotted but not
  /// tappable, until the groups finish loading.
  List<Marker> _pickupMarkers(TripProvider provider) {
    final groups = provider.pickupGroups.where((g) => g.hasCoords).toList();
    if (groups.isNotEmpty) {
      return [
        for (final group in groups)
          Marker(
            point: LatLng(group.lat!, group.lng!),
            width: 170,
            height: 64,
            alignment: Alignment.topCenter,
            child: GestureDetector(
              onTap: () => _showPickupSheet(group),
              child: _buildGroupMarker(group),
            ),
          ),
      ];
    }

    return [
      for (final point in provider.currentTrip!.pickupPoints)
        if (point.coords != null)
          Marker(
            point: point.coords!,
            width: 170,
            height: 64,
            alignment: Alignment.topCenter,
            child: _buildGroupMarker(
              PickupGroup(label: point.location, regionLabel: point.regionLabel),
            ),
          ),
    ];
  }

  Widget _buildGroupMarker(PickupGroup group) {
    final done = group.completed;
    final pinColor = done ? AppTheme.successColor : AppTheme.accentColor;
    final hasPax = group.passengerCount > 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: pinColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: AppTheme.softShadow,
              ),
              child: Icon(
                done
                    ? Icons.check_rounded
                    : (group.isCustom
                          ? Icons.push_pin_rounded
                          : Icons.person_pin_circle_rounded),
                color: Colors.white,
                size: 18,
              ),
            ),
            if (hasPax)
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    '${group.passengerCount}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 9,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            boxShadow: AppTheme.softShadow,
          ),
          child: Text(
            group.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTheme.textMain,
            ),
          ),
        ),
      ],
    );
  }

  void _showPickupSheet(PickupGroup group) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PickupSheet(
        group: group,
        onCall: _call,
        onOpenMap: _openMap,
      ),
    );
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openMap(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildDriverMarker(TripProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.accentColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: AppTheme.softShadow,
      ),
      child: const Icon(
        Icons.airport_shuttle_rounded,
        color: Colors.white,
        size: 20,
      ),
    );
  }

  Widget _buildTopBar(TripProvider provider) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildCircleButton(
            icon: Icons.arrow_back_rounded,
            onPressed: () {
              if (provider.isTracking) {
                _showStopConfirmation(provider);
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(20),
              boxShadow: AppTheme.softShadow,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.badge_rounded,
                  size: 16,
                  color: AppTheme.accentColor,
                ),
                const SizedBox(width: 8),
                Text(
                  provider.selectedVan?.licensePlate ?? 'N/A',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          _buildCircleButton(
            icon: Icons.my_location_rounded,
            onPressed: () => setState(() => _isFollowing = true),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          color: AppTheme.surfaceLight,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: AppTheme.textMain),
      ),
    );
  }

  Widget _buildNoVehicleBanner() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 68,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.warningColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppTheme.softShadow,
        ),
        child: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'รอบนี้ยังไม่ได้ผูกกับรถ ลูกค้าจะไม่เห็นตำแหน่งของคุณ',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingControls(TripProvider provider) {
    return Positioned(
      bottom: 240,
      right: 16,
      child: Column(children: [SpeedIndicator(speed: provider.currentSpeed)]),
    );
  }

  Widget _buildBottomPanel(TripProvider provider) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 20,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (provider.isTracking) ...[
                _DrivingTimeChip(
                  elapsed: provider.drivingElapsed,
                  breakDue: provider.breakDue,
                ),
                const SizedBox(height: 10),
              ],
              if (provider.currentTrip != null)
                ETAPanel(trip: provider.currentTrip!),
              const SizedBox(height: 14),
              if (provider.currentTrip != null) ...[
                Builder(
                  builder: (_) {
                    final mapped = provider.pickupGroups
                        .where((g) => g.hasCoords)
                        .length;
                    final count = mapped > 0
                        ? mapped
                        : provider.currentTrip!.pickupPoints.length;
                    if (count == 0) return const SizedBox.shrink();
                    return _PickupCountChip(count: count);
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ManifestScreen(
                                  schedule: provider.currentTrip!,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.groups_rounded),
                          label: const Text('รายชื่อ'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.accentColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => IncidentListScreen(
                                  scheduleId: provider.currentTrip!.id,
                                  scheduleTitle: provider.currentTrip!.title,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.report_gmailerrorred_rounded),
                          label: const Text('แจ้งเหตุ'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.errorColor,
                            side: const BorderSide(color: AppTheme.errorColor),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              TripControls(
                isTracking: provider.isTracking,
                onStart: () => provider.startTrip(),
                onStop: () => _showStopConfirmation(provider),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Pop a rest-break reminder once continuous driving crosses the threshold.
  void _maybeShowBreakPrompt(TripProvider provider) {
    if (!provider.breakDue || _breakPromptOpen) return;
    _breakPromptOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      final hours = provider.drivingElapsed.inHours;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('ถึงเวลาพักรถ 😴'),
          content: Text(
            'คุณขับต่อเนื่องมา ${hours > 0 ? '$hours ชม.' : 'สักพัก'} แล้ว '
            'เพื่อความปลอดภัย แนะนำให้จอดพักสัก 10–15 นาที ยืดเส้นยืดสาย '
            'แล้วค่อยเดินทางต่อ',
            style: GoogleFonts.anuphan(height: 1.5),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
              child: const Text('รับทราบ • พักแล้ว'),
            ),
          ],
        ),
      );
      provider.acknowledgeBreak();
      if (mounted) _breakPromptOpen = false;
    });
  }

  void _showStopConfirmation(TripProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('หยุดการเดินทาง?'),
        content: const Text(
          'คุณแน่ใจหรือไม่ว่าต้องการหยุดการแชร์ตำแหน่งและจบการเดินทางนี้?',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.stopTrip();
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('หยุดเดินทาง'),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet listing everyone to pick up at one point — tapped from a map
/// marker. Shows seat, check-in status and a call shortcut per passenger.
class _PickupSheet extends StatelessWidget {
  final PickupGroup group;
  final Future<void> Function(String phone) onCall;
  final Future<void> Function(String url) onOpenMap;

  const _PickupSheet({
    required this.group,
    required this.onCall,
    required this.onOpenMap,
  });

  @override
  Widget build(BuildContext context) {
    final notes = group.notes?.trim() ?? '';
    final mapUrl = group.mapUrl?.trim() ?? '';

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textMuted,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  group.completed
                      ? Icons.check_circle_rounded
                      : (group.isCustom
                            ? Icons.push_pin_rounded
                            : Icons.person_pin_circle_rounded),
                  color: group.completed
                      ? AppTheme.successColor
                      : AppTheme.accentColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.label,
                        style: GoogleFonts.anuphan(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textMain,
                        ),
                      ),
                      if ((group.regionLabel ?? '').isNotEmpty)
                        Text(
                          group.regionLabel!,
                          style: GoogleFonts.anuphan(
                            fontSize: 12.5,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                if (mapUrl.isNotEmpty)
                  IconButton(
                    onPressed: () => onOpenMap(mapUrl),
                    tooltip: 'เปิดแผนที่',
                    icon: const Icon(
                      Icons.directions_rounded,
                      color: AppTheme.accentColor,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'ผู้โดยสาร ${group.passengerCount} คน · เช็กอินแล้ว ${group.checkedInCount}',
              style: GoogleFonts.anuphan(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppTheme.textSecondary,
              ),
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.bgLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  notes,
                  style: GoogleFonts.anuphan(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: group.passengers.length,
                separatorBuilder: (_, _) => const Divider(height: 16),
                itemBuilder: (_, i) =>
                    _PickupPassengerRow(passenger: group.passengers[i], onCall: onCall),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickupPassengerRow extends StatelessWidget {
  final PickupGroupPassenger passenger;
  final Future<void> Function(String phone) onCall;

  const _PickupPassengerRow({required this.passenger, required this.onCall});

  @override
  Widget build(BuildContext context) {
    final avatar = passenger.avatarUrl?.trim() ?? '';
    final nickname = passenger.nickname?.trim() ?? '';
    final name = nickname.isEmpty
        ? passenger.fullName
        : '${passenger.fullName} ($nickname)';
    final seat = passenger.seatLabel?.trim() ?? '';
    final phone = passenger.phone?.trim() ?? '';

    return Row(
      children: [
        if (avatar.isNotEmpty)
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.bgLight,
            backgroundImage: NetworkImage(avatar),
          )
        else
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.bgLight,
            child: const Icon(
              Icons.person_rounded,
              size: 18,
              color: AppTheme.textSecondary,
            ),
          ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? 'ไม่ระบุชื่อ' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.anuphan(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textMain,
                ),
              ),
              Row(
                children: [
                  Icon(
                    passenger.checkedIn
                        ? Icons.check_circle_rounded
                        : Icons.schedule_rounded,
                    size: 13,
                    color: passenger.checkedIn
                        ? AppTheme.successColor
                        : AppTheme.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    passenger.checkedIn ? 'เช็กอินแล้ว' : 'ยังไม่เช็กอิน',
                    style: GoogleFonts.anuphan(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: passenger.checkedIn
                          ? AppTheme.successColor
                          : AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (seat.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.event_seat_rounded,
                  size: 13,
                  color: AppTheme.accentColor,
                ),
                const SizedBox(width: 4),
                Text(
                  seat,
                  style: GoogleFonts.anuphan(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.accentColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (phone.isNotEmpty)
          IconButton(
            onPressed: () => onCall(phone),
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.phone_rounded,
              color: AppTheme.successColor,
            ),
          ),
      ],
    );
  }
}

class _DrivingTimeChip extends StatelessWidget {
  final Duration elapsed;
  final bool breakDue;

  const _DrivingTimeChip({required this.elapsed, required this.breakDue});

  @override
  Widget build(BuildContext context) {
    final h = elapsed.inHours;
    final m = elapsed.inMinutes.remainder(60);
    final text = h > 0 ? 'ขับมาแล้ว $h ชม. $m นาที' : 'ขับมาแล้ว $m นาที';
    final color = breakDue ? AppTheme.warningColor : AppTheme.textSecondary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: breakDue
            ? AppTheme.warningColor.withValues(alpha: 0.12)
            : AppTheme.bgLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: breakDue
              ? AppTheme.warningColor.withValues(alpha: 0.4)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          Icon(
            breakDue
                ? Icons.bedtime_rounded
                : Icons.timelapse_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.anuphan(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: breakDue ? AppTheme.warningColor : AppTheme.textMain,
            ),
          ),
          const Spacer(),
          if (breakDue)
            Text(
              'ควรพัก',
              style: GoogleFonts.anuphan(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppTheme.warningColor,
              ),
            ),
        ],
      ),
    );
  }
}

class _PickupCountChip extends StatelessWidget {
  final int count;

  const _PickupCountChip({required this.count});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppTheme.accentColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.person_pin_circle_rounded,
              size: 16,
              color: AppTheme.accentColor,
            ),
            const SizedBox(width: 6),
            Text(
              'จุดรับลูกค้า $count จุด',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
