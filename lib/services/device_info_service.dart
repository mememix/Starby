import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// 设备信息服务
class DeviceInfoService {
  static const String _deviceIdKey = 'device_id';
  static String? _cachedDeviceName;

  /// 获取设备唯一ID
  static Future<String> getDeviceId() async {
    try {
      // 尝试从本地存储获取
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString(_deviceIdKey);
      if (deviceId != null && deviceId.isNotEmpty) {
        return deviceId;
      }

      // 生成新的设备ID
      final newDeviceId = await _generateDeviceId();
      await prefs.setString(_deviceIdKey, newDeviceId);
      return newDeviceId;
    } catch (e) {
      debugPrint('[DeviceInfo] 获取设备ID失败: $e');
      // 生成临时的设备ID
      return _generateDeviceId();
    }
  }

  /// 生成设备ID
  static Future<String> _generateDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();

      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        return webInfo.userAgent?.hashCode.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
      }

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id; // Android ID 是唯一的
      }

      if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? DateTime.now().millisecondsSinceEpoch.toString();
      }

      if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        return macInfo.systemGUID ?? DateTime.now().millisecondsSinceEpoch.toString();
      }

      if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        final computerName = windowsInfo.computerName;
        return computerName;
      }

      if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        final machineId = linuxInfo.machineId;
        return machineId ?? DateTime.now().millisecondsSinceEpoch.toString();
      }
    } catch (e) {
      debugPrint('[DeviceInfo] 生成设备ID失败: $e');
    }

    // 生成基于时间戳和随机数的临时ID
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = random.nextInt(0xFFFFFFFF);
    return '$timestamp-$randomPart';
  }

  /// 获取设备名称
  static Future<String> getDeviceName() async {
    // 使用缓存
    if (_cachedDeviceName != null) {
      return _cachedDeviceName!;
    }

    try {
      final deviceInfo = DeviceInfoPlugin();

      if (kIsWeb) {
        // Web平台
        final webInfo = await deviceInfo.webBrowserInfo;
        final browserName = webInfo.browserName.name;
        _cachedDeviceName = 'Web ($browserName)';
        return _cachedDeviceName!;
      }

      if (Platform.isAndroid) {
        // 获取详细的 Android 设备信息
        final androidInfo = await deviceInfo.androidInfo;
        final brand = androidInfo.brand; // 品牌: Huawei, Xiaomi, Samsung 等
        final model = androidInfo.model; // 型号: Pura 70 Pro, Mi 11 等
        final deviceCode = androidInfo.device; // 设备代号

        // 尝试构建友好的设备名称
        if (brand.isNotEmpty) {
          // 去除首尾空格
          final brandName = brand.trim();
          final modelName = model.trim();
          _cachedDeviceName = modelName.isNotEmpty
              ? '$brandName $modelName'
              : '$brandName 设备';
        } else {
          _cachedDeviceName = deviceCode.isNotEmpty ? deviceCode : 'Android设备';
        }

        debugPrint('[DeviceInfo] Android设备信息:');
        debugPrint('  - 品牌: ${androidInfo.brand}');
        debugPrint('  - 型号: ${androidInfo.model}');
        debugPrint('  - 设备代号: ${androidInfo.device}');
        debugPrint('  - 最终设备名: $_cachedDeviceName');

        return _cachedDeviceName!;
      }

      if (Platform.isIOS) {
        // 获取 iOS 设备信息
        final iosInfo = await deviceInfo.iosInfo;
        final systemVersion = iosInfo.systemVersion;

        // 尝试识别具体的设备型号
        final machine = iosInfo.utsname.machine; // 如: iPhone15,3
        String deviceModel = 'iOS设备';
        if (machine.contains('iPhone')) {
          deviceModel = 'iPhone';
        } else if (machine.contains('iPad')) {
          deviceModel = 'iPad';
        }

        _cachedDeviceName = '$deviceModel (iOS $systemVersion)';

        debugPrint('[DeviceInfo] iOS设备信息:');
        debugPrint('  - 型号: ${iosInfo.model}');
        debugPrint('  - 系统版本: $systemVersion');
        debugPrint('  - 机器代号: $machine');
        debugPrint('  - 最终设备名: $_cachedDeviceName');

        return _cachedDeviceName!;
      }

      if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        _cachedDeviceName = '${macInfo.computerName} (macOS ${macInfo.majorVersion}.${macInfo.minorVersion})';
        return _cachedDeviceName!;
      }

      if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        _cachedDeviceName = '${windowsInfo.computerName} (Windows ${windowsInfo.majorVersion})';
        return _cachedDeviceName!;
      }

      if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        _cachedDeviceName = '${linuxInfo.prettyName} (Linux)';
        return _cachedDeviceName!;
      }
    } catch (e) {
      debugPrint('[DeviceInfo] 获取设备名称失败: $e');
    }

    // 默认返回通用设备名称
    _cachedDeviceName = '未知设备';
    return _cachedDeviceName!;
  }

  /// 获取设备类型
  static Future<String> getDeviceType() async {
    if (kIsWeb) {
      return 'web';
    }

    try {
      if (Platform.isAndroid) {
        return 'android';
      }

      if (Platform.isIOS) {
        return 'ios';
      }

      if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        return 'desktop';
      }
    } catch (e) {
      debugPrint('[DeviceInfo] 获取设备类型失败: $e');
    }

    return 'unknown';
  }

}
