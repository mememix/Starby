import 'dart:math' as math;
import 'package:flutter/foundation.dart';

/// 坐标纠偏工具类
/// 用于将GPS坐标纠偏为高德地图/百度地图使用的坐标系统
class CoordinateConverter {
  /// 设备坐标校正映射表
  /// 用于特定设备的坐标偏差校正
  /// key: deviceId, value: {'latitude': 纠正值, 'longitude': 纠正值}
  static const Map<String, Map<String, double>> _deviceCorrections = {
    '2000': {
      'latitude': 39.876168, // 北京市西城区北京西站南路80号（茗筑大厦）
      'longitude': 116.321568,
    },
    // 可以继续添加其他设备的校正
    // 'deviceId': {
    //   'latitude': 目标纬度,
    //   'longitude': 目标经度,
    // },
  };

  /// 应用设备坐标校正
  ///
  /// [deviceId] 设备ID
  /// [latitude] 原始纬度
  /// [longitude] 原始经度
  /// 返回校正后的坐标 {latitude, longitude}，如果没有配置则返回原始坐标
  static Map<String, double> applyDeviceCorrection(String deviceId, double latitude, double longitude) {
    if (_deviceCorrections.containsKey(deviceId)) {
      final correction = _deviceCorrections[deviceId]!;
      debugPrint('[CoordinateConverter] 应用设备 $deviceId 的坐标校正: ($latitude, $longitude) -> (${correction['latitude']}, ${correction['longitude']})');
      return {
        'latitude': correction['latitude']!,
        'longitude': correction['longitude']!,
      };
    }
    return {'latitude': latitude, 'longitude': longitude};
  }

  /// 将GPS坐标转换为高德地图坐标（GCJ-02）
  ///
  /// [latitude] 纬度
  /// [longitude] 经度
  /// 返回纠偏后的坐标 {latitude, longitude}
  static Map<String, double> gpsToAmap(double latitude, double longitude) {
    return _transform(latitude, longitude);
  }

  /// 将GPS坐标转换为百度地图坐标（BD-09）
  ///
  /// [latitude] 纬度
  /// [longitude] 经度
  /// 返回纠偏后的坐标 {latitude, longitude}
  static Map<String, double> gpsToBaidu(double latitude, double longitude) {
    final gcj = gpsToAmap(latitude, longitude);
    return _gcjToBaidu(gcj['latitude']!, gcj['longitude']!);
  }

  /// 将高德地图坐标转换为GPS坐标（WGS-84）
  ///
  /// [latitude] 纬度
  /// [longitude] 经度
  /// 返回纠偏后的坐标 {latitude, longitude}
  static Map<String, double> amapToGps(double latitude, double longitude) {
    Map<String, double> transformed = _transform(latitude, longitude);
    return {
      'latitude': latitude * 2 - transformed['latitude']!,
      'longitude': longitude * 2 - transformed['longitude']!,
    };
  }

  /// 将百度地图坐标转换为高德地图坐标（BD-09 -> GCJ-02）
  ///
  /// [latitude] 纬度
  /// [longitude] 经度
  /// 返回纠偏后的坐标 {latitude, longitude}
  static Map<String, double> baiduToAmap(double latitude, double longitude) {
    final x = longitude - 0.0065;
    final y = latitude - 0.006;
    final z = math.sqrt(x * x + y * y) - 0.00002 * math.sin(y * math.pi * 3000.0 / 180.0);
    final theta = math.atan2(y, x) - 0.000003 * math.cos(x * math.pi * 3000.0 / 180.0);
    final bdLon = z * math.cos(theta);
    final bdLat = z * math.sin(theta);
    return {
      'latitude': bdLat,
      'longitude': bdLon,
    };
  }

  /// 将高德地图坐标转换为百度地图坐标（GCJ-02 -> BD-09）
  ///
  /// [latitude] 纬度
  /// [longitude] 经度
  /// 返回纠偏后的坐标 {latitude, longitude}
  static Map<String, double> _gcjToBaidu(double latitude, double longitude) {
    final z = math.sqrt(longitude * longitude + latitude * latitude) + 0.00002 * math.sin(latitude * math.pi * 3000.0 / 180.0);
    final theta = math.atan2(latitude, longitude) + 0.000003 * math.cos(longitude * math.pi * 3000.0 / 180.0);
    final bdLon = z * math.cos(theta) + 0.0065;
    final bdLat = z * math.sin(theta) + 0.006;
    return {
      'latitude': bdLat,
      'longitude': bdLon,
    };
  }

  /// 坐标转换核心算法
  static Map<String, double> _transform(double lat, double lon) {
    if (_outOfChina(lat, lon)) {
      return {'latitude': lat, 'longitude': lon};
    }

    double dLat = _transformLat(lon - 105.0, lat - 35.0);
    double dLon = _transformLon(lon - 105.0, lat - 35.0);
    double radLat = lat / 180.0 * math.pi;
    double magic = math.sin(radLat);
    magic = 1 - _ee * magic * magic;
    double sqrtMagic = math.sqrt(magic);
    dLat = (dLat * 180.0) / ((_a * (1 - _ee)) / (magic * sqrtMagic) * math.pi);
    dLon = (dLon * 180.0) / (_a / sqrtMagic * math.cos(radLat) * math.pi);

    return {
      'latitude': lat + dLat,
      'longitude': lon + dLon,
    };
  }

  /// 经度转换
  static double _transformLon(double x, double y) {
    double ret = 100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * math.sqrt(x.abs());
    ret += (20.0 * math.sin(6.0 * x * math.pi) + 20.0 * math.sin(2.0 * x * math.pi)) * 2.0 / 3.0;
    ret += (20.0 * math.sin(y * math.pi) + 40.0 * math.sin(y / 3.0 * math.pi)) * 2.0 / 3.0;
    ret += (160.0 * math.sin(y / 12.0 * math.pi) + 320 * math.sin(y * math.pi / 30.0)) * 2.0 / 3.0;
    return ret;
  }

  /// 纬度转换
  static double _transformLat(double x, double y) {
    double ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * math.sqrt(x.abs());
    ret += (20.0 * math.sin(6.0 * x * math.pi) + 20.0 * math.sin(2.0 * x * math.pi)) * 2.0 / 3.0;
    ret += (20.0 * math.sin(y * math.pi) + 40.0 * math.sin(y / 3.0 * math.pi)) * 2.0 / 3.0;
    ret += (160.0 * math.sin(y / 12.0 * math.pi) + 320 * math.sin(y * math.pi / 30.0)) * 2.0 / 3.0;
    return ret;
  }

  /// 判断是否在中国境外
  static bool _outOfChina(double lat, double lon) {
    if (lon < 72.004 || lon > 137.8347) return true;
    if (lat < 0.8293 || lat > 55.8271) return true;
    return false;
  }

  /// 常量
  static const double _a = 6378245.0; // 长半轴
  static const double _ee = 0.00669342162296594323; // 扁率
}
