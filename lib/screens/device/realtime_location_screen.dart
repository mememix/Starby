// lib/screens/device/realtime_location_screen.dart
// 实时定位页

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../constants/colors.dart';
import '../../models/device.dart';
import '../../models/location.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../../config/app_config.dart';
import '../../../widgets/map/amap_widget.dart';

class RealtimeLocationScreen extends StatefulWidget {
  const RealtimeLocationScreen({super.key, this.deviceId});

  final String? deviceId;

  @override
  State<RealtimeLocationScreen> createState() => _RealtimeLocationScreenState();
}

class _RealtimeLocationScreenState extends State<RealtimeLocationScreen> {
  bool _isTracking = true;
  late String deviceId;
  Device? _device;
  Location? _currentLocation;
  WebSocketChannel? _channel;
  bool _connecting = false;
  String? _errorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 优先使用构造函数传递的 deviceId，其次使用路由参数
    final id = widget.deviceId ?? ModalRoute.of(context)?.settings.arguments as String?;
    if (id != null && id.isNotEmpty) {
      deviceId = id;
      _loadDeviceInfo();
      _connectWebSocket();
    }
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  // 加载设备信息
  Future<void> _loadDeviceInfo() async {
    try {
      final token = await StorageService.getAuthToken();
      if (token != null) {
        ApiService().setAuthToken(token);
      }

      final device = await ApiService().getDeviceDetail(deviceId);
      // 位置可能为空（设备未上传过位置），这是正常情况
      Location? location;
      try {
        location = await ApiService().getDeviceLocation(deviceId);
      } catch (locationError) {
        // 位置获取失败不影响设备信息显示
        debugPrint('获取位置失败（设备可能未上传过位置）: $locationError');
      }

      // 合并设备信息到位置对象
      Location? mergedLocation;
      if (location != null) {
        mergedLocation = Location(
          id: location.id,
          deviceId: deviceId,
          lat: location.lat,
          lng: location.lng,
          address: location.address ?? device.address,
          accuracy: location.accuracy,
          battery: location.battery ?? device.battery,
          timestamp: device.lastUpdate ?? location.timestamp ?? DateTime.now(),
          type: location.type,
        );
        debugPrint('[RealtimeLocation] Merged device info for $deviceId');
      } else if (device.latitude != null && device.longitude != null) {
        // 使用设备对象中的位置信息作为后备
        mergedLocation = Location(
          id: '',
          deviceId: deviceId,
          lat: device.latitude!,
          lng: device.longitude!,
          address: device.address,
          battery: device.battery,
          timestamp: device.lastUpdate ?? DateTime.now(),
        );
        debugPrint('[RealtimeLocation] Using device location as fallback for $deviceId');
      }

      if (mounted) {
        setState(() {
          _device = device;
          _currentLocation = mergedLocation;
        });
      }
    } catch (e) {
      debugPrint('加载设备信息失败: $e');
      if (mounted) {
        setState(() {
          _errorMessage = '加载设备信息失败: $e';
        });
      }
    }
  }

