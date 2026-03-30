// lib/screens/home/home_immersive_screen.dart
// 首页 - 沉浸式版本

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../constants/colors.dart';
import '../../models/device.dart';
import '../../models/location.dart';
import '../../routes.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/map/amap_widget.dart';

class HomeImmersiveScreen extends StatefulWidget {
  const HomeImmersiveScreen({super.key});

  @override
  State<HomeImmersiveScreen> createState() => _HomeImmersiveScreenState();
}

class _HomeImmersiveScreenState extends State<HomeImmersiveScreen> {
  int _currentDeviceIndex = 0;
  bool _isDeviceLogin = false;
  bool _isLoading = true;
  List<Device> _devices = [];
  Map<String, Location> _deviceLocations = {};
  String? _errorMessage;

  // 将base64头像数据转换为ImageProvider
  ImageProvider? _getAvatarProvider(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return null;
    }
    
    // 检查是否为data:image/开头的base64数据URI
    if (avatarUrl.startsWith('data:image/') && avatarUrl.contains(';base64,')) {
      try {
        // 提取base64部分
        final base64String = avatarUrl.split(';base64,').last;
        if (base64String.isEmpty) {
          return null;
        }
        final bytes = base64.decode(base64String);
        return MemoryImage(bytes);
      } catch (e) {
        debugPrint('[HomeImmersiveScreen] 解析base64头像失败: $e');
        return null;
      }
    } else {
      // 如果是普通的网络URL，使用NetworkImage
      return NetworkImage(avatarUrl);
    }
  }

  // 获取默认头像emoji
  String _getDefaultAvatar(String deviceName) {
    const avatars = ['🦁', '👶', '🐱', '👴', '👧', '👦', '🐶', '🐼', '🐯', '🦊'];
    final hashCode = deviceName.hashCode;
    return avatars[hashCode % avatars.length];
  }

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  // 从后端加载设备列表
  Future<void> _loadDevices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 从本地存储获取Token并设置到ApiService
      final token = await StorageService.getAuthToken();
      final tokenPreview = token != null && token.length > 20
          ? '${token.substring(0, 20)}...'
          : (token ?? 'null');
      debugPrint('[HomeImmersive] Got token from storage: $tokenPreview');

      if (token == null || token.isEmpty) {
        // Token不存在，跳转到登录页
        debugPrint('[HomeImmersive] No token, redirect to login');
        if (mounted) {
          await StorageService.setLoggedIn(false);
          Navigator.pushReplacementNamed(context, AppRoutes.login);
          return;
        }
      }

      ApiService().setAuthToken(token!);
      debugPrint('[HomeImmersive] Calling getDevices...');
      final devices = await ApiService().getDevices();
      debugPrint('[HomeImmersive] Loaded ${devices.length} devices');
      for (var device in devices) {
        debugPrint('[HomeImmersive] Device: ${device.id}, ${device.name}, ${device.deviceNo}');
      }
      final isDevice = await StorageService.isDeviceLogin();

      // 加载所有设备的位置信息
      Map<String, Location> locations = {};
      for (final device in devices) {
        try {
          final location = await ApiService().getDeviceLocation(device.id);
          // 检查位置是否有效（不是默认的0.0, 0.0）
          if (location.lat != 0.0 && location.lng != 0.0) {
            // 位置API返回有效经纬度，但地址和电量可能为空
            // 合并设备对象中的地址和电量信息
            // 应用设备特定的坐标校正
            debugPrint('[HomeImmersive] 设备 ${device.id}: 坐标(${location.lat}, ${location.lng})');
            debugPrint('[HomeImmersive] 设备 ${device.id}: API地址="${location.address}", 设备地址="${device.address}"');

            // 应用设备特定的坐标校正
            final corrected = device.deviceCorrectedCoordinates ??
                {'latitude': location.lat, 'longitude': location.lng};
            final finalLat = corrected['latitude']!;
            final finalLng = corrected['longitude']!;

            debugPrint('[HomeImmersive] 应用坐标校正: (${location.lat}, ${location.lng}) -> ($finalLat, $finalLng)');

            // 优先使用API的经纬度（最新数据），但使用设备表的地址（轨迹表地址通常为null）
            final mergedLocation = Location(
              id: location.id,
              deviceId: device.id,
              lat: finalLat,
              lng: finalLng,
              address: device.address ?? location.address, // 优先使用设备表的地址
              accuracy: location.accuracy,
              battery: device.battery ?? location.battery, // 优先使用设备表的电量
              timestamp: location.timestamp ?? device.lastUpdate ?? DateTime.now(),
              type: location.type,
            );
            locations[device.id] = mergedLocation;
            if (location.address == null && device.address != null) {
              debugPrint('[HomeImmersive] Merged device address for ${device.id}');
            }
            if (location.battery == null && device.battery != null) {
              debugPrint('[HomeImmersive] Merged device battery for ${device.id}');
            }
          } else if (device.latitude != null && device.longitude != null) {
            // 位置API返回无效数据，使用设备对象中的位置信息作为后备（应用设备特定校正）
            debugPrint('[HomeImmersive] API returned (0,0), using device location for ${device.id}');

            // 应用设备特定的坐标校正
            final corrected = device.deviceCorrectedCoordinates ??
                {'latitude': device.latitude!, 'longitude': device.longitude!};
            final finalLat = corrected['latitude']!;
            final finalLng = corrected['longitude']!;

            debugPrint('[HomeImmersive] 应用坐标校正: (${device.latitude}, ${device.longitude}) -> ($finalLat, $finalLng)');

            locations[device.id] = Location(
              id: '',
              deviceId: device.id,
              lat: finalLat,
              lng: finalLng,
              address: device.address,
              battery: device.battery,
              timestamp: device.lastUpdate ?? DateTime.now(),
            );
          } else {
            debugPrint('[HomeImmersive] No valid location for device ${device.id}');
          }
        } catch (e) {
          // 某个设备位置获取失败不影响其他设备
          debugPrint('Failed to load location for device ${device.id}: $e');
          // 尝试使用设备对象中的位置信息作为后备（应用设备特定校正）
          if (device.latitude != null && device.longitude != null) {
            debugPrint('[HomeImmersive] Using device location as fallback for ${device.id}');

            // 应用设备特定的坐标校正
            final corrected = device.deviceCorrectedCoordinates ??
                {'latitude': device.latitude!, 'longitude': device.longitude!};
            final finalLat = corrected['latitude']!;
            final finalLng = corrected['longitude']!;

            debugPrint('[HomeImmersive] 应用坐标校正: (${device.latitude}, ${device.longitude}) -> ($finalLat, $finalLng)');

            locations[device.id] = Location(
              id: '',
              deviceId: device.id,
              lat: finalLat,
              lng: finalLng,
              address: device.address,
              battery: device.battery,
              timestamp: device.lastUpdate ?? DateTime.now(),
            );
          }
        }
      }

      if (mounted) {
        setState(() {
          _devices = devices;
          _isDeviceLogin = isDevice;
          _deviceLocations = locations;
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.response?.data?['message'] ?? '加载设备列表失败';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '加载设备列表失败: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _switchDevice(int direction) {
    if (_isDeviceLogin || _devices.length <= 1) return;
    setState(() {
      _currentDeviceIndex = (_currentDeviceIndex + direction + _devices.length) % _devices.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFCE8EA), Colors.white],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadDevices,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 检查设备列表是否为空
    if (_devices.isEmpty) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFCE8EA), Colors.white],
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.devices_other,
                    size: 80,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '暂无设备',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '绑定您的设备，开始守护之旅',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.deviceBind,
                      ).then((_) => _loadDevices());
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('绑定设备'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () async {
                      // 清除登录状态并跳转到登录页
                      await StorageService.setLoggedIn(false);
                      await StorageService.clearAuthToken();
                      if (mounted) {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppRoutes.login,
                          (route) => false,
                        );
                      }
                    },
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('退出登录'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // 确保 _currentDeviceIndex 在有效范围内
    if (_currentDeviceIndex >= _devices.length) {
      _currentDeviceIndex = 0;
    }

    final device = _devices[_currentDeviceIndex];
    final isOnline = device.isOnline;

    final currentLocation = _deviceLocations[device.id];
    // 如果没有位置信息，使用默认位置（北京）
    final centerPosition = currentLocation != null
        ? LatLng(currentLocation.lat, currentLocation.lng)
        : const LatLng(39.9042, 116.4074);

    return Scaffold(
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity == null) return;
          if (details.primaryVelocity! < 0) {
            _switchDevice(1); // 左滑 -> 下一个
          } else if (details.primaryVelocity! > 0) {
            _switchDevice(-1); // 右滑 -> 上一个
          }
        },
        child: Stack(
          children: [
            // 实时地图背景
            Positioned.fill(
              child: AMapWidget(
                initialCameraPosition: centerPosition,
                markers: currentLocation != null ? {
                  Marker(
                    id: 'current_${device.id}',
                    position: LatLng(currentLocation.lat, currentLocation.lng),
                    infoWindow: InfoWindow(title: device.name),
                    isOnline: device.isOnline,
                    avatar: device.avatar,
                    battery: device.battery,
                    lastUpdate: currentLocation.timestamp,
                  ),
                } : {},
                myLocationEnabled: true,
              ),
            ),

            // 设备头像 - 位置调整到45%
            Positioned(
              top: MediaQuery.of(context).size.height * 0.45,
              left: MediaQuery.of(context).size.width * 0.5 - 40,
              child: GestureDetector(
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.deviceDetail,
                  arguments: device.id,
                ),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 24,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: _buildDeviceAvatar(device, 36),
                ),
              ),
            ),

            // 顶部栏
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isOnline ? const Color(0xFF4CAF50) : Colors.grey[600],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          device.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isOnline ? '在线' : '离线',
                          style: TextStyle(
                            fontSize: 12,
                            color: isOnline ? const Color(0xFF4CAF50) : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, AppRoutes.deviceBind),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.add, color: AppColors.primary, size: 24),
                    ),
                  ),
                ],
              ),
            ),

            // 底部设备信息
            Positioned(
              bottom: 100,
              left: 16,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.pushNamed(
                  context,
                  AppRoutes.deviceDetail,
                  arguments: device.id,
                ),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: _buildDeviceAvatar(device, 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              device.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (currentLocation != null)
                              Text(
                                currentLocation.address ?? 
                                    '📍 ${currentLocation.lat.toStringAsFixed(4)}, ${currentLocation.lng.toStringAsFixed(4)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            else
                              Text(
                                '等待位置更新',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (currentLocation?.battery != null) ...[
                                  Icon(Icons.battery_full, size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${currentLocation!.battery}%',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                if (currentLocation != null) ...[
                                  Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatTime(currentLocation.timestamp),
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
            ),

            // 右侧按钮
            Positioned(
              right: 16,
              top: MediaQuery.of(context).size.height * 0.35,
              child: Column(
                children: [
                  _buildActionButton(Icons.my_location, () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('定位到当前位置')),
                    );
                  }),
                  const SizedBox(height: 12),
                  _buildActionButton(Icons.layers, () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('切换地图类型')),
                    );
                  }),
                  const SizedBox(height: 12),
                  _buildActionButton(Icons.message_outlined, () {
                    Navigator.pushNamed(context, AppRoutes.message);
                  }),
                  const SizedBox(height: 12),
                  _buildActionButton(Icons.person_outline, () {
                    Navigator.pushNamed(context, AppRoutes.profile);
                  }),
                ],
              ),
            ),

            // 左右切换按钮 - 位置调整到70%
            if (!_isDeviceLogin && _devices.length > 1) ...[
              Positioned(
                top: MediaQuery.of(context).size.height * 0.7,
                left: 8,
                child: GestureDetector(
                  onTap: () => _switchDevice(-1),
                  child: Container(
                    width: 40,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4),
                      ],
                    ),
                    child: const Icon(Icons.chevron_left, color: AppColors.textSecondary, size: 24),
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).size.height * 0.7,
                right: 8,
                child: GestureDetector(
                  onTap: () => _switchDevice(1),
                  child: Container(
                    width: 40,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4),
                      ],
                    ),
                    child: const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 24),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Icon(icon, color: AppColors.textSecondary, size: 22),
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

  // 构建设备头像，优先使用用户设置的头像
  Widget _buildDeviceAvatar(Device device, double fontSize) {
      final displayAvatar = device.avatar ?? _getDefaultAvatar(device.name);
      final isEmojiAvatar = displayAvatar.length <= 4 && displayAvatar.runes.length <= 4;

    if (isEmojiAvatar) {
      return Text(displayAvatar, style: TextStyle(fontSize: fontSize));
    } else {
      final provider = _getAvatarProvider(displayAvatar);
      if (provider != null) {
        return ClipOval(
          child: Image(
            image: provider,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Text(_getDefaultAvatar(device.name), style: TextStyle(fontSize: fontSize));
            },
          ),
        );
      } else {
        return Text(_getDefaultAvatar(device.name), style: TextStyle(fontSize: fontSize));
      }
    }
  }
}
