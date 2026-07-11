import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/incident_model.dart';
import '../models/inspection_model.dart';
import '../models/manifest_model.dart';
import '../models/trip_model.dart';
import '../models/van_model.dart';
import '../services/location_service.dart';

class TripProvider extends ChangeNotifier {
  // Production
  static const String baseUrl = 'https://luilaykhao.com/api/v1';
  // Android Emulator (local dev): 'http://10.0.2.2:8000/api/v1'

  final LocationService _locationService = LocationService();
  static const String _tokenKey = 'driver_auth_token';

  List<Trip> _todaySchedules = [];

  Map<String, dynamic>? _driverUser;
  String? _token;
  Trip? _currentTrip;
  Van? _selectedVan;
  Trip? _selectedSchedule;

  bool _isRestoringSession = true;
  bool _isLoggingIn = false;
  bool _isTracking = false;
  bool _isLoadingSchedules = false;
  String _statusMessage = '';

  List<PickupGroup> _pickupGroups = [];
  bool _isLoadingPickupGroups = false;

  /// Schedules whose pre-trip inspection is known done (this session or found
  /// on the server) — gates "เริ่มติดตาม".
  final Set<int> _inspectedSchedules = {};

  double _currentSpeed = 0;
  LatLng? _currentLocation;
  StreamSubscription<LatLng>? _locationSub;
  StreamSubscription<double>? _speedSub;
  Timer? _locationReportTimer;
  bool _isReportingLocation = false;

  /// Nudge the driver to rest after this many hours of continuous driving.
  static const int breakIntervalHours = 2;
  DateTime? _drivingSince;
  Timer? _fatigueTimer;
  bool _breakDue = false;

  // Getters
  List<Trip> get todaySchedules => _todaySchedules;
  Map<String, dynamic>? get driverUser => _driverUser;
  bool get isAuthenticated => _token != null;
  bool get isRestoringSession => _isRestoringSession;
  bool get isLoggingIn => _isLoggingIn;
  Trip? get currentTrip => _currentTrip;
  Van? get selectedVan => _selectedVan;
  Trip? get selectedSchedule => _selectedSchedule;
  bool get isTracking => _isTracking;
  List<PickupGroup> get pickupGroups => _pickupGroups;
  bool get isLoadingPickupGroups => _isLoadingPickupGroups;
  bool get isLoadingSchedules => _isLoadingSchedules;
  String get statusMessage => _statusMessage;
  double get currentSpeed => _currentSpeed;
  LatLng? get currentLocation => _currentLocation;
  LocationService get locationService => _locationService;

  /// How long the driver has been driving since the trip started or the last
  /// acknowledged rest break.
  Duration get drivingElapsed => _drivingSince == null
      ? Duration.zero
      : DateTime.now().difference(_drivingSince!);

  /// True once continuous driving crosses [breakIntervalHours] — the map shows
  /// a rest prompt until [acknowledgeBreak] is called.
  bool get breakDue => _breakDue;

  /// True when the active schedule has a vehicle, so GPS updates can be
  /// attributed to it and shown to customers. When false, location sharing
  /// is impossible and check-in is the only working feature.
  bool get isLocationShared =>
      (_selectedVan?.id ?? _selectedSchedule?.vehicleId) != null;

  Map<String, String> get _authHeaders => {
    'Accept': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);

    if (_token == null) {
      _isRestoringSession = false;
      notifyListeners();
      return;
    }

