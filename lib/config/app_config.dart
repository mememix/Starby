// lib/config/app_config.dart
// 应用配置文件 - 支持多环境

import 'package:flutter/foundation.dart';

enum Environment { dev, prod }

class AppConfig {
  // 当前环境: 开发环境
  static const Environment ENV = Environment.dev;

  // 环境配置
  static String get API_BASE_URL {
    switch (ENV) {
      case Environment.dev:
        return const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: 'http://192.168.1.5:3000/api',
        );
      case Environment.prod:
        return const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: 'https://api.starby.com/api',
        );
    }
  }

  static String get WS_BASE_URL {
    switch (ENV) {
      case Environment.dev:
        return const String.fromEnvironment(
          'WS_BASE_URL',
          defaultValue: 'ws://192.168.1.5:3000/ws/location',
        );
      case Environment.prod:
        return const String.fromEnvironment(
          'WS_BASE_URL',
          defaultValue: 'wss://api.starby.com/ws/location',
        );
    }
  }

  // 高德地图配置
  static String get AMAP_ANDROID_KEY {
    return const String.fromEnvironment(
      'AMAP_ANDROID_KEY',
      defaultValue: '827fcab330d4be1efe82a3bb995bac84',
    );
  }

  static String get AMAP_IOS_KEY {
    return const String.fromEnvironment(
      'AMAP_IOS_KEY',
      defaultValue: 'your-amap-ios-key-here',
    );
  }

  // 高德Web服务Key(用于逆地理编码等Web API)
  static String get AMAP_WEB_KEY {
    return const String.fromEnvironment(
      'AMAP_WEB_KEY',
      defaultValue: 'eea1694fb0a9cad500e605eaa8e3dffe',
    );
  }

  // 其他配置
  static const int CONNECT_TIMEOUT = 15;
  static const int RECEIVE_TIMEOUT = 30; // 增加接收超时时间以支持图片上传
  static const bool DEBUG_MODE = true;
  static const int LOCATION_REFRESH_INTERVAL = 10; // 秒

  // 打印当前配置
  static void printConfig() {
    if (kDebugMode) {
      print('========== App Config ==========');
      print('Environment: ${ENV.name}');
      print('API Base URL: $API_BASE_URL');
      print('WebSocket URL: $WS_BASE_URL');
      print('AMAP Android Key: ${AMAP_ANDROID_KEY != "your-amap-android-key-here" ? "已配置" : "未配置"}');
      print('AMAP iOS Key: ${AMAP_IOS_KEY != "your-amap-ios-key-here" ? "已配置" : "未配置"}');
      print('AMAP Web Key: ${AMAP_WEB_KEY != "your-amap-android-key-here" ? "已配置" : "未配置"}');
      print('=================================');
    }
  }
}
