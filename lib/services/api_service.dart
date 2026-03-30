// lib/services/api_service.dart
// API服务层 - 添加验证码登录相关接口

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../models/device.dart';
import '../models/location.dart';
import '../models/fence.dart';
import '../models/message.dart';
import 'storage_service.dart';

class ApiService {
  // 使用配置文件中的baseUrl
  static final String baseUrl = AppConfig.API_BASE_URL;

  late final Dio _dio;

  // 单例
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal() {
    if (AppConfig.DEBUG_MODE) {
      debugPrint('[ApiService] Initializing...');
      debugPrint('[ApiService] Base URL: $baseUrl');
      debugPrint('[ApiService] Connect Timeout: ${AppConfig.CONNECT_TIMEOUT}s');
      debugPrint('[ApiService] Receive Timeout: ${AppConfig.RECEIVE_TIMEOUT}s');
    }

    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: AppConfig.CONNECT_TIMEOUT),
      receiveTimeout: const Duration(seconds: AppConfig.RECEIVE_TIMEOUT),
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    // 添加拦截器，每次请求自动添加token
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // 每次请求前从Storage获取最新的token
        final token = await StorageService.getAuthToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
          if (AppConfig.DEBUG_MODE) {
            debugPrint('[ApiService] Request: ${options.method} ${options.uri}');
            final tokenPreview = token.length > 20 ? '${token.substring(0, 20)}...' : token;
            debugPrint('[ApiService] Added Authorization token: $tokenPreview');
          }
        } else {
          if (AppConfig.DEBUG_MODE) {
            debugPrint('[ApiService] No token available for ${options.uri}');
          }
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        if (AppConfig.DEBUG_MODE) {
          debugPrint('[ApiService] Response: ${response.statusCode} ${response.requestOptions.uri}');
        }
        return handler.next(response);
      },
      onError: (error, handler) {
        if (AppConfig.DEBUG_MODE) {
          debugPrint('[ApiService] Error: ${error.requestOptions.uri} - ${error.message}');
        }
        return handler.next(error);
      },
    ));
  }

  // 设置认证Token - 保持接口兼容
  void setAuthToken(String token) {
    // 现在由拦截器自动处理，这里不需要做什么了
    // 但保留方法以兼容现有调用
  }

  // 清除认证Token
  void clearAuthToken() {
    // 由拦截器自动处理，不需要做什么
  }

  // ==================== 认证相关 ====================

  // 登录
  Future<Map<String, dynamic>> login(String phone, String password, {
    String? deviceId,
    String? deviceName,
    String? deviceType,
  }) async {
    try {
      final data = <String, dynamic>{
        'phone': phone,
        'password': password,
      };

      // 添加设备信息
      if (deviceId != null) data['deviceId'] = deviceId;
      if (deviceName != null) data['deviceName'] = deviceName;
      if (deviceType != null) data['deviceType'] = deviceType;

      final response = await _dio.post('/auth/login', data: data);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // 设备号登录
  Future<Map<String, dynamic>> loginByDevice(String deviceNo, String password) async {
    try {
      final response = await _dio.post('/auth/login', data: {
        'deviceNo': deviceNo,
        'password': password,
      });
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // 注册
  Future<Map<String, dynamic>> register(String phone, String password) async {
    try {
      final response = await _dio.post('/auth/register', data: {
        'phone': phone,
        'password': password,
      });
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // 获取当前用户信息
  Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final response = await _dio.get('/auth/me');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // 获取用户统计数据
  Future<Map<String, dynamic>> getUserStats() async {
    try {
      final response = await _dio.get('/auth/stats');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // 获取登录设备列表
  Future<Map<String, dynamic>> getLoginDevices() async {
    try {
      final response = await _dio.get('/auth/devices');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // 删除登录设备
  Future<Map<String, dynamic>> deleteLoginDevice(int deviceId) async {
    try {
      final response = await _dio.delete('/auth/devices/$deviceId');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // 更新用户信息
  Future<Map<String, dynamic>> updateUser(Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/auth/me', data: data);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // 上传用户头像
  Future<Map<String, dynamic>> uploadUserAvatar(String avatarUrl) async {
    try {
      final response = await _dio.put('/auth/me', data: {
        'avatar': avatarUrl,
      });
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // ==================== 验证码登录相关 ====================

  /// 发送验证码
  /// [phone] 手机号
  /// [type] 登录/注册类型（可选：login/register）
  Future<Map<String, dynamic>> sendVerificationCode(String phone, {String type = 'login'}) async {
    try {
      final response = await _dio.post('/auth/send-code', data: {
        'phone': phone,
        'type': type,
      });
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  /// 验证码登录
  /// [phone] 手机号
  /// [code] 验证码
  Future<Map<String, dynamic>> loginWithCode(String phone, String code, {
    String? deviceId,
    String? deviceName,
    String? deviceType,
  }) async {
    try {
      final data = <String, dynamic>{
        'phone': phone,
        'code': code,
      };

      // 添加设备信息
      if (deviceId != null) data['deviceId'] = deviceId;
      if (deviceName != null) data['deviceName'] = deviceName;
      if (deviceType != null) data['deviceType'] = deviceType;

      final response = await _dio.post('/auth/verify-login', data: data);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  /// 验证码注册
  /// [phone] 手机号
  /// [code] 验证码
  /// [password] 密码
  Future<Map<String, dynamic>> registerWithCode(String phone, String code, String password, {
    String? deviceId,
    String? deviceName,
    String? deviceType,
  }) async {
    try {
      final data = <String, dynamic>{
        'phone': phone,
        'code': code,
        'password': password,
      };

      // 添加设备信息
      if (deviceId != null) data['deviceId'] = deviceId;
      if (deviceName != null) data['deviceName'] = deviceName;
      if (deviceType != null) data['deviceType'] = deviceType;

      final response = await _dio.post('/auth/verify-register', data: data);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // ==================== 设备相关 ====================

  // 获取设备列表
  Future<List<Device>> getDevices() async {
    try {
      debugPrint('[ApiService] Getting devices...');
      final response = await _dio.get('/devices');
      debugPrint('[ApiService] Response: $response');

      // 检查响应结构
      if (response.data is! Map) {
        throw Exception('响应格式错误: 期望Map，收到${response.data.runtimeType}');
      }

      final responseData = response.data as Map<String, dynamic>;
      if (!responseData.containsKey('data')) {
        throw Exception('响应中缺少data字段');
      }

      final data = responseData['data'];
      if (data is! Map) {
        throw Exception('data字段格式错误: 期望Map，收到${data.runtimeType}');
      }

      if (!data.containsKey('devices')) {
        throw Exception('响应中缺少devices字段');
      }

      final devicesData = data['devices'];
      if (devicesData is! List) {
        throw Exception('devices字段格式错误: 期望List，收到${devicesData.runtimeType}');
      }

      debugPrint('[ApiService] Found ${devicesData.length} devices');
      return devicesData.map((json) => Device.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('[ApiService] getDevices error: $e');
      rethrow;
    }
  }

  // 绑定设备
  Future<Map<String, dynamic>> bindDevice(String deviceNo, String password, String name) async {
    try {
      final response = await _dio.post('/devices/bind', data: {
        'deviceNo': deviceNo,
        'password': password,
        'name': name,
      });
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // 获取可绑定的JT808设备列表
  Future<List<Device>> getUnboundDevices() async {
    try {
      final response = await _dio.get('/devices/unbound');
      final List<dynamic> data = response.data['data']['devices'];
      return data.map((json) => Device.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }

  // 绑定JT808设备到当前用户
  Future<void> bindDeviceById(String deviceId) async {
    try {
      await _dio.post('/devices/$deviceId/bind');
    } catch (e) {
      rethrow;
    }
  }

  // 解绑设备
  Future<void> unbindDevice(String deviceId) async {
    try {
      await _dio.post('/devices/$deviceId/unbind');
    } catch (e) {
      rethrow;
    }
  }

  // 获取设备详情
  Future<Device> getDeviceDetail(String deviceId) async {
    try {
      final response = await _dio.get('/devices/$deviceId');
      return Device.fromJson(response.data['data']['device']);
    } catch (e) {
      rethrow;
    }
  }

  // 获取设备最新位置
  Future<Location> getDeviceLocation(String deviceId) async {
    try {
      debugPrint('[ApiService] Getting location for device $deviceId...');
      final response = await _dio.get('/devices/$deviceId/location');
      debugPrint('[ApiService] Location response: $response');

      // 检查响应结构
      if (response.data is! Map) {
        throw Exception('位置响应格式错误: 期望Map，收到${response.data.runtimeType}');
      }

      final responseData = response.data as Map<String, dynamic>;
      if (!responseData.containsKey('data')) {
        throw Exception('位置响应中缺少data字段');
      }

      final data = responseData['data'];
      if (data is! Map) {
        throw Exception('位置data字段格式错误: 期望Map，收到${data.runtimeType}');
      }

      // 位置数据可能为null（设备没有位置数据）
      if (!data.containsKey('location') || data['location'] == null) {
        debugPrint('[ApiService] No location data for device $deviceId');
        // 返回一个默认位置
        return Location(
          id: '',
          deviceId: deviceId,
          lat: 0.0,
          lng: 0.0,
          timestamp: DateTime.now(),
        );
      }

      final locationData = data['location'];
      return Location.fromJson(locationData as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[ApiService] getDeviceLocation error: $e');
      // 返回默认位置而不是抛出异常
      return Location(
        id: '',
        deviceId: deviceId,
        lat: 0.0,
        lng: 0.0,
        timestamp: DateTime.now(),
      );
    }
  }

  // 获取设备历史轨迹
  Future<List<Location>> getDeviceHistory(
    String deviceId, {
    DateTime? start,
    DateTime? end,
    int limit = 100,
  }) async {
    try {
      final Map<String, dynamic> queryParams = {
        'limit': limit,
      };
      
      if (start != null) {
        queryParams['startTime'] = start.toIso8601String();
      }
      if (end != null) {
        queryParams['endTime'] = end.toIso8601String();
      }

      final response = await _dio.get(
        '/devices/$deviceId/history',
        queryParameters: queryParams,
      );
      
      final List<dynamic> data = response.data['data']['history'];
      return data.map((json) => Location.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }

  // 更新设备信息
  Future<Map<String, dynamic>> updateDevice(
    String deviceId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.put(
        '/devices/$deviceId',
        data: data,
      );
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // 上传设备头像
  Future<Map<String, dynamic>> uploadDeviceAvatar(String deviceId, String avatarUrl) async {
    try {
      final response = await _dio.put('/devices/$deviceId', data: {
        'avatar': avatarUrl,
      });
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // 更新设备设置
  Future<Map<String, dynamic>> updateDeviceSettings(
    String deviceId,
    Map<String, dynamic> settings,
  ) async {
    try {
      final response = await _dio.put(
        '/devices/$deviceId/settings',
        data: settings,
      );
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // 修改设备密码
  Future<Map<String, dynamic>> changeDevicePassword(
    String deviceId,
    String oldPassword,
    String newPassword,
  ) async {
    try {
      final response = await _dio.put(
        '/devices/$deviceId/password',
        data: {
          'oldPassword': oldPassword,
          'newPassword': newPassword,
        },
      );
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // 解绑设备（删除设备）
  Future<Map<String, dynamic>> deleteDevice(String deviceId) async {
    try {
      final response = await _dio.delete('/devices/$deviceId');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // ==================== 电子围栏相关 ====================

  // 获取围栏列表
  Future<List<Fence>> getFences(String deviceId) async {
    try {
      final response = await _dio.get('/fences');
      final List<dynamic> data = response.data['data']['fences'];
      // 如果提供了deviceId，过滤只返回该设备的围栏
      final filtered = data.where((json) {
        if (deviceId.isEmpty) return true;
        return json['deviceId'] == deviceId;
      });
      return filtered.map((json) => Fence.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }

  // 获取所有围栏列表（不按设备过滤）
  Future<List<Fence>> getAllFences() async {
    try {
      final response = await _dio.get('/fences');
      final List<dynamic> data = response.data['data']['fences'];
      return data.map((json) => Fence.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }

  // 创建电子围栏
  Future<Fence> createFence({
    required String deviceId,
    required String name,
    required double latitude,
    required double longitude,
    required double radius,
    String alarmType = 'both',
  }) async {
    try {
      final response = await _dio.post('/fences', data: {
        'deviceId': deviceId,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'radius': radius,
        'alarmType': alarmType,
      });
      return Fence.fromJson(response.data['data']['fence']);
    } catch (e) {
      rethrow;
    }
  }

  // 更新电子围栏
  Future<Fence> updateFence({
    required String fenceId,
    required String name,
    required double latitude,
    required double longitude,
    required double radius,
    String alarmType = 'both',
  }) async {
    try {
      final response = await _dio.put('/fences/$fenceId', data: {
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'radius': radius,
        'alarmType': alarmType,
      });
      return Fence.fromJson(response.data['data']['fence']);
    } catch (e) {
      rethrow;
    }
  }

  // 删除电子围栏
  Future<Map<String, dynamic>> deleteFence(String fenceId) async {
    try {
      final response = await _dio.delete('/fences/$fenceId');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // ==================== 消息相关 ====================

  // 获取消息列表
  Future<List<Message>> getMessages({String? type, bool unreadOnly = false}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (type != null) {
        queryParams['type'] = type;
      }
      if (unreadOnly) {
        queryParams['unreadOnly'] = 'true';
      }

      final response = await _dio.get(
        '/messages',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      final List<dynamic> data = response.data['data']['messages'];
      return data.map((json) => Message.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }

  // 获取消息详情
  Future<Message> getMessageDetail(String messageId) async {
    try {
      final response = await _dio.get('/messages/$messageId');
      return Message.fromJson(response.data['data']['message']);
    } catch (e) {
      rethrow;
    }
  }

  // 标记消息为已读
  Future<Message> markMessageAsRead(String messageId) async {
    try {
      final response = await _dio.put('/messages/$messageId/read');
      return Message.fromJson(response.data['data']['message']);
    } catch (e) {
      rethrow;
    }
  }

  // 标记所有消息为已读
  Future<Map<String, dynamic>> markAllMessagesAsRead({String? type}) async {
    try {
      final response = await _dio.put('/messages/read-all', data: {
        if (type != null) 'type': type,
      });
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // 删除消息
  Future<Map<String, dynamic>> deleteMessage(String messageId) async {
    try {
      final response = await _dio.delete('/messages/$messageId');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // 清空已读消息
  Future<Map<String, dynamic>> clearReadMessages() async {
    try {
      final response = await _dio.delete('/messages/clear');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // ==================== SOS相关 ====================

  // 触发SOS报警
  Future<Map<String, dynamic>> triggerSOS(String deviceId, {Map<String, dynamic>? location}) async {
    try {
      final response = await _dio.post('/sos/trigger', data: {
        'deviceId': deviceId,
        if (location != null) 'location': location,
      });
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // ==================== 设备共享相关 ====================

  // 获取设备的共享成员列表
  Future<Map<String, dynamic>> getDeviceShares(String deviceId) async {
    try {
      final response = await _dio.get('/devices/$deviceId/shares');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // 获取设备的共享成员数量
  Future<int> getDeviceSharesCount(String deviceId) async {
    try {
      final response = await _dio.get('/devices/$deviceId/shares/count');
      if (response.data['success'] == true) {
        return response.data['data']['count'] as int;
      }
      return 0;
    } catch (e) {
      debugPrint('[ApiService] 获取共享成员数量失败: $e');
      return 0;
    }
  }

  // 添加共享成员
  Future<Map<String, dynamic>> addDeviceShare(
    String deviceId,
    String phone, {
    String role = 'member',
  }) async {
    try {
      final response = await _dio.post(
        '/devices/$deviceId/shares',
        data: {
          'phone': phone,
          'role': role,
        },
      );
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // 移除共享成员
  Future<Map<String, dynamic>> removeDeviceShare(
    String deviceId,
    String shareId,
  ) async {
    try {
      final response = await _dio.delete('/devices/$deviceId/shares/$shareId');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // ==================== 位置上报相关 ====================

  // 上报设备位置
  Future<Map<String, dynamic>> uploadLocation({
    required String deviceId,
    required double latitude,
    required double longitude,
    double? altitude,
    double? speed,
    int? direction,
    double? accuracy,
    int? battery,
  }) async {
    try {
      final response = await _dio.post('/location/upload', data: {
        'deviceId': deviceId,
        'latitude': latitude,
        'longitude': longitude,
        if (altitude != null) 'altitude': altitude,
        if (speed != null) 'speed': speed,
        if (direction != null) 'direction': direction,
        if (accuracy != null) 'accuracy': accuracy,
        if (battery != null) 'battery': battery,
      });
      return response.data;
    } catch (e) {
      rethrow;
    }
  }
}