    await fetchDriverContext();
    _isRestoringSession = false;
    notifyListeners();
  }

  Future<bool> login({required String email, required String password}) async {
    _isLoggingIn = true;
    _statusMessage = '';
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: const {'Accept': 'application/json'},
        body: {'email': email, 'password': password},
      );
      final result = json.decode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || result['success'] != true) {
        _statusMessage =
            result['message']?.toString() ?? 'เข้าสู่ระบบไม่สำเร็จ';
        return false;
      }

      final data = Map<String, dynamic>.from(result['data'] as Map);
      _token = data['token']?.toString();
      if (_token == null || _token!.isEmpty) {
        _statusMessage = 'ไม่พบข้อมูลยืนยันตัวตน กรุณาลองใหม่';
        return false;
      }
      _driverUser = Map<String, dynamic>.from(data['user'] as Map);

      final roles = (_driverUser?['roles'] as List?)?.map((e) => e.toString());
      final allowed =
          roles?.any((r) => ['staff', 'operator', 'admin'].contains(r)) ??
          false;
      if (!allowed) {
        _token = null;
        _driverUser = null;
        _statusMessage = 'บัญชีนี้ยังไม่ได้รับสิทธิ์คนขับหรือสตาฟ';
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, _token!);
      await fetchDriverContext();
      return true;
    } catch (e) {
      _statusMessage = 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้';
      return false;
    } finally {
      _isLoggingIn = false;
      notifyListeners();
    }
  }

  Future<bool> loginWithDriverPin(String driverPin) async {
    _isLoggingIn = true;
    _statusMessage = '';
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/pin-login'),
        headers: const {'Accept': 'application/json'},
        body: {'driver_pin': driverPin},
      );
      final result = json.decode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || result['success'] != true) {
        _statusMessage = result['message']?.toString() ?? 'ไม่พบรหัสคนขับนี้';
        return false;
      }

      final data = Map<String, dynamic>.from(result['data'] as Map);
      _token = data['token']?.toString();
      _driverUser = Map<String, dynamic>.from(data['user'] as Map);
      _todaySchedules = List<dynamic>.from(
        data['schedules'] ?? [],
      ).map((s) => Trip.fromJson(Map<String, dynamic>.from(s as Map))).toList();
      if (_todaySchedules.length == 1) {
        selectSchedule(_todaySchedules.first);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, _token!);
      return true;
    } catch (e) {
      _statusMessage = 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้';
      return false;
    } finally {
      _isLoggingIn = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      if (_token != null) {
        await http.post(
          Uri.parse('$baseUrl/auth/logout'),
          headers: _authHeaders,
        );
      }
    } catch (_) {
      // Local logout should still work even if the token expired.
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    stopTrip();
    _token = null;
    _driverUser = null;
    _todaySchedules = [];
    _selectedSchedule = null;
    _selectedVan = null;
    _inspectedSchedules.clear();
    notifyListeners();
  }

  Future<void> fetchDriverContext() async {
    if (_token == null) return;
    _isLoadingSchedules = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/driver/me'),
        headers: _authHeaders,
      );
      final result = json.decode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 401) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_tokenKey);
        _token = null;
        _driverUser = null;
        _todaySchedules = [];
        _statusMessage = 'กรุณาเข้าสู่ระบบอีกครั้ง';
        return;
      }
      if (response.statusCode == 200 && result['success'] == true) {
        final data = Map<String, dynamic>.from(result['data'] as Map);
        _driverUser = Map<String, dynamic>.from(data['user'] as Map);
        _todaySchedules = List<dynamic>.from(data['schedules'] ?? [])
            .map((s) => Trip.fromJson(Map<String, dynamic>.from(s as Map)))
            .toList();
        if (_todaySchedules.length == 1) {
          selectSchedule(_todaySchedules.first);
        }
      } else {
        _statusMessage =
            result['message']?.toString() ?? 'โหลดข้อมูลคนขับไม่สำเร็จ';
      }
    } catch (e) {
      _statusMessage = 'ไม่สามารถโหลดข้อมูลคนขับได้';
    } finally {
      _isLoadingSchedules = false;
      notifyListeners();
    }
  }

  /// Report an on-trip incident (accident / injury / traffic). Sends as
  /// multipart when a photo is attached, plain form otherwise. Throws
  /// [IncidentException] with a user-facing message on failure.
  Future<Incident> reportIncident({
    required int scheduleId,
    required String severity,
    required String description,
    String? passengerName,
    double? latitude,
    double? longitude,
    String? photoPath,
  }) async {
    final fields = <String, String>{
      'severity': severity,
      'description': description,
      if (passengerName != null && passengerName.trim().isNotEmpty)
        'passenger_name': passengerName.trim(),
      if (latitude != null) 'latitude': latitude.toString(),
      if (longitude != null) 'longitude': longitude.toString(),
    };

    final uri = Uri.parse('$baseUrl/driver/schedules/$scheduleId/incidents');
    final http.Response response;
    try {
      if (photoPath != null && photoPath.isNotEmpty) {
        final request = http.MultipartRequest('POST', uri)
          ..headers.addAll(_authHeaders)
          ..fields.addAll(fields)
          ..files.add(await http.MultipartFile.fromPath('photo', photoPath));
        response = await http.Response.fromStream(await request.send());
      } else {
        response = await http.post(uri, headers: _authHeaders, body: fields);
      }
    } catch (_) {
      throw const IncidentException('ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้');
    }

    Map<String, dynamic> result;
    try {
      result = json.decode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const IncidentException('ข้อมูลจากเซิร์ฟเวอร์ไม่ถูกต้อง');
    }

    if (response.statusCode != 200 || result['success'] != true) {
      throw IncidentException(
        result['message']?.toString() ?? 'แจ้งเหตุไม่สำเร็จ',
      );
    }

    return Incident.fromJson(Map<String, dynamic>.from(result['data'] as Map));
  }

  /// Incidents logged for a schedule (most recent first).
  Future<List<Incident>> fetchIncidents(int scheduleId) async {
    final http.Response response;
    try {
      response = await http.get(
        Uri.parse('$baseUrl/driver/schedules/$scheduleId/incidents'),
        headers: _authHeaders,
      );
    } catch (_) {
      throw const IncidentException('ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้');
    }

    Map<String, dynamic> result;
    try {
      result = json.decode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const IncidentException('ข้อมูลจากเซิร์ฟเวอร์ไม่ถูกต้อง');
    }

    if (response.statusCode != 200 || result['success'] != true) {
      throw IncidentException(
        result['message']?.toString() ?? 'โหลดรายการแจ้งเหตุไม่สำเร็จ',
      );
    }

    return List<dynamic>.from(result['data'] ?? [])
        .map((e) => Incident.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Mark an incident resolved. Returns the updated incident.
  Future<Incident> resolveIncident(int incidentId) async {
    final http.Response response;
    try {
      response = await http.post(
        Uri.parse('$baseUrl/driver/incidents/$incidentId/resolve'),
        headers: _authHeaders,
      );
    } catch (_) {
      throw const IncidentException('ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้');
    }

    Map<String, dynamic> result;
    try {
      result = json.decode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const IncidentException('ข้อมูลจากเซิร์ฟเวอร์ไม่ถูกต้อง');
    }

    if (response.statusCode != 200 || result['success'] != true) {
      throw IncidentException(
        result['message']?.toString() ?? 'ปิดเคสไม่สำเร็จ',
      );
    }

    return Incident.fromJson(Map<String, dynamic>.from(result['data'] as Map));
  }

  /// Load pickup groups (passengers grouped by pickup point, with coords) so
  /// the map can plot tappable markers. Best-effort: keeps the previous set on
  /// failure so a transient error never blanks the map.
  Future<void> loadPickupGroups(int scheduleId) async {
    _isLoadingPickupGroups = true;
    notifyListeners();
    try {
      final manifest = await fetchManifest(scheduleId);
      _pickupGroups = manifest.pickupGroups;
    } on ManifestException {
      // Keep whatever we already have.
    } finally {
      _isLoadingPickupGroups = false;
      notifyListeners();
    }
  }

  /// Fetch the pre-trip inspection template + latest submission for a schedule.
  Future<InspectionState> fetchInspection(int scheduleId) async {
    final http.Response response;
    try {
      response = await http.get(
        Uri.parse('$baseUrl/driver/schedules/$scheduleId/inspection'),
        headers: _authHeaders,
      );
    } catch (_) {
      throw const InspectionException('ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้');
    }

    Map<String, dynamic> result;
    try {
      result = json.decode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const InspectionException('ข้อมูลจากเซิร์ฟเวอร์ไม่ถูกต้อง');
    }

    if (response.statusCode != 200 || result['success'] != true) {
      throw InspectionException(
        result['message']?.toString() ?? 'โหลดรายการตรวจสภาพรถไม่สำเร็จ',
      );
    }

    return InspectionState.fromJson(
      Map<String, dynamic>.from(result['data'] as Map),
    );
  }

  /// Whether this schedule's vehicle has been inspected (gates trip start).
  bool isInspected(int scheduleId) => _inspectedSchedules.contains(scheduleId);

  void markInspected(int scheduleId) {
    _inspectedSchedules.add(scheduleId);
    notifyListeners();
  }

  /// Best-effort check of whether the server already has an inspection for this
  /// schedule; marks it locally so the start gate can pass. Never throws.
  Future<bool> hasBackendInspection(int scheduleId) async {
    try {
      final state = await fetchInspection(scheduleId);
      if (state.latest != null) {
        _inspectedSchedules.add(scheduleId);
        return true;
      }
    } catch (_) {
      // Offline / error: treat as not-yet-inspected so the checklist opens.
    }
    return false;
  }

  /// Submit a pre-trip inspection. [items] maps each item key to its ok flag.
  Future<Inspection> submitInspection({
    required int scheduleId,
    required Map<String, bool> items,
    String? note,
    double? latitude,
    double? longitude,
  }) async {
    final body = <String, dynamic>{
      'note': note,
      'latitude': ?latitude,
      'longitude': ?longitude,
      'items': [
        for (final entry in items.entries) {'key': entry.key, 'ok': entry.value},
      ],
    };

    final http.Response response;
    try {
      response = await http.post(
        Uri.parse('$baseUrl/driver/schedules/$scheduleId/inspection'),
        headers: {..._authHeaders, 'Content-Type': 'application/json'},
        body: json.encode(body),
      );
    } catch (_) {
      throw const InspectionException('ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้');
    }

    Map<String, dynamic> result;
    try {
      result = json.decode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const InspectionException('ข้อมูลจากเซิร์ฟเวอร์ไม่ถูกต้อง');
    }

    if (response.statusCode != 200 || result['success'] != true) {
      throw InspectionException(
        result['message']?.toString() ?? 'บันทึกผลตรวจไม่สำเร็จ',
      );
    }

    _inspectedSchedules.add(scheduleId);
    return Inspection.fromJson(Map<String, dynamic>.from(result['data'] as Map));
  }

  /// Fetch the passenger manifest for a schedule. Throws [ManifestException]
  /// with a user-facing message when the request fails.
  Future<TripManifest> fetchManifest(int scheduleId) async {
    final http.Response response;
    try {
      response = await http.get(
        Uri.parse('$baseUrl/driver/schedules/$scheduleId/manifest'),
        headers: _authHeaders,
      );
    } catch (_) {
      throw const ManifestException('ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้');
    }

    Map<String, dynamic> result;
    try {
      result = json.decode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const ManifestException('ข้อมูลจากเซิร์ฟเวอร์ไม่ถูกต้อง');
    }

    if (response.statusCode != 200 || result['success'] != true) {
      throw ManifestException(
        result['message']?.toString() ?? 'โหลดรายชื่อผู้โดยสารไม่สำเร็จ',
      );
    }

    return TripManifest.fromJson(
      Map<String, dynamic>.from(result['data'] as Map),
    );
  }

  /// Select a schedule for the trip
  void selectSchedule(Trip schedule) {
    _selectedSchedule = schedule;
    if (schedule.vehicleId != null) {
      _selectedVan = Van(
        id: schedule.vehicleId!,
        name: schedule.vehicleName ?? 'รถประจำทริป',
        type: '',
        capacity: schedule.totalSeats,
        licensePlate: schedule.licensePlate ?? '',
        driverName: schedule.driverName,
        driverPhone: schedule.driverPhone,
      );
    }
    notifyListeners();
  }

  /// Start a trip session
  Future<bool> startTrip() async {
    if (_selectedSchedule == null) {
      _statusMessage = 'กรุณาเลือกรอบเดินทาง';
      notifyListeners();
      return false;
    }

    final hasPermission = await _locationService.checkPermissions();
    if (!hasPermission) {
      _statusMessage = 'กรุณาอนุญาตการเข้าถึงตำแหน่ง';
      notifyListeners();
      return false;
    }

    final currentPos = await _locationService.getCurrentPosition();
    if (currentPos == null) {
      _statusMessage = 'ไม่สามารถระบุตำแหน่งของคุณได้';
      notifyListeners();
      return false;
    }

    _currentLocation = currentPos;
    _currentTrip = _selectedSchedule;
    _currentTrip!.currentLocation = currentPos;
    _currentTrip!.currentSpeed = 0;

    _isTracking = true;
    _statusMessage = 'กำลังแบ่งปันตำแหน่งของคุณ...';
    _startFatigueClock();
    _locationService.startTracking();

    _locationSub = _locationService.locationStream.listen((LatLng location) {
      _currentLocation = location;
      if (_currentTrip != null) {
        _currentTrip!.currentLocation = location;
        _reportCurrentLocation();
        notifyListeners();
      }
    });

    _speedSub = _locationService.speedStream.listen((double speed) {
      _currentSpeed = speed;
      if (_currentTrip != null) {
        _currentTrip!.currentSpeed = speed;
        notifyListeners();
      }
    });

    await _reportCurrentLocation();
    _locationReportTimer?.cancel();
    _locationReportTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _reportCurrentLocation();
    });

    // Tell the backend to push a "departed" alert to passengers. Non-blocking:
    // tracking works regardless of whether this notification is delivered.
    _notifyDeparted(_currentTrip!.id);

    notifyListeners();
    return true;
  }

  /// Ask the backend to send the "trip departed" push to passengers. The
  /// backend de-duplicates so repeated calls in a day send only once.
  Future<void> _notifyDeparted(int scheduleId) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/driver/schedules/$scheduleId/depart'),
        headers: _authHeaders,
      );
    } catch (_) {
      // Non-critical: ignore so a failed notification never blocks the trip.
    }
  }

  /// Report location update to backend API
  Future<void> _reportCurrentLocation() async {
    final location = _currentLocation;
    if (location == null || _currentTrip == null) return;
    if (_isReportingLocation) return;

    _isReportingLocation = true;
    try {
      await _reportLocation(location, _currentSpeed);
    } finally {
      _isReportingLocation = false;
    }
  }

  Future<void> _reportLocation(LatLng location, double speed) async {
    final vehicleId = _selectedVan?.id ?? _selectedSchedule?.vehicleId;
    if (vehicleId == null) return;

    final heading = _locationService.lastKnownHeading;
    final hasHeading = heading.isFinite && heading >= 0 && heading <= 360;

    try {
      await http.post(
        Uri.parse('$baseUrl/tracking/update'),
        headers: _authHeaders,
        body: {
          'vehicle_id': vehicleId.toString(),
          'latitude': location.latitude.toString(),
          'longitude': location.longitude.toString(),
          'speed': speed.toString(),
          if (hasHeading) 'heading': heading.toString(),
          'recorded_at': DateTime.now().toIso8601String(),
        },
      );
    } catch (_) {
      // Fail silently for background updates, maybe log in production
    }
  }

  /// Start counting continuous driving time and schedule rest-break nudges.
  void _startFatigueClock() {
    _drivingSince = DateTime.now();
    _breakDue = false;
    _fatigueTimer?.cancel();
    _fatigueTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_drivingSince == null || _breakDue) return;
      if (DateTime.now().difference(_drivingSince!) >=
          const Duration(hours: breakIntervalHours)) {
        _breakDue = true;
        notifyListeners();
      }
    });
  }

  /// Driver acknowledged a rest break — restart the driving clock.
  void acknowledgeBreak() {
    _drivingSince = DateTime.now();
    _breakDue = false;
    notifyListeners();
  }

  /// Stop the trip session
  void stopTrip() {
    _locationSub?.cancel();
    _speedSub?.cancel();
    _locationReportTimer?.cancel();
    _locationReportTimer = null;
    _fatigueTimer?.cancel();
    _fatigueTimer = null;
    _drivingSince = null;
    _breakDue = false;
    _locationService.stopTracking();
    _isTracking = false;

    if (_currentTrip != null) {
      _currentTrip!.isActive = false;
    }

    _statusMessage = 'จบการเดินทางแล้ว';
    _currentTrip = null;
    _pickupGroups = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _speedSub?.cancel();
    _locationReportTimer?.cancel();
    _fatigueTimer?.cancel();
    _locationService.dispose();
    super.dispose();
  }
}
