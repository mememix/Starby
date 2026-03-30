// lib/models/fence.dart
// 电子围栏模型

class Fence {
  final String id;
  final String deviceId;
  final String name;
  final double latitude;
  final double longitude;
  final double radius;
  final DateTime createdAt;
  final String? deviceName;
  final String? alarmType; // 'both': 进入和离开都提醒, 'enter': 只提醒进入, 'leave': 只提醒离开
  final int? status;

  Fence({
    required this.id,
    required this.deviceId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.createdAt,
    this.deviceName,
    this.alarmType = 'both',
    this.status = 1,
  });

  factory Fence.fromJson(Map<String, dynamic> json) {
    return Fence(
      id: json['id'] as String,
      deviceId: json['deviceId'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      radius: (json['radius'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      deviceName: json['device'] != null ? json['device']['name'] as String? : null,
      alarmType: json['alarmType'] as String? ?? 'both',
      status: json['status'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceId': deviceId,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'createdAt': createdAt.toIso8601String(),
      if (deviceName != null) 'deviceName': deviceName,
      if (alarmType != null) 'alarmType': alarmType,
      if (status != null) 'status': status,
    };
  }

  Fence copyWith({
    String? id,
    String? deviceId,
    String? name,
    double? latitude,
    double? longitude,
    double? radius,
    DateTime? createdAt,
    String? deviceName,
    String? alarmType,
    int? status,
  }) {
    return Fence(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radius: radius ?? this.radius,
      createdAt: createdAt ?? this.createdAt,
      deviceName: deviceName ?? this.deviceName,
      alarmType: alarmType ?? this.alarmType,
      status: status ?? this.status,
    );
  }
}
