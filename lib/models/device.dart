// lib/models/device.dart
// 设备数据模型

import '../utils/coordinate_converter.dart';

class Device {
  final String id;              // 设备ID
  final String name;            // 设备名称
  final String? avatar;         // 头像URL
  final String deviceNo;        // 设备号
  final double? latitude;       // 纬度
  final double? longitude;      // 经度
  final String? address;        // 地址
  final int? battery;           // 电量 0-100
  final bool isOnline;          // 是否在线
  final DateTime? lastUpdate;   // 最后更新时间
  final String? ownerId;        // 绑定用户ID
  final DateTime? bindTime;     // 绑定时间
  final bool isShared;          // 是否共享查看
  final String? ip;             // 设备IP地址（外部平台推送数据用）
  final int? port;              // 设备端口（外部平台推送数据用）

  /// 获取设备特定的校正坐标
  /// 优先使用设备校正映射表中的目标坐标，如果没有则返回原始坐标
  Map<String, double>? get deviceCorrectedCoordinates {
    if (latitude == null || longitude == null) return null;
    return CoordinateConverter.applyDeviceCorrection(id, latitude!, longitude!);
  }

  /// 获取设备校正后的纬度
  double? get deviceCorrectedLatitude => deviceCorrectedCoordinates?['latitude'];

  /// 获取设备校正后的经度
  double? get deviceCorrectedLongitude => deviceCorrectedCoordinates?['longitude'];

  /// 获取纠偏后的坐标（GPS -> GCJ-02 高德地图）
  @Deprecated('使用 deviceCorrectedCoordinates 代替，它会应用设备特定的坐标校正')
  Map<String, double>? get correctedCoordinates {
    if (latitude == null || longitude == null) return null;
    return CoordinateConverter.gpsToAmap(latitude!, longitude!);
  }

  /// 获取纠偏后的纬度
  @Deprecated('使用 deviceCorrectedLatitude 代替，它会应用设备特定的坐标校正')
  double? get correctedLatitude => correctedCoordinates?['latitude'];

  /// 获取纠偏后的经度
  @Deprecated('使用 deviceCorrectedLongitude 代替，它会应用设备特定的坐标校正')
  double? get correctedLongitude => correctedCoordinates?['longitude'];

  Device({
    required this.id,
    required this.name,
    this.avatar,
    this.deviceNo = '',
    this.latitude,
    this.longitude,
    this.address,
    this.battery,
    this.isOnline = false,
    this.lastUpdate,
    this.ownerId,
    this.bindTime,
    this.isShared = false,
    this.ip,
    this.port,
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
  factory Device.fromJson(Map<String, dynamic> json) {
    // 如果没有设备头像，尝试使用userAvatar（用户设置的头像）
    String? avatarUrl = json['avatar'];
    if ((avatarUrl == null || avatarUrl.isEmpty) && json['userAvatar'] != null && json['userAvatar'].toString().isNotEmpty) {
      avatarUrl = json['userAvatar'].toString();
    }

    return Device(
      id: json['deviceId']?.toString() ?? json['id']?.toString() ?? '',
      name: json['deviceName'] ?? json['name'] ?? '未命名设备',
      avatar: avatarUrl,
      deviceNo: json['deviceCode'] ?? json['deviceSn'] ?? json['deviceNo'] ?? '',
      latitude: _parseDouble(json['latitude'] ?? json['lastLatitude']),
      longitude: _parseDouble(json['longitude'] ?? json['lastLongitude']),
      address: json['address'],
      battery: _parseInt(json['batteryLevel'] ?? json['battery']),
      isOnline: json['status'] == '1',
      lastUpdate: json['lastLocationTime'] != null
          ? DateTime.parse(json['lastLocationTime'])
          : null,
      ownerId: json['userId']?.toString(),
      bindTime: json['bindDate'] != null
          ? DateTime.parse(json['bindDate'])
          : null,
      isShared: json['isShared'] ?? false,
      ip: json['ip'],
      port: json['port'] != null ? _parseInt(json['port']) : null,
    );
  }
  
  // 转JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatar': avatar,
      'deviceNo': deviceNo,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'battery': battery,
      'isOnline': isOnline,
      'lastUpdate': lastUpdate?.toIso8601String(),
      'ownerId': ownerId,
      'bindTime': bindTime?.toIso8601String(),
      'isShared': isShared,
      'ip': ip,
      'port': port,
    };
  }
  
  // 复制并修改
  Device copyWith({
    String? id,
    String? name,
    String? avatar,
    String? deviceNo,
    double? latitude,
    double? longitude,
    String? address,
    int? battery,
    bool? isOnline,
    DateTime? lastUpdate,
    String? ownerId,
    DateTime? bindTime,
    bool? isShared,
    String? ip,
    int? port,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      deviceNo: deviceNo ?? this.deviceNo,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      battery: battery ?? this.battery,
      isOnline: isOnline ?? this.isOnline,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      ownerId: ownerId ?? this.ownerId,
      bindTime: bindTime ?? this.bindTime,
      isShared: isShared ?? this.isShared,
      ip: ip ?? this.ip,
      port: port ?? this.port,
    );
  }

  /// 获取外部平台推送数据的完整地址
  /// 格式: http://ip:port
  String? get pushUrl {
    if (ip == null || port == null) return null;
    return 'http://$ip:$port';
  }

  /// 是否已经配置了推送地址
  bool get hasPushConfig => ip != null && ip!.isNotEmpty && port != null;
}
