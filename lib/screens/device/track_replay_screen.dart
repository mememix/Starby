// lib/screens/device/track_replay_screen.dart
// 轨迹回放页面 - 基于 track-replay-v1.html 设计规范

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:dio/dio.dart';
import '../../constants/colors.dart';
import '../../models/location.dart';
import '../../utils/trajectory_calibrator.dart';
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
  String selectedSpeed = '1x'; // 显示速度（1x, 2x, 4x, 8x）
  double baseSpeedMultiplier = 4.0; // 内部基准速度倍数（默认4倍速）
  DateTime? selectedDate;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  late String deviceId;
  late List<Location> _originalLocations;
  late List<Location> locations;
  int currentIndex = 0;
  Timer? _playbackTimer;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isTrackInfoExpanded = false;

  // 显示速度到内部速度的映射
  final Map<String, double> _speedMapping = {
    '1x': 4.0,   // 显示1x = 内部4x
    '2x': 8.0,   // 显示2x = 内部8x
    '4x': 16.0,  // 显示4x = 内部16x
    '8x': 32.0,  // 显示8x = 内部32x
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 优先使用构造函数传递的参数，其次使用路由参数
    if (widget.deviceId != null && widget.locations != null) {
      deviceId = widget.deviceId!;
      _originalLocations = widget.locations!;
      // 轨迹校准：过滤掉几乎一致的点位
      locations = TrajectoryCalibrator.calibrate(_originalLocations);
      // 如果有数据，设置selectedDate为第一个位置点的日期
      if (locations.isNotEmpty) {
        selectedDate = locations.first.timestamp;
      }
      // 打印校准统计信息
      if (_originalLocations.length > locations.length) {
        final stats = TrajectoryCalibrator.getCalibrationStats(_originalLocations, locations);
        debugPrint('轨迹校准: 原始${stats['originalCount']}点 → 校准后${stats['calibratedCount']}点 (减少${stats['reduction']}%)');
      }
    } else {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        deviceId = args['deviceId'];
        _originalLocations = args['locations'] as List<Location>;
        // 轨迹校准：过滤掉几乎一致的点位
        locations = TrajectoryCalibrator.calibrate(_originalLocations);
        // 如果有数据，设置selectedDate为第一个位置点的日期
        if (locations.isNotEmpty) {
          selectedDate = locations.first.timestamp;
        }
        // 打印校准统计信息
        if (_originalLocations.length > locations.length) {
          final stats = TrajectoryCalibrator.getCalibrationStats(_originalLocations, locations);
          debugPrint('轨迹校准: 原始${stats['originalCount']}点 → 校准后${stats['calibratedCount']}点 (减少${stats['reduction']}%)');
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

      // 获取选择日期的开始和结束时间（全天数据）
      final start = DateTime(date.year, date.month, date.day);
      final end = start.add(const Duration(days: 1));

      final newLocations = await ApiService().getDeviceHistory(
        deviceId,
        start: start,
        end: end,
        limit: 10000,
      );

      if (mounted) {
        _originalLocations = newLocations;
        // 轨迹校准：过滤掉几乎一致的点位
        locations = TrajectoryCalibrator.calibrate(_originalLocations);
        // 打印校准统计信息
        if (_originalLocations.length > locations.length) {
          final stats = TrajectoryCalibrator.getCalibrationStats(_originalLocations, locations);
          debugPrint('轨迹校准: 原始${stats['originalCount']}点 → 校准后${stats['calibratedCount']}点 (减少${stats['reduction']}%)');
        }
        setState(() {
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
    // 使用第一个位置点作为中心（已经是按时间升序排列）
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

    // 获取实际播放速度倍数（使用映射表）
    double speedMultiplier = _speedMapping[selectedSpeed] ?? 4.0;

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

    // 添加起点标记（第一个位置点，时间最早）
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

    // 添加当前位置标记（播放进度所在位置）
    if (currentIndex > 0 && currentIndex < locations.length) {
      final currentLocation = locations[currentIndex];
      markers.add(Marker(
        id: 'current',
        position: LatLng(currentLocation.lat, currentLocation.lng),
        infoWindow: InfoWindow(
          title: '当前位置',
          snippet: _formatTime(currentLocation.timestamp),
        ),
        isOnline: true,
      ));
    }

    return markers;
  }

  // 获取当前轨迹线
  Set<Polyline> get _currentPolylines {
    if (locations.isEmpty || currentIndex == 0) return {};

    // 从起点到当前位置绘制轨迹
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
            flex: 3,
            child: Column(
              children: [
                _buildTimeSelector(),
                Expanded(child: _buildMapArea()),
              ],
            ),
          ),
          Flexible(
            flex: 2,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildPlaybackControls(),
                  const SizedBox(height: 12),
                  _buildStatistics(),
                  const SizedBox(height: 12),
                  _buildTrackInfo(),
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
                locale: const Locale('zh', 'CN'),
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
        ],
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
      padding: const EdgeInsets.all(16),
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
                    items: const ['1x', '2x', '4x', '8x'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      if (newValue != null) {
                        _pausePlayback();
                        setState(() {
                          selectedSpeed = newValue;
                        });
                      }
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

  // 轨迹信息（可展开收起）
  Widget _buildTrackInfo() {
    if (locations.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        setState(() {
          _isTrackInfoExpanded = !_isTrackInfoExpanded;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        '详细点位',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _isTrackInfoExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // 展开的内容
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: _isTrackInfoExpanded
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.grey[200]!),
                        ),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: locations.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          color: Colors.grey[200],
                        ),
                        itemBuilder: (context, index) {
                          final location = locations[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: index == 0
                                        ? Colors.green
                                        : index == locations.length - 1
                                            ? Colors.red
                                            : AppColors.primary.withValues(alpha: 0.3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    index == 0
                                        ? Icons.play_arrow
                                        : index == locations.length - 1
                                            ? Icons.flag
                                            : Icons.circle,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _formatTime(location.timestamp),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        location.address ??
                                            '${location.lat.toStringAsFixed(4)}, ${location.lng.toStringAsFixed(4)}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  // 轨迹统计
  Widget _buildStatistics() {
    if (locations.isEmpty) return const SizedBox.shrink();

    final duration = locations.last.timestamp.difference(locations.first.timestamp);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              Icons.timer,
              hours > 0 ? '${hours}h${minutes}m' : '${minutes}m',
              '时长',
            ),
          ),
          Expanded(
            child: _buildStatItem(
              Icons.location_on,
              locations.length.toString(),
              '轨迹点',
            ),
          ),
          Expanded(
            child: _buildStatItem(
              Icons.route,
              '0.0',
              '公里',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
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
            color: AppColors.textHint,
          ),
        ),
      ],
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
