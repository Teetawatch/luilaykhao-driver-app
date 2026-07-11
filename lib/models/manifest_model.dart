class ManifestException implements Exception {
  final String message;
  const ManifestException(this.message);

  @override
  String toString() => message;
}

class ManifestPassenger {
  final String name;
  final String? nickname;
  final String? phone;
  final String? seatLabel;

  const ManifestPassenger({
    required this.name,
    this.nickname,
    this.phone,
    this.seatLabel,
  });

  factory ManifestPassenger.fromJson(Map<String, dynamic> json) {
    final seat = json['seat_label']?.toString().trim();
    return ManifestPassenger(
      name: json['name']?.toString() ?? '',
      nickname: json['nickname']?.toString(),
      phone: json['phone']?.toString(),
      seatLabel: (seat == null || seat.isEmpty) ? null : seat,
    );
  }
}

class ManifestEntry {
  final String bookingRef;
  final String status;
  final bool checkedIn;
  final DateTime? checkedInAt;
  final String? contactName;
  final String? contactPhone;
  final String? contactAvatarUrl;
  final bool isGroup;
  final String? groupName;
  final String? pickupRegion;
  final String? pickupLocation;
  final String? pickupRegionLabel;
  final String? pickupMapUrl;
  final String? pickupNotes;
  final int passengerCount;
  final List<ManifestPassenger> passengers;

  const ManifestEntry({
    required this.bookingRef,
    required this.status,
    required this.checkedIn,
    this.checkedInAt,
    this.contactName,
    this.contactPhone,
    this.contactAvatarUrl,
    this.isGroup = false,
    this.groupName,
    this.pickupRegion,
    this.pickupLocation,
    this.pickupRegionLabel,
    this.pickupMapUrl,
    this.pickupNotes,
    this.passengerCount = 0,
    this.passengers = const [],
  });

  /// Best display label for the pickup point, falling back to the region.
  String? get pickupLabel {
    final location = pickupLocation?.trim() ?? '';
    if (location.isNotEmpty) return location;
    final label = pickupRegionLabel?.trim() ?? '';
    if (label.isNotEmpty) return label;
    final region = pickupRegion?.trim() ?? '';
    return region.isEmpty ? null : region;
  }

  factory ManifestEntry.fromJson(Map<String, dynamic> json) {
    return ManifestEntry(
      bookingRef: json['booking_ref']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      checkedIn: json['checked_in'] == true,
      checkedInAt: json['checked_in_at'] != null
          ? DateTime.tryParse(json['checked_in_at'].toString())
          : null,
      contactName: json['contact_name']?.toString(),
      contactPhone: json['contact_phone']?.toString(),
      contactAvatarUrl: json['contact_avatar_url']?.toString(),
      isGroup: json['is_group'] == true,
      groupName: json['group_name']?.toString(),
      pickupRegion: json['pickup_region']?.toString(),
      pickupLocation: json['pickup_location']?.toString(),
      pickupRegionLabel: json['pickup_region_label']?.toString(),
      pickupMapUrl: json['pickup_map_url']?.toString(),
      pickupNotes: json['pickup_notes']?.toString(),
      passengerCount: json['passenger_count'] is int
          ? json['passenger_count'] as int
          : int.tryParse(json['passenger_count']?.toString() ?? '') ?? 0,
      passengers: (json['passengers'] as List?)
              ?.map(
                (p) => ManifestPassenger.fromJson(
                  Map<String, dynamic>.from(p as Map),
                ),
              )
              .toList() ??
          const [],
    );
  }
}

/// A passenger as grouped under a pickup point (map tap sheet).
class PickupGroupPassenger {
  final String fullName;
  final String? nickname;
  final String? phone;
  final String? seatLabel;
  final bool checkedIn;
  final String? avatarUrl;

  const PickupGroupPassenger({
    required this.fullName,
    this.nickname,
    this.phone,
    this.seatLabel,
    this.checkedIn = false,
    this.avatarUrl,
  });

  factory PickupGroupPassenger.fromJson(Map<String, dynamic> json) {
    final seat = json['seat_label']?.toString().trim();
    return PickupGroupPassenger(
      fullName: json['full_name']?.toString() ?? json['name']?.toString() ?? '',
      nickname: json['nickname']?.toString(),
      phone: json['phone']?.toString(),
      seatLabel: (seat == null || seat.isEmpty) ? null : seat,
      checkedIn: json['checked_in'] == true,
      avatarUrl: json['avatar_url']?.toString(),
    );
  }
}

/// All passengers to pick up at one point, with coordinates so the driver map
/// can plot a tappable marker.
class PickupGroup {
  final int? id;
  final String label;
  final String? regionLabel;
  final double? lat;
  final double? lng;
  final String? mapUrl;
  final String? notes;
  final bool isCustom;
  final bool completed;
  final int passengerCount;
  final int checkedInCount;
  final List<PickupGroupPassenger> passengers;

  const PickupGroup({
    this.id,
    required this.label,
    this.regionLabel,
    this.lat,
    this.lng,
    this.mapUrl,
    this.notes,
    this.isCustom = false,
    this.completed = false,
    this.passengerCount = 0,
    this.checkedInCount = 0,
    this.passengers = const [],
  });

  bool get hasCoords => lat != null && lng != null;

