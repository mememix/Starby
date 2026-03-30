// lib/services/storage_service.dart
// 本地存储服务

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class StorageService {
  static const String _keyHomeStyle = 'home_style';
  static const String _keyLoggedIn = 'logged_in';
  static const String _keyLoginType = 'login_type';
  static const String _keyAuthToken = 'auth_token';
  static const String _keyUserId = 'user_id';
  static const String _keyUserPhone = 'user_phone';
  static const String _keyUserInfo = 'user_info';
  static const String _classic = 'classic';
  static const String _immersive = 'immersive';
  static const String _loginTypePhone = 'phone';
  static const String _loginTypeDevice = 'device';

  /// 获取首页风格
  static Future<String> getHomeStyle() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyHomeStyle) ?? _classic;
    } catch (e) {
      return _classic;
    }
  }

  /// 检查是否已登录
  static Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyLoggedIn) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// 设置登录状态
  static Future<void> setLoggedIn(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyLoggedIn, value);
    } catch (e) {
      debugPrint('Error saving login state: $e');
    }
  }

  /// 设置认证Token
  static Future<void> setAuthToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAuthToken, token);
    } catch (e) {
      debugPrint('Error saving auth token: $e');
    }
  }

  /// 获取认证Token
  static Future<String?> getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyAuthToken);
    } catch (e) {
      return null;
    }
  }

  /// 清除认证Token
  static Future<void> clearAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyAuthToken);
    } catch (e) {
      debugPrint('Error clearing auth token: $e');
    }
  }

  /// 设置用户ID
  static Future<void> setUserId(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUserId, userId);
    } catch (e) {
      debugPrint('Error saving user id: $e');
    }
  }

  /// 获取用户ID
  static Future<String?> getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyUserId);
    } catch (e) {
      return null;
    }
  }

  /// 设置用户手机号
  static Future<void> setUserPhone(String phone) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUserPhone, phone);
    } catch (e) {
      debugPrint('Error saving user phone: $e');
    }
  }

  /// 获取用户手机号
  static Future<String?> getUserPhone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyUserPhone);
    } catch (e) {
      return null;
    }
  }

  /// 清除所有用户信息（退出登录）
  static Future<void> clearAllUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyAuthToken);
      await prefs.remove(_keyUserId);
      await prefs.remove(_keyUserPhone);
      await prefs.remove(_keyLoggedIn);
      await prefs.remove(_keyLoginType);
    } catch (e) {
      debugPrint('Error clearing user data: $e');
    }
  }

  /// 设置首页风格
  static Future<void> setHomeStyle(String style) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyHomeStyle, style);
    } catch (e) {
      debugPrint('Error saving home style: $e');
    }
  }

  /// 设置为经典版
  static Future<void> setClassicStyle() async {
    await setHomeStyle(_classic);
  }

  /// 设置为沉浸版
  static Future<void> setImmersiveStyle() async {
    await setHomeStyle(_immersive);
  }

  /// 是否为经典版
  static Future<bool> isClassicStyle() async {
    final style = await getHomeStyle();
    return style == _classic;
  }

  /// 是否为沉浸版
  static Future<bool> isImmersiveStyle() async {
    final style = await getHomeStyle();
    return style == _immersive;
  }

  /// 设置登录类型
  static Future<void> setLoginType(String type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLoginType, type);
    } catch (e) {
      debugPrint('Error saving login type: $e');
    }
  }

  /// 获取登录类型
  static Future<String> getLoginType() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyLoginType) ?? _loginTypePhone;
    } catch (e) {
      return _loginTypePhone;
    }
  }

  /// 是否为设备号登录
  static Future<bool> isDeviceLogin() async {
    final type = await getLoginType();
    return type == _loginTypeDevice;
  }

  /// 保存用户信息
  static Future<void> saveUserInfo(Map<String, dynamic> userInfo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userInfoJson = jsonEncode(userInfo);
      await prefs.setString(_keyUserInfo, userInfoJson);
      debugPrint('[StorageService] 保存用户信息成功: $userInfoJson');
    } catch (e) {
      debugPrint('Error saving user info: $e');
    }
  }

  /// 获取用户信息
  static Future<Map<String, dynamic>?> getUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userInfoString = prefs.getString(_keyUserInfo);
      if (userInfoString != null && userInfoString.isNotEmpty) {
        final userInfo = jsonDecode(userInfoString) as Map<String, dynamic>;
        debugPrint('[StorageService] 获取用户信息: $userInfo');
        return userInfo;
      }
      // 如果JSON不存在，尝试从旧的方式获取
      return {
        'id': prefs.getString(_keyUserId),
        'phone': prefs.getString(_keyUserPhone),
      };
    } catch (e) {
      debugPrint('[StorageService] 获取用户信息失败: $e');
      // 发生错误时，返回基本用户信息
      final prefs = await SharedPreferences.getInstance();
      return {
        'id': prefs.getString(_keyUserId),
        'phone': prefs.getString(_keyUserPhone),
      };
    }
  }
}
