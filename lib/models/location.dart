// lib/models/location.dart
// 位置数据模型

class Location {
  final String id;
  final String deviceId;
  final double lat;           // 纬度
  final double lng;           // 经度
  final String? address;      // 地址描述
  final double? accuracy;     // 精度（米）
  final int? battery;         // 当时电量
  final DateTime timestamp;   // 记录时间
  final String type;          // gps/wifi/lbs

  Location({
    required this.id,
    required this.deviceId,
    required this.lat,
    required this.lng,
    this.address,
    this.accuracy,
    this.battery,
    required this.timestamp,
    this.type = 'gps',
  });

  // 安全解析double值
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  // 安全解析int值
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  // 从JSON解析
  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      id: json['trackId'] ?? json['id'] ?? '',
      deviceId: json['deviceId']?.toString() ?? '',
      lat: _parseDouble(json['latitude'] ?? json['lat']) ?? 0.0,
      lng: _parseDouble(json['longitude'] ?? json['lng']) ?? 0.0,
      address: json['address'],
      accuracy: _parseDouble(json['accuracy']),
      battery: _parseInt(json['batteryLevel'] ?? json['battery']),
      timestamp: json['locationTime'] != null
          ? DateTime.parse(json['locationTime'])
          : (json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now()),
      type: json['type'] ?? 'gps',
    );
  }

  // 转JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceId': deviceId,
      'lat': lat,
      'lng': lng,
      'address': address,
      'accuracy': accuracy,
      'battery': battery,
      'timestamp': timestamp.toIso8601String(),
      'type': type,
    };
  }
}

// 位置历史查询参数
class LocationHistoryQuery {
  final String deviceId;
  final DateTime startTime;
  final DateTime endTime;
  final int? page;
  final int? limit;

  LocationHistoryQuery({
    required this.deviceId,
    required this.startTime,
    required this.endTime,
    this.page = 1,
    this.limit = 100,
  });

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'page': page,
      'limit': limit,
    };
  }
}