  // 连接 WebSocket
  void _connectWebSocket() async {
    if (!_isTracking) return;

    setState(() => _connecting = true);

    final token = await StorageService.getAuthToken();
    if (token == null) {
      if (mounted) {
        setState(() {
          _errorMessage = '未登录';
          _connecting = false;
        });
      }
      return;
    }

    // 使用配置文件中的WebSocket地址
    final wsUrl = Uri.parse('${AppConfig.WS_BASE_URL}?token=$token');
    _channel = WebSocketChannel.connect(wsUrl);

    _channel!.stream.listen(
      (message) {
        final data = json.decode(message);
        if (data['type'] == 'location') {
          final locationData = data['data'] as Map<String, dynamic>;
          // 检查是否是当前设备的位置更新
          if (locationData['deviceId'] == deviceId) {
            if (mounted) {
              setState(() {
                _currentLocation = Location.fromJson(locationData);
              });
            }
          }
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _errorMessage = 'WebSocket连接错误';
            _connecting = false;
          });
        }
      },
      onDone: () {
        if (mounted) {
          setState(() {
            _connecting = false;
          });
        }
      },
    );

    if (mounted) {
      setState(() => _connecting = false);
    }
  }

  // 切换追踪状态
  void _toggleTracking() {
    setState(() {
      _isTracking = !_isTracking;
    });

    if (_isTracking) {
      _connectWebSocket();
    } else {
      _channel?.sink.close();
      _channel = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_device == null) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_errorMessage != null)
                  Column(
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadDeviceInfo,
                        child: const Text('重试'),
                      ),
                    ],
                  )
                else
                  const CircularProgressIndicator(color: Colors.blue),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // 全屏地图区域
          _buildMapArea(),
          
          // 顶部导航栏
          _buildHeader(),
          
          // 底部信息栏
          _buildBottomInfo(),
        ],
      ),
    );
  }

  // 顶部导航栏
  Widget _buildHeader() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.arrow_back,
                size: 20,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  _isTracking ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  size: 16,
                  color: _isTracking ? const Color(0xFF4CAF50) : Colors.grey[400],
                ),
                const SizedBox(width: 8),
                Text(
                  _isTracking ? '追踪中' : '已暂停',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _isTracking ? const Color(0xFF4CAF50) : AppColors.textSecondary,
                  ),
                ),
                if (_connecting)
                  const SizedBox(
                    width: 8,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 地图区域
  Widget _buildMapArea() {
    final lat = _currentLocation?.lat ?? _device?.latitude ?? 39.909187;
    final lng = _currentLocation?.lng ?? _device?.longitude ?? 116.397451;

    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        children: [
          AMapWidget(
            initialCameraPosition: LatLng(lat, lng),
            markers: _currentLocation != null && _device != null ? {
              Marker(
                id: 'realtime_${_device!.id}',
                position: LatLng(lat, lng),
                infoWindow: InfoWindow(title: _device!.name),
                isOnline: _device!.isOnline,
                avatar: _device!.avatar,
                battery: _device!.battery,
                lastUpdate: _currentLocation!.timestamp,
              ),
            } : {},
            myLocationEnabled: true,
            showNavigationButton: true,
          ),
        ],
      ),
    );
  }

  // 底部信息栏
  Widget _buildBottomInfo() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              
              // 设备信息
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _device?.name ?? '',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentLocation != null
                              ? '${_currentLocation!.lat.toStringAsFixed(4)}, ${_currentLocation!.lng.toStringAsFixed(4)}'
                              : '等待位置更新',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _device?.isOnline == true
                          ? const Color(0xFFE8F5E9)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _device?.isOnline == true ? '在线' : '离线',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _device?.isOnline == true
                            ? const Color(0xFF4CAF50)
                            : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // 实时数据
              Row(
                children: [
                  Expanded(
                    child: _buildDataItem(
                      '电量',
                      (_currentLocation?.battery ?? _device?.battery) != null
                          ? '${_currentLocation?.battery ?? _device?.battery}%'
                          : '--%',
                      Icons.battery_full,
                    ),
                  ),
                  Expanded(
                    child: _buildDataItem(
                      '精度',
                      _currentLocation?.accuracy != null
                          ? '${_currentLocation!.accuracy!.toStringAsFixed(0)}m'
                          : '--m',
                      Icons.gps_fixed,
                    ),
                  ),
                  Expanded(
                    child: _buildDataItem(
                      '更新',
                      _currentLocation != null
                          ? _formatTime(_currentLocation!.timestamp)
                          : '--',
                      Icons.access_time,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // 操作按钮
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _connecting ? null : _toggleTracking,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: _isTracking ? const Color(0xFFF44336) : AppColors.primary),
                          foregroundColor: _isTracking ? const Color(0xFFF44336) : AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: Icon(
                            _isTracking ? Icons.stop : Icons.play_arrow,
                            size: 20,
                        ),
                        label: Text(
                          _isTracking ? '停止追踪' : '开始追踪',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 格式化时间
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}小时前';
    } else {
      return '${difference.inDays}天前';
    }
  }

  // 数据项
  Widget _buildDataItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: AppColors.textSecondary,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
