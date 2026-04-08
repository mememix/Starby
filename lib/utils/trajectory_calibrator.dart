// lib/utils/trajectory_calibrator.dart
// 轨迹校准工具类

import 'dart:math';
import '../models/location.dart';

class TrajectoryCalibrator {
  // 静止判断距离阈值（米），小于此距离视为静止
  static const double _stationaryDistanceThreshold = 15.0;

  // 静止时间阈值（秒），超过此时间视为静止时段
  static const int _stationaryTimeThreshold = 120; // 2分钟

  // 最小移动距离阈值（米），小于此距离的移动点会被过滤
  static const double _minMoveDistanceThreshold = 5.0;

  // 最小时间间隔阈值（秒），用于保留时间节点
  static const int _minTimeInterval = 30;

  // 地球半径（米）
  static const double _earthRadius = 6371000.0;

  /// 校准轨迹数据 - 增强版
  /// - 检测静止时段（长时间在同一位置），只保留起点和终点
  /// - 移动时段：过滤掉距离过小的点
  /// - 大幅减少静止时段的点位数量
  static List<Location> calibrate(List<Location> locations) {
    if (locations.length <= 2) {
      return locations;
    }

    List<Location> calibrated = [];
    calibrated.add(locations.first);

    Location? prev = locations.first;
    bool inStationaryPeriod = false;
    Location? stationaryStart;

    for (int i = 1; i < locations.length; i++) {
      Location current = locations[i];

      // 计算与前一点的距离
      double distance = calculateDistance(
        prev!.lat,
        prev.lng,
        current.lat,
        current.lng,
      );

      // 计算与静止起点的距离（如果在静止时段）
      double distanceFromStart = 0.0;
      if (stationaryStart != null) {
        distanceFromStart = calculateDistance(
          stationaryStart.lat,
          stationaryStart.lng,
          current.lat,
          current.lng,
        );
      }

      // 判断是否静止
      bool isStationary = distance < _stationaryDistanceThreshold;

      if (isStationary) {
        // 静止状态
        if (!inStationaryPeriod) {
          // 进入静止时段，记录起点
          inStationaryPeriod = true;
          stationaryStart = prev;
        }
        // 静止时段内不添加中间点
      } else {
        // 移动状态
        if (inStationaryPeriod) {
          // 退出静止时段，添加静止时段的终点（上一个点）
          if (prev != calibrated.last && prev != stationaryStart) {
            calibrated.add(prev!);
          }
          inStationaryPeriod = false;
          stationaryStart = null;
        }

        // 移动时段：距离超过阈值或时间间隔足够长则添加
        int timeDiff = current.timestamp.difference(calibrated.last.timestamp).inSeconds;
        if (distance >= _minMoveDistanceThreshold || timeDiff >= _minTimeInterval) {
          calibrated.add(current);
        }
      }

      prev = current;
    }

    // 处理最后一个静止时段
    if (inStationaryPeriod && prev != calibrated.last) {
      calibrated.add(prev!);
    }

    // 确保始终保留最后一个点
    if (calibrated.last != locations.last) {
      calibrated.add(locations.last);
    }

    return calibrated;
  }

  /// 使用 Haversine 公式计算两点之间的距离（米）
  static double calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    double dLat = _toRadians(lat2 - lat1);
    double dLng = _toRadians(lng2 - lng1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return _earthRadius * c;
  }

  /// 角度转弧度
  static double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  /// 获取校准统计信息
  static Map<String, dynamic> getCalibrationStats(
    List<Location> original,
    List<Location> calibrated,
  ) {
    return {
      'originalCount': original.length,
      'calibratedCount': calibrated.length,
      'reduction': original.isNotEmpty
          ? ((original.length - calibrated.length) / original.length * 100)
              .toStringAsFixed(1)
          : '0.0',
    };
  }
}
