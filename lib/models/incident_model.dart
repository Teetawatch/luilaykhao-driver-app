class IncidentException implements Exception {
  final String message;
  const IncidentException(this.message);

  @override
  String toString() => message;
}

/// An on-trip incident (accident / injury / traffic) logged by the driver or
/// staff for a schedule.
class Incident {
  final int id;
  final int scheduleId;
  final String? passengerName;
  final String severity;
  final String severityLabel;
  final String description;
  final double? latitude;
  final double? longitude;
  final String? photoUrl;
  final String status;
  final String? reportedByName;
  final String? resolvedByName;
  final DateTime? resolvedAt;
  final DateTime? createdAt;

  const Incident({
    required this.id,
    required this.scheduleId,
    this.passengerName,
    required this.severity,
    required this.severityLabel,
    required this.description,
    this.latitude,
    this.longitude,
    this.photoUrl,
    required this.status,
    this.reportedByName,
    this.resolvedByName,
    this.resolvedAt,
    this.createdAt,
  });

  bool get isResolved => status == 'resolved';
  bool get hasLocation => latitude != null && longitude != null;

  String? get mapUrl => hasLocation
      ? 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude'
      : null;

  factory Incident.fromJson(Map<String, dynamic> json) {
    double? asDouble(dynamic v) =>
        v == null ? null : (v is num ? v.toDouble() : double.tryParse(v.toString()));

    return Incident(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      scheduleId: json['schedule_id'] is int
          ? json['schedule_id'] as int
          : int.tryParse(json['schedule_id']?.toString() ?? '') ?? 0,
      passengerName: json['passenger_name']?.toString(),
      severity: json['severity']?.toString() ?? 'moderate',
      severityLabel: json['severity_label']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      latitude: asDouble(json['latitude']),
      longitude: asDouble(json['longitude']),
      photoUrl: json['photo_url']?.toString(),
      status: json['status']?.toString() ?? 'open',
      reportedByName: json['reported_by_name']?.toString(),
      resolvedByName: json['resolved_by_name']?.toString(),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.tryParse(json['resolved_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}
