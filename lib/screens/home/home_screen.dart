// lib/screens/home/home_screen.dart
// 首页 - 经典版

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../constants/colors.dart';
import '../../models/device.dart';
import '../../models/location.dart';
import '../../routes.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../../services/amap_service.dart';
import '../../widgets/map/amap_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _isLoading = true;
  List<Device> _devices = [];
  Map<String, Location> _deviceLocations = {};
  final Map<String, String> _realtimeAddresses = {}; // 存储实时地址
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
        debugPrint('[HomeScreen] 解析base64头像失败: $e');
        return null;
      }
    } else {
      // 如果是相对路径（以 /uploads/ 开头），拼接服务器地址
      String finalUrl = avatarUrl;
      if (avatarUrl.startsWith('/uploads/')) {
        // 获取API基础URL（静态属性）
        final baseUrl = ApiService.baseUrl;
        // 移除baseUrl末尾的 /api 部分
        final serverUrl = baseUrl.replaceAll(RegExp(r'/api$'), '');
        // 去除重复的uploads/remote/前缀
        if (avatarUrl.contains('/uploads/remote/uploads/remote/')) {
          finalUrl = avatarUrl.replaceAll('/uploads/remote/uploads/remote/', '/uploads/remote/');
        }
        finalUrl = '$serverUrl$finalUrl';
        debugPrint('[HomeScreen] 拼接头像URL: $finalUrl');
      }

      // 如果是普通的网络URL，使用NetworkImage
      return NetworkImage(finalUrl);
    }
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
      debugPrint('[HomeScreen] Got token from storage: $tokenPreview');

      if (token == null || token.isEmpty) {
        // Token不存在，跳转到登录页
        debugPrint('[HomeScreen] No token, redirect to login');
        await StorageService.setLoggedIn(false);
        if (mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.login);
        }
        return;
      }

      ApiService().setAuthToken(token);
      final devices = await ApiService().getDevices();
      debugPrint('[HomeScreen] Loaded ${devices.length} devices');

      // 直接使用设备对象中的位置信息（后端已进行坐标转换）
      Map<String, Location> locations = {};
      for (final device in devices) {
        debugPrint('[HomeScreen] 检查设备 ${device.name} (ID: ${device.id}): lat=${device.latitude}, lng=${device.longitude}');
        if (device.latitude != null && device.longitude != null) {
          // 注意：后端API已经对坐标进行了转换（WGS-84 -> GCJ-02 + 统一偏移）
          // 前端直接使用后端返回的坐标，不再进行二次转换
          final finalLat = device.latitude!;
          final finalLng = device.longitude!;

          // 设备有位置数据，使用设备对象中的位置
          locations[device.id] = Location(
            id: device.id,
            deviceId: device.id,
            lat: finalLat,
            lng: finalLng,
            address: device.address, // 这里保留原始地址作为后备
            accuracy: null,
            battery: device.battery,
            timestamp: device.lastUpdate ?? DateTime.now(),
            type: 'gps',
          );
          debugPrint('[HomeScreen] Device ${device.name} (${device.id}): 使用后端转换后坐标 lat=$finalLat, lng=$finalLng, addr=${device.address}');
        } else {
          debugPrint('[HomeScreen] Device ${device.name} (${device.id}): No location data (lat=${device.latitude}, lng=${device.longitude})');
        }
      }

      if (mounted) {
        setState(() {
          _devices = devices;
          _deviceLocations = locations;
          _isLoading = false;
        });
        
        // 加载完设备列表后,异步获取实时地址
        _loadRealtimeAddresses();
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

  // 加载实时地址(逆地理编码)
  Future<void> _loadRealtimeAddresses() async {
    for (final device in _devices) {
      if (device.latitude != null && device.longitude != null) {
        try {
          debugPrint('[HomeScreen] 处理设备 ${device.name} (ID: ${device.id})');
          debugPrint('[HomeScreen] 后端转换后坐标: ${device.latitude}, ${device.longitude}');

          // 注意：后端API已经对坐标进行了转换
          // 前端直接使用后端返回的坐标进行逆地理编码，不再进行二次转换
          final finalLat = device.latitude!;
          final finalLng = device.longitude!;

          debugPrint('[HomeScreen] 逆地理编码使用坐标: $finalLat, $finalLng');

          // 使用后端转换后的坐标进行逆地理编码
          final address = await AmapService.getAddress(
            finalLng,
            finalLat,
          );
          if (address != null && mounted) {
            setState(() {
              _realtimeAddresses[device.id] = address;
            });
            debugPrint('[HomeScreen] 实时地址 ${device.name}: $address');
          }
        } catch (e) {
          debugPrint('[HomeScreen] 获取实时地址失败 ${device.name}: $e');
        }
      }
    }
  }

  // 获取默认头像emoji
  String _getDefaultAvatar(String deviceName) {
    const avatars = ['🦁', '👶', '🐱', '👴', '👧', '👦', '🐶', '🐼', '🐯', '🦊'];
    final hashCode = deviceName.hashCode;
    return avatars[hashCode % avatars.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(flex: 2, child: _buildMapArea()),
          _buildDeviceList(),
          _buildBottomNav(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, Color(0xFFF0B0B8)],
        ),
      ),
      child: SafeArea(
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 40),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star, color: Colors.white, size: 24),
                  SizedBox(width: 8),
                  Text(
                    '星护伙伴',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, AppRoutes.deviceBind).then((_) => _loadDevices()),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapArea() {
    // 优先使用第一个设备的位置作为地图中心
    LatLng? centerPosition;
    if (_devices.isNotEmpty) {
      final firstDevice = _devices.first;
      final location = _deviceLocations[firstDevice.id];
      if (location != null && location.lat != 0.0 && location.lng != 0.0) {
        centerPosition = LatLng(location.lat, location.lng);
        debugPrint('[MapArea] 使用第一个设备(${firstDevice.name})的位置作为地图中心: ${location.lat}, ${location.lng}');
      } else if (firstDevice.latitude != null && firstDevice.longitude != null) {
        centerPosition = LatLng(firstDevice.latitude!, firstDevice.longitude!);
        debugPrint('[MapArea] 使用第一个设备(${firstDevice.name})的原始位置作为地图中心: ${firstDevice.latitude}, ${firstDevice.longitude}');
      }
    }

    // 收集所有有效位置（包括设备对象中的位置）
    List<LatLng> validPositions = [];

    for (final device in _devices) {
      final location = _deviceLocations[device.id];
      if (location != null && location.lat != 0.0 && location.lng != 0.0) {
        validPositions.add(LatLng(location.lat, location.lng));
      } else if (device.latitude != null && device.longitude != null) {
        validPositions.add(LatLng(device.latitude!, device.longitude!));
      }
    }

    // 创建设备标记点
    final markers = <Marker>{};
    debugPrint('========== 地图标记点调试信息 ==========');
    for (final device in _devices) {
      final location = _deviceLocations[device.id];
      LatLng? position;
      DateTime? lastUpdate;

      debugPrint('设备: ${device.name} (ID: ${device.id})');

      if (location != null && location.lat != 0.0 && location.lng != 0.0) {
        position = LatLng(location.lat, location.lng);
        lastUpdate = location.timestamp;
        debugPrint('  使用 _deviceLocations 位置: ${location.lat}, ${location.lng}');
      } else if (device.latitude != null && device.longitude != null) {
        position = LatLng(device.latitude!, device.longitude!);
        lastUpdate = device.lastUpdate;
        debugPrint('  使用 device 对象位置: ${device.latitude}, ${device.longitude}');
      } else {
        debugPrint('  无有效位置');
      }

      if (position != null) {
        debugPrint('  标记位置: ${position.latitude}, ${position.longitude}');
        markers.add(Marker(
          id: 'device_${device.id}',
          position: position,
          infoWindow: InfoWindow(title: device.name),
          isOnline: device.isOnline,
          avatar: device.avatar,
          battery: device.battery,
          lastUpdate: lastUpdate,
        ));
      }
    }
    debugPrint('================================');
    debugPrint('[MapArea] 传递给地图的 centerPosition: $centerPosition');
    if (centerPosition != null) {
      debugPrint('[MapArea] centerPosition lat: ${centerPosition.latitude}, lng: ${centerPosition.longitude}');
    }

    return SizedBox(
      width: double.infinity,
      child: Stack(
        children: [
          AMapWidget(
            key: ValueKey('map_${centerPosition?.latitude}_${centerPosition?.longitude}'),
            initialCameraPosition: centerPosition,
            markers: markers,
            myLocationEnabled: false,
          ),
          // 添加设备按钮 - 右上角（与沉浸版一致，考虑安全区域）
          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 16,
            child: GestureDetector(
              onTap: () => Navigator.pushNamed(context, AppRoutes.deviceBind).then((_) => _loadDevices()),
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
          ),
          // 刷新按钮 - 右下角
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.small(
              heroTag: 'refresh_map',
              onPressed: _isLoading ? null : _loadDevices,
              backgroundColor: Colors.white,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : const Icon(Icons.refresh, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList() {
    if (_isLoading) {
      return Container(
        height: 280,
        color: Colors.white,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Container(
        height: 280,
        color: Colors.white,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadDevices,
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('我的伙伴', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                Text('${_devices.length}个伙伴', style: const TextStyle(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (_devices.isEmpty)
            SizedBox(
              height: 280, // 空状态固定高度（相当于约3台设备）
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.device_unknown, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      '还没有绑定任何伙伴\n点击右上角 + 号添加伙伴',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            )
          else
            RefreshIndicator(
              onRefresh: _loadDevices,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: 200,  // 最低高度（约2台设备）
                  maxHeight: 300, // 最高高度（约3台设备：74*3 + 间距）
                ),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _devices.length,
                  shrinkWrap: true,  // 允许ListView适应内容
                  physics: const AlwaysScrollableScrollPhysics(),  // 确保可以滚动
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final device = _devices[index];
                    return _buildDeviceCard(device);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(Device device) {
    final location = _deviceLocations[device.id];

    // 打印调试信息
    debugPrint('========== 设备卡片调试信息 ==========');
    debugPrint('设备: ${device.name} (ID: ${device.id})');
    debugPrint('设备对象地址: ${device.address ?? "无"}');
    debugPrint('实时逆地理编码地址: ${_realtimeAddresses[device.id] ?? "无"}');
    if (location != null) {
      debugPrint('位置API经纬度: ${location.lat}, ${location.lng}');
    }
    debugPrint('================================');

    // 优先使用用户设置的头像，其次使用默认emoji
      final displayAvatar = device.avatar ?? _getDefaultAvatar(device.name);
      final isEmojiAvatar = displayAvatar.length <= 4 && displayAvatar.runes.length <= 4;

    // 使用实时逆地理编码的地址（不依赖后端的address字段）
    String locationText;

    if (_realtimeAddresses[device.id] != null) {
      // 优先使用实时逆地理编码地址
      locationText = _realtimeAddresses[device.id]!;
    } else if (device.latitude != null && device.longitude != null) {
      // 等待实时逆地理编码完成
      locationText = '获取地址中...';
    } else {
      locationText = '等待位置更新';
    }

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.deviceDetail, arguments: device.id).then((_) => _loadDevices()),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF5F5F5)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: device.isOnline ? const Color(0xFFE797A2) : Colors.grey, width: 2),
              ),
              child: ClipOval(
                child: isEmojiAvatar
                    ? Center(child: Text(displayAvatar, style: const TextStyle(fontSize: 24)))
                    : _getAvatarProvider(displayAvatar) != null
                        ? Image(
                            image: _getAvatarProvider(displayAvatar)!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(child: Text(_getDefaultAvatar(device.name), style: const TextStyle(fontSize: 24)));
                            },
                          )
                        : Center(child: Text(_getDefaultAvatar(device.name), style: const TextStyle(fontSize: 24))),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 第一行：名称（不折行，超过显示...）
                  Text(
                    device.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // 第二行：位置（字体适当调大）
                  Text(
                    locationText,
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home_outlined, '首页', 0),
            _buildNavItem(Icons.message, '消息', 1),
            _buildNavItem(Icons.person_outline, '我的', 2),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedIndex = index);
        if (index == 1) {
          Navigator.pushNamed(context, AppRoutes.message);
        }
        if (index == 2) {
          Navigator.pushNamed(context, AppRoutes.profile);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 24,
            color: isSelected ? AppColors.primary : Colors.grey[400],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isSelected ? AppColors.primary : Colors.grey[400],
            ),
          ),
        ],
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
}
