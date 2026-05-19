import 'package:latlong2/latlong.dart';

class PickupPoint {
  final int id;
  final String location;
  final String? regionLabel;
  final LatLng? coords;
  final String? notes;

  const PickupPoint({
    required this.id,
    required this.location,
    this.regionLabel,
    this.coords,
    this.notes,
  });

  factory PickupPoint.fromJson(Map<String, dynamic> json) {
    final lat = json['latitude'];
    final lng = json['longitude'];
    return PickupPoint(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      location: json['location']?.toString() ?? '',
      regionLabel: json['region_label']?.toString(),
      coords: (lat != null && lng != null)
          ? LatLng((lat as num).toDouble(), (lng as num).toDouble())
          : null,
      notes: json['notes']?.toString(),
    );
  }
}

class Trip {
  final int id;
  final String title;
  final String location;
  final String departurePoint;
  final LatLng destination;
  final String departureDate;
  final int totalSeats;
  final int bookedSeats;
  final int availableSeats;
  final int confirmedBookingsCount;
  final int checkedInBookingsCount;
  final String status;
  final int? vehicleId;
  final String? vehicleName;
  final String? licensePlate;
  final String? driverName;
  final String? driverPhone;
  final List<PickupPoint> pickupPoints;

  // Runtime tracking data
  LatLng? currentLocation;
  double? currentSpeed; // km/h
  bool isActive;

  Trip({
    required this.id,
    required this.title,
    required this.location,
    required this.departurePoint,
    required this.destination,
    required this.departureDate,
    required this.totalSeats,
    required this.bookedSeats,
    required this.availableSeats,
    this.confirmedBookingsCount = 0,
    this.checkedInBookingsCount = 0,
    required this.status,
    this.vehicleId,
    this.vehicleName,
    this.licensePlate,
    this.driverName,
    this.driverPhone,
    this.pickupPoints = const [],
    this.currentLocation,
    this.currentSpeed,
    this.isActive = true,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    final vehicle = json['vehicle'] is Map
        ? Map<String, dynamic>.from(json['vehicle'] as Map)
        : <String, dynamic>{};
    return Trip(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      title: json['trip_title'] ?? '',
      location: json['trip_location'] ?? '',
      departurePoint: json['departure_point'] ?? '',
      destination: LatLng(
        json['destination_lat'] != null
            ? (json['destination_lat'] as num).toDouble()
            : 0.0,
        json['destination_lng'] != null
            ? (json['destination_lng'] as num).toDouble()
            : 0.0,
      ),
      departureDate: json['departure_date'] ?? '',
      totalSeats: json['total_seats'] ?? 0,
      bookedSeats: json['booked_seats'] ?? 0,
      availableSeats: json['available_seats'] ?? 0,
      confirmedBookingsCount: json['confirmed_bookings_count'] ?? 0,
      checkedInBookingsCount: json['checked_in_bookings_count'] ?? 0,
      status: json['status'] ?? '',
      vehicleId: vehicle['id'] is int
          ? vehicle['id'] as int
          : int.tryParse(vehicle['id']?.toString() ?? ''),
      vehicleName: vehicle['name']?.toString(),
      licensePlate: vehicle['license_plate']?.toString(),
      driverName: vehicle['driver_name']?.toString(),
      driverPhone: vehicle['driver_phone']?.toString(),
      pickupPoints: (json['pickup_points'] as List?)
              ?.map(
                (p) => PickupPoint.fromJson(Map<String, dynamic>.from(p as Map)),
              )
              .toList() ??
          const [],
    );
  }

  /// Calculate ETA based on distance and speed
  Duration? getETA() {
    if (currentLocation == null) {
      return null;
    }
    // destination not set (0,0 fallback means no GPS coords in DB)
    if (destination.latitude == 0.0 && destination.longitude == 0.0) {
      return null;
    }

    const distance = Distance();
    final km = distance.as(LengthUnit.Kilometer, currentLocation!, destination);

    if (km <= 0.05) return Duration.zero; // Already arrived (< 50m)

    // Use actual speed if meaningful, otherwise default to 40 km/h estimate
    final speed = (currentSpeed == null || currentSpeed! < 10)
        ? 40.0
        : currentSpeed!;
    final hours = km / speed;
    return Duration(minutes: (hours * 60).ceil());
  }

  /// Get remaining distance in km
  double? getRemainingDistance() {
    if (currentLocation == null) return null;

    const distance = Distance();
    return distance.as(LengthUnit.Kilometer, currentLocation!, destination);
  }

  String getETAFormatted() {
    if (currentLocation == null) return 'กำลังระบุตำแหน่ง...';
    if (destination.latitude == 0.0 && destination.longitude == 0.0) {
      return 'ไม่มีข้อมูลจุดหมาย';
    }
    final eta = getETA();
    if (eta == null) return 'กำลังคำนวณ...';
    if (eta == Duration.zero) return 'ถึงแล้ว!';

    final hours = eta.inHours;
    final minutes = eta.inMinutes.remainder(60);
    final isEstimate = currentSpeed == null || currentSpeed! < 10;
    final prefix = isEstimate ? '~' : '';

    if (hours > 0) {
      return '$prefix$hours ชม. $minutes นาที';
    }
    return '$prefix$minutes นาที';
  }
}
