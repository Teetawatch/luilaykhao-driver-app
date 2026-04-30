class Van {
  final int id;
  final String name;
  final String type;
  final int capacity;
  final String licensePlate;
  final String? color;
  final String? driverName;
  final String? driverPhone;
  final String? driverPhoto;
  final List<String>? images;

  const Van({
    required this.id,
    required this.name,
    required this.type,
    required this.capacity,
    required this.licensePlate,
    this.color,
    this.driverName,
    this.driverPhone,
    this.driverPhoto,
    this.images,
  });

  factory Van.fromJson(Map<String, dynamic> json) {
    return Van(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      capacity: json['capacity'] ?? 12,
      licensePlate: json['license_plate'] ?? '',
      color: json['color'],
      driverName: json['driver_name'],
      driverPhone: json['driver_phone'],
      driverPhoto: json['driver_photo'],
      images: json['images'] != null ? List<String>.from(json['images']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'capacity': capacity,
      'license_plate': licensePlate,
      'color': color,
      'driver_name': driverName,
      'driver_phone': driverPhone,
      'driver_photo': driverPhoto,
      'images': images,
    };
  }
}
