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

  const ManifestPassenger({required this.name, this.nickname, this.phone});

  factory ManifestPassenger.fromJson(Map<String, dynamic> json) {
    return ManifestPassenger(
      name: json['name']?.toString() ?? '',
      nickname: json['nickname']?.toString(),
      phone: json['phone']?.toString(),
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

class TripManifest {
  final int bookingCount;
  final int checkedInCount;
  final int passengerCount;
  final List<ManifestEntry> entries;

  const TripManifest({
    required this.bookingCount,
    required this.checkedInCount,
    required this.passengerCount,
    required this.entries,
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
    );
  }
}
