import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/trip_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/eta_panel.dart';
import '../widgets/speed_indicator.dart';
import '../widgets/trip_controls.dart';
import 'qr_check_in_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  bool _isMapReady = false;
  bool _isFollowing = true;

  @override
  void initState() {
    super.initState();
    _initMap();
  }

  Future<void> _initMap() async {
    final provider = context.read<TripProvider>();
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

        return Scaffold(
          body: Stack(
            children: [
              _buildMap(provider),
              _buildTopBar(provider),
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
              if (provider.currentTrip != null)
                ETAPanel(trip: provider.currentTrip!),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const QrCheckInScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('สแกนเช็กอิน'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accentColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
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
