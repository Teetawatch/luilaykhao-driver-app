import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip_model.dart';
import '../models/van_model.dart';
import '../services/location_service.dart';

class TripProvider extends ChangeNotifier {
  // Production
  static const String baseUrl = 'https://luilaykhao.com/api/v1';
  // Android Emulator (local dev): 'http://10.0.2.2:8000/api/v1'

  final LocationService _locationService = LocationService();
  static const String _tokenKey = 'driver_auth_token';

  List<Van> _availableVans = [];
  List<Trip> _todaySchedules = [];

  Map<String, dynamic>? _driverUser;
  String? _token;
  Trip? _currentTrip;
  Van? _selectedVan;
  Trip? _selectedSchedule;

  bool _isRestoringSession = true;
  bool _isLoggingIn = false;
  bool _isTracking = false;
  bool _isLoadingVans = false;
  bool _isLoadingSchedules = false;
  bool _isCheckingIn = false;
  String _statusMessage = '';

  double _currentSpeed = 0;
  LatLng? _currentLocation;
  StreamSubscription<LatLng>? _locationSub;
  StreamSubscription<double>? _speedSub;
  Timer? _locationReportTimer;
  bool _isReportingLocation = false;

  // Getters
  List<Van> get availableVans => _availableVans;
  List<Trip> get todaySchedules => _todaySchedules;
  Map<String, dynamic>? get driverUser => _driverUser;
  bool get isAuthenticated => _token != null;
  bool get isRestoringSession => _isRestoringSession;
  bool get isLoggingIn => _isLoggingIn;
  Trip? get currentTrip => _currentTrip;
  Van? get selectedVan => _selectedVan;
  Trip? get selectedSchedule => _selectedSchedule;
  bool get isTracking => _isTracking;
  bool get isLoadingVans => _isLoadingVans;
  bool get isLoadingSchedules => _isLoadingSchedules;
  bool get isCheckingIn => _isCheckingIn;
  String get statusMessage => _statusMessage;
  double get currentSpeed => _currentSpeed;
  LatLng? get currentLocation => _currentLocation;
  LocationService get locationService => _locationService;

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

  Future<CheckInResult> checkInQr(String rawCode) async {
    if (_selectedSchedule == null) {
      return CheckInResult.failure('กรุณาเลือกรอบเดินทางก่อนสแกน');
    }

    _isCheckingIn = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/driver/check-in'),
        headers: {..._authHeaders, 'Content-Type': 'application/json'},
        body: json.encode({
          'qr_code': rawCode,
          'schedule_id': _selectedSchedule!.id,
        }),
      );
      final result = json.decode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          result['success'] == true) {
        await fetchDriverContext();
        return CheckInResult.success(
          result['message']?.toString() ?? 'เช็กอินสำเร็จ',
          Map<String, dynamic>.from(result['data'] as Map),
        );
      }

      return CheckInResult.failure(
        result['message']?.toString() ?? 'เช็กอินไม่สำเร็จ',
      );
    } catch (e) {
      return CheckInResult.failure('ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้');
    } finally {
      _isCheckingIn = false;
      notifyListeners();
    }
  }

  /// Fetch all vehicles from backend
  Future<void> fetchVans() async {
    _isLoadingVans = true;
    _statusMessage = 'กำลังโหลดข้อมูลรถ...';
    notifyListeners();

    try {
      final response = await http.get(Uri.parse('$baseUrl/vehicles'));
      if (response.statusCode == 200) {
        final Map<String, dynamic> result = json.decode(response.body);
        if (result['success'] == true) {
          final List<dynamic> data = result['data'];
          _availableVans = data.map((v) => Van.fromJson(v)).toList();
        }
      } else {
        _statusMessage = 'เกิดข้อผิดพลาดในการโหลดข้อมูลรถ';
      }
    } catch (e) {
      _statusMessage = 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้';
    } finally {
      _isLoadingVans = false;
      notifyListeners();
    }
  }

  /// Select a van and fetch today's schedules
  Future<void> selectVan(Van van) async {
    _selectedVan = van;
    _selectedSchedule = null;
    _todaySchedules = [];
    _isLoadingSchedules = true;
    notifyListeners();

    try {
      final url = '$baseUrl/vehicles/${van.id}/schedules/today';
      debugPrint('[TripProvider] GET $url');
      final response = await http.get(Uri.parse(url));
      debugPrint('[TripProvider] Status: ${response.statusCode}');
      debugPrint('[TripProvider] Body: ${response.body}');
      if (response.statusCode == 200) {
        final Map<String, dynamic> result = json.decode(response.body);
        if (result['success'] == true) {
          final List<dynamic> data = result['data'];
          debugPrint('[TripProvider] Schedules count: ${data.length}');
          _todaySchedules = data.map((s) => Trip.fromJson(s)).toList();
        } else {
          debugPrint(
            '[TripProvider] success=false, message=${result['message']}',
          );
        }
      } else {
        debugPrint('[TripProvider] Non-200 response: ${response.body}');
        _statusMessage = 'เกิดข้อผิดพลาด: ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('[TripProvider] Exception: $e');
      _statusMessage = 'ไม่สามารถโหลดรอบเดินทางได้: $e';
    } finally {
      _isLoadingSchedules = false;
      notifyListeners();
    }
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

    notifyListeners();
    return true;
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

    try {
      await http.post(
        Uri.parse('$baseUrl/tracking/update'),
        body: {
          'vehicle_id': vehicleId.toString(),
          'latitude': location.latitude.toString(),
          'longitude': location.longitude.toString(),
          'speed': speed.toString(),
          'recorded_at': DateTime.now().toIso8601String(),
        },
      );
    } catch (_) {
      // Fail silently for background updates, maybe log in production
    }
  }

  /// Stop the trip session
  void stopTrip() {
    _locationSub?.cancel();
    _speedSub?.cancel();
    _locationReportTimer?.cancel();
    _locationReportTimer = null;
    _locationService.stopTracking();
    _isTracking = false;

    if (_currentTrip != null) {
      _currentTrip!.isActive = false;
    }

    _statusMessage = 'จบการเดินทางแล้ว';
    _currentTrip = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _speedSub?.cancel();
    _locationReportTimer?.cancel();
    _locationService.dispose();
    super.dispose();
  }
}

class CheckInResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? booking;

  const CheckInResult({
    required this.success,
    required this.message,
    this.booking,
  });

  factory CheckInResult.success(String message, Map<String, dynamic> booking) {
    return CheckInResult(success: true, message: message, booking: booking);
  }

  factory CheckInResult.failure(String message) {
    return CheckInResult(success: false, message: message);
  }
}
