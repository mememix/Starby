// lib/screens/device/track_replay_screen.dart
// 轨迹回放页面 - 基于 track-replay-v1.html 设计规范

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../constants/colors.dart';
import '../../models/location.dart';
import '../../widgets/map/amap_widget.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';

class TrackReplayScreen extends StatefulWidget {
  const TrackReplayScreen({super.key, this.deviceId, this.locations});

  final String? deviceId;
  final List<Location>? locations;

  @override
  State<TrackReplayScreen> createState() => _TrackReplayScreenState();
}

class _TrackReplayScreenState extends State<TrackReplayScreen> {
  bool isPlaying = false;
  double progress = 0.0;
  String selectedSpeed = '1x';
  DateTime? selectedDate;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  late String deviceId;
  late List<Location> locations;
  int currentIndex = 0;
  Timer? _playbackTimer;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 优先使用构造函数传递的参数，其次使用路由参数
    if (widget.deviceId != null && widget.locations != null) {
      deviceId = widget.deviceId!;
      locations = widget.locations!;
      // 如果有数据，设置selectedDate为第一个位置点的日期
      if (locations.isNotEmpty) {
        selectedDate = locations.first.timestamp;
      }
    } else {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        deviceId = args['deviceId'];
        locations = args['locations'] as List<Location>;
        // 如果有数据，设置selectedDate为第一个位置点的日期
        if (locations.isNotEmpty) {
          selectedDate = locations.first.timestamp;
        }
      }
    }
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  // 加载指定日期的历史轨迹
  Future<void> _loadHistoryForDate(DateTime date) async {
    if (deviceId.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await StorageService.getAuthToken();
      if (token != null) {
        ApiService().setAuthToken(token);
      }

      // 获取选择日期的开始和结束时间
      final start = DateTime(date.year, date.month, date.day);
      final end = start.add(const Duration(days: 1));

      final newLocations = await ApiService().getDeviceHistory(
        deviceId,
        start: start,
        end: end,
        limit: 1000,
      );

      if (mounted) {
        setState(() {
          locations = newLocations;
          currentIndex = 0;
          progress = 0.0;
          _isLoading = false;
          selectedDate = date;
        });
      }
    } on DioException catch (e) {
      debugPrint('加载历史轨迹失败 (DioException): ${e.response?.data}');
      if (mounted) {
        setState(() {
          _errorMessage = e.response?.data?['message'] ?? '加载历史轨迹失败';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('加载历史轨迹失败 (Exception): $e');
      if (mounted) {
        setState(() {
          _errorMessage = '加载历史轨迹失败: $e';
          _isLoading = false;
        });
      }
    }
  }

  // 获取地图中心点（设备的初始位置）
  LatLng get _mapCenter {
    if (locations.isEmpty) {
      return const LatLng(39.909187, 116.397451); // 默认北京
    }
    // 使用第一个位置点作为中心
    return LatLng(locations.first.lat, locations.first.lng);
  }

  // 移动地图到当前位置
  void _moveMapToCurrentLocation() {
    if (currentIndex > 0 && currentIndex < locations.length) {
      // TODO: 使用mapController移动地图中心
      // _mapController.moveCamera(CameraUpdate.newLatLng(
      //   LatLng(locations[currentIndex].lat, locations[currentIndex].lng),
      // ));
    }
  }

  // 开始播放
  void _startPlayback() {
    if (locations.isEmpty) return;
    if (isPlaying) return;

    setState(() => isPlaying = true);

    // 获取速度倍数
    double speedMultiplier = double.parse(selectedSpeed.replaceAll('x', ''));

    // 计算播放间隔
    int intervalMs = (1000 / speedMultiplier).round();

    _playbackTimer = Timer.periodic(
      Duration(milliseconds: intervalMs),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (currentIndex < locations.length - 1) {
          setState(() {
            currentIndex++;
            progress = currentIndex / (locations.length - 1);
          });
          // 移动地图到当前位置
          _moveMapToCurrentLocation();
        } else {
          timer.cancel();
          setState(() {
            isPlaying = false;
          });
        }
      },
    );
  }

  // 暂停播放
  void _pausePlayback() {
    _playbackTimer?.cancel();
    setState(() => isPlaying = false);
  }

  // 获取当前标记
  Set<Marker> get _currentMarkers {
    final markers = <Marker>{};

    if (locations.isEmpty) return markers;

    // 添加起点和终点标记
    if (locations.isNotEmpty) {
      final startLocation = locations.first;
      markers.add(Marker(
        id: 'start',
        position: LatLng(startLocation.lat, startLocation.lng),
        infoWindow: InfoWindow(
          title: '起点',
          snippet: _formatTime(startLocation.timestamp),
        ),
        isOnline: true,
      ));
    }

    // 添加终点标记
    if (currentIndex > 0 && currentIndex < locations.length) {
      final endLocation = locations[currentIndex];
      markers.add(Marker(
        id: 'current',
        position: LatLng(endLocation.lat, endLocation.lng),
        infoWindow: InfoWindow(
          title: '当前位置',
          snippet: _formatTime(endLocation.timestamp),
        ),
        isOnline: true,
      ));
    }

    return markers;
  }

  // 获取当前轨迹线
  Set<Polyline> get _currentPolylines {
    if (locations.isEmpty || currentIndex == 0) return {};

    final points = locations
        .take(currentIndex + 1)
        .map((l) => LatLng(l.lat, l.lng))
        .toList();

    // 返回两条线：黑色边框和粉色主线
    return {
      // 黑色边框线（更宽）
      Polyline(
        id: 'track_border',
        points: points,
        color: Colors.black,
        width: 8,
      ),
      // 粉色主线
      Polyline(
        id: 'track',
        points: points,
        color: const Color(0xFFF5C6CB),
        width: 4,
      ),
    };
  }

  // 格式化时间
  String _formatTime(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildTimeSelector(),
                  _buildMapArea(),
                  _buildPlaybackControls(),
                  _buildTrackInfo(),
                  _buildStatistics(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 顶部导航栏
  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(
                Icons.chevron_left,
                size: 24,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const Text(
            '轨迹回放',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          GestureDetector(
            onTap: () {
              // TODO: 分享轨迹
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('分享轨迹')),
              );
            },
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(
                Icons.share,
                size: 20,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 时间选择器
  Widget _buildTimeSelector() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 日期选择
          const Text(
            '选择日期',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate ?? DateTime.now(),
                firstDate: DateTime.now().subtract(const Duration(days: 90)),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                // 重新加载该日期的轨迹数据
                await _loadHistoryForDate(picked);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[200]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_isLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Text(
                      selectedDate != null
                          ? '${selectedDate!.year}年${selectedDate!.month}月${selectedDate!.day}日'
                          : '请选择日期',
                      style: TextStyle(
                        fontSize: 15,
                        color: selectedDate != null
                            ? AppColors.textPrimary
                            : AppColors.textHint,
                      ),
                    ),
                  const Icon(
                    Icons.calendar_today,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 快速选择
          Wrap(
            spacing: 8,
            children: [
              _buildQuickTimeBtn('今天', false, () => _loadHistoryForDate(DateTime.now())),
              _buildQuickTimeBtn('昨天', false, () => _loadHistoryForDate(DateTime.now().subtract(const Duration(days: 1)))),
              _buildQuickTimeBtn('近7天', true, () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请选择具体日期')),
                );
              }),
              _buildQuickTimeBtn('近30天', false, () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请选择具体日期')),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickTimeBtn(String text, bool isActive, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: isActive ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  // 地图区域
  Widget _buildMapArea() {
    if (_isLoading) {
      return Container(
        height: 350,
        color: Colors.white,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        height: 350,
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
                onPressed: () {
                  if (selectedDate != null) {
                    _loadHistoryForDate(selectedDate!);
                  }
                },
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    if (locations.isEmpty) {
      return Container(
        height: 350,
        color: Colors.white,
        child: const Center(
          child: Text('暂无轨迹数据\n请选择其他日期查看'),
        ),
      );
    }

    // 使用初始位置作为地图中心点
    final centerPosition = _mapCenter;

    return Container(
      height: 350,
      color: Colors.white,
      child: Stack(
        children: [
          // 使用真实地图
          Positioned.fill(
            child: AMapWidget(
              initialCameraPosition: centerPosition,
              markers: _currentMarkers,
              polylines: _currentPolylines,
              myLocationEnabled: false,
            ),
          ),
          // 地图控制按钮
          Positioned(
            right: 12,
            bottom: 80,
            child: Column(
              children: [
                _buildMapControlBtn(Icons.add),
                const SizedBox(height: 8),
                _buildMapControlBtn(Icons.remove),
                const SizedBox(height: 8),
                _buildMapControlBtn(Icons.my_location),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapControlBtn(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, size: 18, color: AppColors.textSecondary),
    );
  }

  // 播放控制
  Widget _buildPlaybackControls() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 进度条
          SliderTheme(
            data: const SliderThemeData(
              trackHeight: 4,
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: progress,
              onChanged: (value) {
                _pausePlayback();
                setState(() {
                  progress = value;
                  currentIndex = (value * (locations.length - 1)).round();
                });
              },
              activeColor: AppColors.primary,
              inactiveColor: Colors.grey[200],
            ),
          ),
          const SizedBox(height: 8),
          // 时间显示
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (locations.isNotEmpty)
                Text(
                  _formatTime(locations.first.timestamp),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint,
                  ),
                )
              else
                const Text(''),
              if (locations.isNotEmpty && currentIndex < locations.length)
                Text(
                  _formatTime(locations[currentIndex].timestamp),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint,
                  ),
                )
              else
                const Text(''),
              if (locations.isNotEmpty)
                Text(
                  _formatTime(locations.last.timestamp),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint,
                  ),
                )
              else
                const Text(''),
            ],
          ),
          const SizedBox(height: 16),
          // 控制按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () {
                  // 后退10个点
                  if (currentIndex > 0) {
                    _pausePlayback();
                    setState(() {
                      currentIndex = (currentIndex - 10).clamp(0, locations.length - 1);
                      progress = currentIndex / (locations.length - 1);
                    });
                  }
                },
                icon: const Icon(Icons.fast_rewind),
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 24),
              GestureDetector(
                onTap: () {
                  if (isPlaying) {
                    _pausePlayback();
                  } else {
                    _startPlayback();
                  }
                },
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 24),
              IconButton(
                onPressed: () {
                  // 快进10个点
                  if (currentIndex < locations.length - 1) {
                    _pausePlayback();
                    setState(() {
                      currentIndex = (currentIndex + 10).clamp(0, locations.length - 1);
                      progress = currentIndex / (locations.length - 1);
                    });
                  }
                },
                icon: const Icon(Icons.fast_forward),
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 24),
              // 速度选择
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedSpeed,
                    icon: const Icon(Icons.arrow_drop_down, size: 18),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                    items: ['1x', '2x', '4x', '8x'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      _pausePlayback();
                      setState(() {
                        selectedSpeed = newValue!;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 轨迹点信息
  Widget _buildTrackInfo() {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '轨迹点信息',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () {
                  // TODO: 展开全部
                },
                child: const Text(
                  '展开全部',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...locations.map((point) => _buildTrackPointCard(point)),
        ],
      ),
    );
  }

  Widget _buildTrackPointCard(Location point) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on,
              size: 14,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatTime(point.timestamp),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        point.address ?? '${point.lat.toStringAsFixed(6)}, ${point.lng.toStringAsFixed(6)}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 12,
                      color: AppColors.textHint,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${point.lat.toStringAsFixed(6)}, ${point.lng.toStringAsFixed(6)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 轨迹统计
  Widget _buildStatistics() {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '轨迹统计',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  Icons.route,
                  '28.5',
                  '总里程(km)',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  Icons.hourglass_bottom,
                  '10h',
                  '总时长',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  Icons.speed,
                  '65',
                  '最高速度(km/h)',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
              icon,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }
}

// 网格背景绘制器
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE0E8EC)
      ..strokeWidth = 1;

    const gridSize = 32.0;

    for (double i = 0; i < size.width; i += gridSize) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }

    for (double i = 0; i < size.height; i += gridSize) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// 轨迹路径绘制器
class TrackPathPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF5C6CB)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(size.width * 0.1, size.height * 0.5);
    path.lineTo(size.width * 0.3, size.height * 0.5);
    path.lineTo(size.width * 0.5, size.height * 0.3);
    path.lineTo(size.width * 0.7, size.height * 0.5);
    path.lineTo(size.width * 0.9, size.height * 0.7);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