  factory PickupGroup.fromJson(Map<String, dynamic> json) {
    double? asDouble(dynamic v) => v == null
        ? null
        : (v is num ? v.toDouble() : double.tryParse(v.toString()));
    int asInt(dynamic v) =>
        v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;

    return PickupGroup(
      id: json['id'] == null ? null : asInt(json['id']),
      label: json['label']?.toString() ?? 'จุดรับ',
      regionLabel: json['region_label']?.toString(),
      lat: asDouble(json['lat']),
      lng: asDouble(json['lng']),
      mapUrl: json['map_url']?.toString(),
      notes: json['notes']?.toString(),
      isCustom: json['is_custom'] == true,
      completed: json['completed_at'] != null,
      passengerCount: asInt(json['passenger_count']),
      checkedInCount: asInt(json['checked_in_count']),
      passengers: (json['passengers'] as List?)
              ?.map(
                (p) => PickupGroupPassenger.fromJson(
                  Map<String, dynamic>.from(p as Map),
                ),
              )
              .toList() ??
          const [],
    );
  }
}

/// Who sits in a seat — overlaid onto the vehicle layout.
class SeatOccupant {
  final String name;
  final String? nickname;
  final String? bookingRef;
  final bool checkedIn;

  const SeatOccupant({
    required this.name,
    this.nickname,
    this.bookingRef,
    this.checkedIn = false,
  });

  /// Short label for the seat tile — nickname if present, else first name word.
  String get shortLabel {
    final nick = nickname?.trim() ?? '';
    if (nick.isNotEmpty) return nick;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  factory SeatOccupant.fromJson(Map<String, dynamic> json) {
    return SeatOccupant(
      name: json['name']?.toString() ?? '',
      nickname: json['nickname']?.toString(),
      bookingRef: json['booking_ref']?.toString(),
      checkedIn: json['checked_in'] == true,
    );
  }
}

class Seat {
  final String id;
  final String label;
  final SeatOccupant? occupant;

  const Seat({required this.id, required this.label, this.occupant});

  bool get occupied => occupant != null;

  factory Seat.fromJson(Map<String, dynamic> json) {
    final occ = json['occupant'];
    return Seat(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? json['id']?.toString() ?? '',
      occupant: occ is Map
          ? SeatOccupant.fromJson(Map<String, dynamic>.from(occ))
          : null,
    );
  }
}

/// The vehicle seat layout with occupants overlaid. Null for schedules without
/// seat assignments (charters / join trips).
class SeatMap {
  final int rows;
  final List<String> columns;
  final List<Seat> seats;
  final String? frontSeat;
  final List<String> lastRowCenter;
  final String frontLabel;
  final String rearLabel;
  final bool showDriver;
  final int occupied;
  final int total;

  const SeatMap({
    required this.rows,
    required this.columns,
    required this.seats,
    this.frontSeat,
    this.lastRowCenter = const [],
    this.frontLabel = 'หน้ารถ',
    this.rearLabel = 'ท้ายรถ',
    this.showDriver = true,
    this.occupied = 0,
    this.total = 0,
  });

  Seat? seatById(String id) {
    for (final seat in seats) {
      if (seat.id == id) return seat;
    }
    return null;
  }

  factory SeatMap.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) =>
        v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
    List<String> asStrList(dynamic v) => (v as List?)
            ?.map((e) => e?.toString() ?? '')
            .toList() ??
        const [];

    final front = json['front_seat']?.toString().trim();
    return SeatMap(
      rows: asInt(json['rows']),
      columns: asStrList(json['columns']),
      seats: (json['seats'] as List?)
              ?.map((s) => Seat.fromJson(Map<String, dynamic>.from(s as Map)))
              .toList() ??
          const [],
      frontSeat: (front == null || front.isEmpty) ? null : front,
      lastRowCenter: asStrList(json['last_row_center']),
      frontLabel: json['front_label']?.toString() ?? 'หน้ารถ',
      rearLabel: json['rear_label']?.toString() ?? 'ท้ายรถ',
      showDriver: json['show_driver'] != false,
      occupied: asInt(json['occupied']),
      total: asInt(json['total']),
    );
  }
}

class TripManifest {
  final int bookingCount;
  final int checkedInCount;
  final int passengerCount;
  final List<ManifestEntry> entries;
  final List<PickupGroup> pickupGroups;
  final SeatMap? seatMap;

  const TripManifest({
    required this.bookingCount,
    required this.checkedInCount,
    required this.passengerCount,
    required this.entries,
    this.pickupGroups = const [],
    this.seatMap,
  });

  factory TripManifest.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] is Map
        ? Map<String, dynamic>.from(json['summary'] as Map)
        : const <String, dynamic>{};
    int asInt(dynamic value) =>
        value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;

    return TripManifest(
      bookingCount: asInt(summary['bookings']),
      checkedInCount: asInt(summary['checked_in']),
      passengerCount: asInt(summary['passengers']),
      entries: (json['bookings'] as List?)
              ?.map(
                (b) =>
                    ManifestEntry.fromJson(Map<String, dynamic>.from(b as Map)),
              )
              .toList() ??
          const [],
      pickupGroups: (json['pickup_groups'] as List?)
              ?.map(
                (g) =>
                    PickupGroup.fromJson(Map<String, dynamic>.from(g as Map)),
              )
              .toList() ??
          const [],
      seatMap: json['seat_map'] is Map
          ? SeatMap.fromJson(Map<String, dynamic>.from(json['seat_map'] as Map))
          : null,
    );
  }
}
