import 'dart:async';
import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  StreamSubscription<Position>? _positionSubscription;
  final StreamController<LatLng> _locationController =
      StreamController<LatLng>.broadcast();
  final StreamController<double> _speedController =
      StreamController<double>.broadcast();

  Stream<LatLng> get locationStream => _locationController.stream;
  Stream<double> get speedStream => _speedController.stream;

  LatLng? lastKnownLocation;
  double lastKnownSpeed = 0;
  double lastKnownHeading = 0;

  /// Check and request location permissions
  Future<bool> checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Get current position
  Future<LatLng?> getCurrentPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final latLng = LatLng(position.latitude, position.longitude);
      lastKnownLocation = latLng;
      lastKnownSpeed = position.speed * 3.6; // m/s to km/h
      lastKnownHeading = position.heading;
      return latLng;
    } catch (e) {
      return null;
    }
  }

  /// Start tracking location updates. On Android this runs as a foreground
  /// location service and on iOS as a background location session, so updates
  /// can continue while the app is backgrounded on both platforms.
  void startTracking() {
    final LocationSettings locationSettings;
    if (Platform.isAndroid) {
      locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
        intervalDuration: const Duration(seconds: 5),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'กำลังแชร์ตำแหน่งรถตู้',
          notificationText: 'ลุยเลยเขากำลังส่งตำแหน่งแบบ Real-Time',
          notificationIcon: AndroidResource(
            name: 'ic_launcher',
            defType: 'mipmap',
          ),
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    } else if (Platform.isIOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 5,
        // Keep streaming location while the app is backgrounded. Requires the
        // `location` UIBackgroundMode and the "Always" location permission.
        allowBackgroundLocationUpdates: true,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    } else {
      locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      );
    }

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            final latLng = LatLng(position.latitude, position.longitude);
            lastKnownLocation = latLng;
            lastKnownHeading = position.heading;

            // Convert speed from m/s to km/h, minimum 0
            final speedKmh = position.speed >= 0 ? position.speed * 3.6 : 0.0;
            lastKnownSpeed = speedKmh;

            _locationController.add(latLng);
            _speedController.add(speedKmh);
          },
        );
  }

  /// Stop tracking location updates
  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  /// Dispose resources
  void dispose() {
    stopTracking();
    _locationController.close();
    _speedController.close();
  }
}
