// lib/screens/device/partner_detail_screen.dart
// 伙伴详情页

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import '../../constants/colors.dart';
import '../../models/device.dart';
import '../../models/location.dart';
import '../../routes.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../../services/amap_service.dart';
import '../../widgets/map/amap_widget.dart';

class PartnerDetailScreen extends StatefulWidget {
  const PartnerDetailScreen({super.key, this.deviceId});

  final String? deviceId;

  @override
  State<PartnerDetailScreen> createState() => _PartnerDetailScreenState();
}

class _PartnerDetailScreenState extends State<PartnerDetailScreen> {
  bool _isLoading = true;
  bool _isLocationLoading = false;
  String? _errorMessage;
  late String deviceId;
  Device? _device;
  Location? _currentLocation;
  bool _hasLoaded = false; // 防止重复加载
  String? _currentAddress; // 当前地址
  bool _hasShownBatteryAlert = false; // 是否已显示电量告警

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasLoaded) {
      // 优先使用构造函数传递的 deviceId，其次使用路由参数
      final id = widget.deviceId ?? ModalRoute.of(context)?.settings.arguments as String?;
      if (id != null && id.isNotEmpty) {
        deviceId = id;
        _hasLoaded = true;
        // 先加载设备详情，再加载位置信息
        _loadDeviceDetail().then((_) {
          _loadCurrentLocation();
        });
      }
    }
  }

  // 加载设备详情
  Future<void> _loadDeviceDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await StorageService.getAuthToken();
      if (token != null) {
        ApiService().setAuthToken(token);
      }

      final device = await ApiService().getDeviceDetail(deviceId);

      if (mounted) {
        setState(() {
          _device = device;
          _isLoading = false;
        });
        // 检查电量告警
        _checkBatteryAlert();
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.response?.data?['message'] ?? '加载设备详情失败';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '加载设备详情失败: $e';
          _isLoading = false;
        });
      }
    }
  }

  // 加载当前位置
  Future<void> _loadCurrentLocation() async {
    setState(() {
      _isLocationLoading = true;
    });

    try {
      final token = await StorageService.getAuthToken();
      if (token != null) {
        ApiService().setAuthToken(token);
      }

      final location = await ApiService().getDeviceLocation(deviceId);

      // 优先使用位置API的数据，因为它是最准确的最新位置
      Location mergedLocation = location;
      String? finalAddress;

      if (location.lat != 0.0 && location.lng != 0.0) {
        // API返回了有效位置，后端已经应用了坐标纠偏
        debugPrint('[PartnerDetail] 使用位置API的数据: lat=${location.lat}, lng=${location.lng}, addr=${location.address}');

        // 后端API已经应用了坐标纠偏，直接使用
        final finalLat = location.lat;
        final finalLng = location.lng;

        // 调用实时逆地理编码获取地址（与首页保持一致）
        String? realtimeAddress;
        try {
          realtimeAddress = await AmapService.getAddress(
            finalLng,
            finalLat,
          );
          debugPrint('[PartnerDetail] 实时逆地理编码地址: $realtimeAddress');
        } catch (e) {
          debugPrint('[PartnerDetail] 逆地理编码失败: $e');
        }

        // 优先使用实时逆地理编码的地址，如果失败则使用设备表地址
        mergedLocation = Location(
          id: location.id,
          deviceId: deviceId,
          lat: finalLat,
          lng: finalLng,
          address: realtimeAddress ?? _device!.address, // 优先使用实时逆地理编码地址
          accuracy: location.accuracy,
          battery: _device!.battery, // 直接使用设备表的电量
          timestamp: location.timestamp,
          type: location.type,
        );
        finalAddress = mergedLocation.address;
      } else if (_device!.latitude != null && _device!.longitude != null) {
        // API返回无效数据，使用设备表的位置作为后备（设备表坐标已经是GCJ-02，无需纠偏）
        debugPrint('[PartnerDetail] API返回(0,0), 使用设备表位置: lat=${_device!.latitude}, lng=${_device!.longitude}');

        mergedLocation = Location(
          id: _device!.id,
          deviceId: deviceId,
          lat: _device!.latitude!,
          lng: _device!.longitude!,
          address: _device!.address,
          accuracy: null,
          battery: _device!.battery,
          timestamp: _device!.lastUpdate ?? DateTime.now(),
          type: 'gps',
        );
        finalAddress = mergedLocation.address;
      } else {
        debugPrint('[PartnerDetail] 无有效位置数据');
      }

      if (mounted) {
        setState(() {
          _currentLocation = mergedLocation;
          _currentAddress = finalAddress;
          _isLocationLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load location for device $deviceId: $e');
      if (mounted) {
        setState(() {
          _isLocationLoading = false;
        });
      }
    }
  }

  // 获取默认头像emoji
  String _getDefaultAvatar(String deviceName) {
    const avatars = ['🦁', '👶', '🐱', '👴', '👧', '👦', '🐶', '🐼', '🐯', '🦊'];
    final hashCode = deviceName.hashCode;
    return avatars[hashCode % avatars.length];
  }

  // 获取电量颜色（用于其他地方可能需要纯色）
  Color _getBatteryColor(int? battery) {
    debugPrint('[Battery] _getBatteryColor battery=$battery');
    if (battery == null) return Colors.grey;
    if (battery >= 50) return const Color(0xFF4CAF50);
    if (battery >= 20) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  // 获取电量背景色（带透明度）
  Color _getBatteryBackgroundColor(int? battery) {
    debugPrint('[Battery] _getBatteryBackgroundColor battery=$battery');
    if (battery == null) {
      debugPrint('[Battery] 返回灰色(null)');
      return Colors.grey.withValues(alpha: 0.3);
    }
    if (battery >= 50) {
      debugPrint('[Battery] 返回绿色(>=50)');
      return const Color(0xFF2E7D32); // 深绿色,不透明
    }
    if (battery >= 20) {
      debugPrint('[Battery] 返回橙色(20-50)');
      return const Color(0xFFF57C00); // 深橙色,不透明
    }
    debugPrint('[Battery] 返回红色(<20)');
    return const Color(0xFFD32F2F); // 深红色,不透明
  }

  // 获取电量图标
  IconData _getBatteryIcon(int? battery) {
    if (battery == null) return Icons.battery_unknown;
    if (battery >= 50) return Icons.battery_charging_full;
    if (battery >= 20) return Icons.battery_std;
    return Icons.battery_alert;
  }

  // 检查并显示电量告警
  void _checkBatteryAlert() {
    if (_hasShownBatteryAlert) return;

    final battery = _currentLocation?.battery ?? _device?.battery;
    if (battery != null && battery < 20) {
      _hasShownBatteryAlert = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final deviceName = _device?.name ?? '设备';
          final message = battery < 10
              ? '🚨 电量危急！$deviceName电量仅剩$battery%，请立即充电！'
              : '⚠️ 电量偏低！$deviceName电量仅剩$battery%，建议尽快充电。';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: battery < 10 ? Colors.red : Colors.orange,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: '知道了',
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
        }
      });
    }
  }

  // 构建头像Widget
  Widget _buildAvatarWidget() {
    // 如果设备头像为空，使用默认emoji头像
    if (_device == null || _device!.avatar == null || _device!.avatar!.isEmpty) {
      return Text(
        _getDefaultAvatar(_device!.name),
        style: const TextStyle(fontSize: 28),
      );
    }

    final avatarUrl = _device!.avatar!;

    // 检查是否是emoji（长度小于等于4个字符且不包含URL格式）
    final isEmoji = avatarUrl.length <= 4 && !avatarUrl.contains(RegExp(r'^(http|data:)'));
    if (isEmoji) {
      return Text(
        avatarUrl,
        style: const TextStyle(fontSize: 28),
      );
    }

    // 检查是否是base64数据URI
    if (avatarUrl.startsWith('data:image/') && avatarUrl.contains(';base64,')) {
      try {
        final base64Data = avatarUrl.split(';base64,').last;
        if (base64Data.isEmpty) {
          return Text(
            _getDefaultAvatar(_device!.name),
            style: const TextStyle(fontSize: 28),
          );
        }
        final imageBytes = base64Decode(base64Data);
        return ClipOval(
          child: Image.memory(
            imageBytes,
            fit: BoxFit.cover,
            width: 64,
            height: 64,
            errorBuilder: (context, error, stackTrace) {
              return Text(
                _getDefaultAvatar(_device!.name),
                style: const TextStyle(fontSize: 28),
              );
            },
          ),
        );
      } catch (e) {
        // 解码失败，显示默认头像
        debugPrint('[PartnerDetail] 解码base64头像失败: $e');
        return Text(
          _getDefaultAvatar(_device!.name),
          style: const TextStyle(fontSize: 28),
        );
      }
    }

    // 网络图片URL
    return ClipOval(
      child: Image.network(
        avatarUrl,
        fit: BoxFit.cover,
        width: 64,
        height: 64,
        errorBuilder: (context, error, stackTrace) {
          return Text(
            _getDefaultAvatar(_device!.name),
            style: const TextStyle(fontSize: 28),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFE797A2), Color(0xFFF5B5BD)],
            ),
          ),
          child: const Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      );
    }

    if (_errorMessage != null || _device == null) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFE797A2), Color(0xFFF5B5BD)],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _errorMessage ?? '设备不存在',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadDeviceDetail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFE797A2),
                  ),
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          // 顶部伙伴信息区
          _buildHeader(),
          // 地图区域
          Expanded(
            child: _buildMapArea(),
          ),
          // 底部功能按钮
          _buildActionButtons(),
        ],
      ),
    );
  }

  // 顶部伙伴信息区
  Widget _buildHeader() {
    // 打印调试信息
    debugPrint('========== 设备详情页调试信息 ==========');
    debugPrint('设备对象位置 - lat: ${_device?.latitude}, lng: ${_device?.longitude}, address: ${_device?.address}');
    debugPrint('_currentLocation 位置: ${_currentLocation != null ? "有" : "无"}');
    if (_currentLocation != null) {
      debugPrint('  - lat: ${_currentLocation!.lat}');
      debugPrint('  - lng: ${_currentLocation!.lng}');
      debugPrint('  - address: ${_currentLocation!.address}');
      debugPrint('  - battery: ${_currentLocation!.battery}');
      debugPrint('  - timestamp: ${_currentLocation!.timestamp}');
    }
    debugPrint('_currentAddress: $_currentAddress');
    debugPrint('================================');

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE797A2), // 品牌主色
            Color(0xFFF5B5BD), // 浅粉
          ],
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 20,
      ),
      child: Column(
        children: [
          // 导航栏
          Row(
            children: [
              IconButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const Expanded(
                child: Text(
                  '伙伴详情',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              PopupMenuButton(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'share',
                    child: Text('分享伙伴'),
                  ),
                  const PopupMenuItem(
                    value: 'unbind',
                    child: Text(
                      '解除绑定',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
                onSelected: (value) async {
                  if (value == 'share') {
                    _sharePartner();
                  } else if (value == 'unbind') {
                    await _showUnbindDialog();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          // 伙伴信息
          Row(
            children: [
              // 伙伴头像
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.2),
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: _buildAvatarWidget(),
              ),
              const SizedBox(width: 16),
              // 伙伴名称和状态
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _device!.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // 在线状态和电量并列显示
                    Row(
                      children: [
                        // 在线状态
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _device!.isOnline ? Colors.green : Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _device!.isOnline ? '在线' : '离线',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        // 电量显示（仅在线时显示）
                        if (_device!.isOnline && (_currentLocation?.battery != null || _device?.battery != null))
                          Builder(
                            builder: (context) {
                              final batteryValue = _currentLocation?.battery ?? _device?.battery;
                              debugPrint('[Battery] UI显示: batteryValue=$batteryValue, _currentLocation.battery=${_currentLocation?.battery}, _device.battery=${_device?.battery}');
                              return Row(
                                children: [
                                  const SizedBox(width: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getBatteryBackgroundColor(batteryValue),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _getBatteryIcon(batteryValue),
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${batteryValue ?? '--'}%',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          )
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 位置信息（单独占满一行）
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _currentAddress ?? '等待位置更新',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
      child: Stack(
        children: [
          AMapWidget(
            initialCameraPosition: LatLng(lat, lng),
            markers: {
              Marker(
                id: 'partner_${_device!.id}',
                position: LatLng(lat, lng),
                infoWindow: InfoWindow(title: _device!.name),
                isOnline: _device!.isOnline,
                avatar: _device!.avatar,
                battery: _device!.battery,
                lastUpdate: _currentLocation?.timestamp ?? _device!.lastUpdate,
              ),
            },
            myLocationEnabled: false,
          ),
          // 定位按钮
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.small(
              onPressed: _loadCurrentLocation,
              backgroundColor: Colors.white,
              child: _isLocationLoading
                  ? const CircularProgressIndicator(color: Color(0xFFE797A2))
                  : const Icon(Icons.my_location, color: Color(0xFFE797A2)),
            ),
          ),
        ],
      ),
    );
  }

  // 底部功能按钮
  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
          children: [
            // 历史轨迹
            Expanded(
              child: _buildActionButton(
                Icons.history,
                '历史轨迹',
                () {
                  Navigator.pushNamed(context, AppRoutes.history, arguments: deviceId);
                },
              ),
            ),
            // 电子围栏
            Expanded(
              child: _buildActionButton(
                Icons.roundabout_right,
                '电子围栏',
                () {
                  Navigator.pushNamed(context, AppRoutes.fence, arguments: deviceId);
                },
              ),
            ),
            // 实时追踪
            Expanded(
              child: _buildActionButton(
                Icons.play_arrow,
                '实时追踪',
                () {
                  Navigator.pushNamed(context, AppRoutes.deviceRealtime, arguments: deviceId);
                },
              ),
            ),
            // 伙伴设置
            Expanded(
              child: _buildActionButton(
                Icons.settings,
                '伙伴设置',
                () {
                  Navigator.pushNamed(context, AppRoutes.deviceSettings, arguments: deviceId)
                      .then((_) {
                    _loadDeviceDetail();
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFE797A2),
              size: 22,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // 分享伙伴
  Future<void> _sharePartner() async {
    try {
      final deviceName = _device?.name ?? '未知设备';
      final shareText = '我在使用Starby守护家人安全，$deviceName的实时位置可以随时查看。\n\n快来加入我们吧！\n\n下载链接：https://example.com/download';

      await Share.share(
        shareText,
        subject: '邀请您使用Starby',
      );
    } catch (e) {
      debugPrint('[PartnerDetailScreen] 分享失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败: ${e.toString()}')),
        );
      }
    }
  }

  // 显示解除绑定对话框
  Future<void> _showUnbindDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('解除绑定'),
        content: Text('确定要解除与"${_device?.name ?? '该设备'}"的绑定吗？\n\n解除后您将无法查看该设备的位置信息。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('解除绑定'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      await _unbindDevice();
    }
  }

  // 解除设备绑定
  Future<void> _unbindDevice() async {
    try {
      // 显示加载提示
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      final token = await StorageService.getAuthToken();
      if (token != null) {
        ApiService().setAuthToken(token);
      }

      await ApiService().unbindDevice(deviceId);

      // 关闭加载对话框
      if (mounted) {
        Navigator.pop(context);
      }

      // 显示成功提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已成功解除绑定')),
        );
      }

      // 返回上一页
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      // 关闭加载对话框
      if (mounted) {
        Navigator.pop(context);
      }

      // 显示错误提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('解除绑定失败: ${e.toString()}')),
        );
      }
    }
  }
}
