class InspectionException implements Exception {
  final String message;
  const InspectionException(this.message);

  @override
  String toString() => message;
}

/// One checklist item as defined by the server (template) or recorded on a
/// submitted inspection (with its ok flag).
class InspectionItem {
  final String key;
  final String label;
  final bool critical;
  final bool ok;

  const InspectionItem({
    required this.key,
    required this.label,
    this.critical = false,
    this.ok = false,
  });

  InspectionItem copyWith({bool? ok}) => InspectionItem(
    key: key,
    label: label,
    critical: critical,
    ok: ok ?? this.ok,
  );

  factory InspectionItem.fromJson(Map<String, dynamic> json) {
    return InspectionItem(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      critical: json['critical'] == true,
      ok: json['ok'] == true,
    );
  }
}

/// A recorded pre-trip inspection for a schedule.
class Inspection {
  final int id;
  final int scheduleId;
  final List<InspectionItem> items;
  final bool passed;
  final bool criticalFailed;
  final String? note;
  final String? inspectedByName;
  final DateTime? createdAt;

  const Inspection({
    required this.id,
    required this.scheduleId,
    required this.items,
    required this.passed,
    required this.criticalFailed,
    this.note,
    this.inspectedByName,
    this.createdAt,
  });

  factory Inspection.fromJson(Map<String, dynamic> json) {
    return Inspection(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      scheduleId: json['schedule_id'] is int
          ? json['schedule_id'] as int
          : int.tryParse(json['schedule_id']?.toString() ?? '') ?? 0,
      items: (json['items'] as List?)
              ?.map(
                (e) =>
                    InspectionItem.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList() ??
          const [],
      passed: json['passed'] == true,
      criticalFailed: json['critical_failed'] == true,
      note: json['note']?.toString(),
      inspectedByName: json['inspected_by_name']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}

/// The checklist template plus this schedule's latest submission (null if the
/// vehicle hasn't been inspected yet).
class InspectionState {
  final List<InspectionItem> template;
  final Inspection? latest;

  const InspectionState({required this.template, this.latest});

  bool get inspected => latest != null;

  factory InspectionState.fromJson(Map<String, dynamic> json) {
    return InspectionState(
      template: (json['template'] as List?)
              ?.map(
                (e) =>
                    InspectionItem.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList() ??
          const [],
      latest: json['latest'] is Map
          ? Inspection.fromJson(Map<String, dynamic>.from(json['latest'] as Map))
          : null,
    );
  }
}
