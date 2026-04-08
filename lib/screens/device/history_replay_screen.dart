// lib/screens/device/history_replay_screen.dart
// 轨迹回放页面

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import '../../constants/colors.dart';
import '../../models/location.dart';
import '../../utils/trajectory_calibrator.dart';

class HistoryReplayScreen extends StatefulWidget {
  const HistoryReplayScreen({super.key});

  @override
  State<HistoryReplayScreen> createState() => _HistoryReplayScreenState();
}

class _HistoryReplayScreenState extends State<HistoryReplayScreen> {
  bool _isPlaying = false;
  double _playbackSpeed = 1.0;
  double _currentProgress = 0.0;
  Timer? _playbackTimer;
  List<Location> _locations = [];
  int _currentIndex = 0;
  final GlobalKey _mapKey = GlobalKey();
  String? _deviceId;
  bool _isTrackInfoExpanded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 获取路由参数
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      final originalLocations = args['locations'] as List<Location>? ?? [];
      // 轨迹校准：过滤掉几乎一致的点位
      _locations = TrajectoryCalibrator.calibrate(originalLocations);
      _deviceId = args['deviceId'] as String?;
      
      // 打印校准统计信息
      if (originalLocations.length > _locations.length) {
        final stats = TrajectoryCalibrator.getCalibrationStats(originalLocations, _locations);
        debugPrint('轨迹校准: 原始${stats['originalCount']}点 → 校准后${stats['calibratedCount']}点 (减少${stats['reduction']}%)');
      }
    }
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  // 播放轨迹
  void _startPlayback() {
    if (_locations.isEmpty) return;

    setState(() => _isPlaying = true);

    _playbackTimer = Timer.periodic(
      Duration(milliseconds: (1000 / _playbackSpeed).round()),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (_currentIndex < _locations.length - 1) {
          setState(() {
            _currentIndex++;
            _currentProgress = _currentIndex / (_locations.length - 1);
          });
        } else {
          timer.cancel();
          setState(() => _isPlaying = false);
        }
      },
    );
  }

  // 暂停播放
  void _pausePlayback() {
    _playbackTimer?.cancel();
    setState(() => _isPlaying = false);
  }

  // 获取当前位置
  Location? get _currentLocation {
    if (_locations.isEmpty || _currentIndex >= _locations.length) {
      return null;
    }
    return _locations[_currentIndex];
  }

  // 获取地图中心点
  LatLng? get _mapCenter {
    if (_currentLocation == null) return null;
    return LatLng(_currentLocation!.lat, _currentLocation!.lng);
  }

  // 获取轨迹线
  List<LatLng> get _polylinePoints {
    return _locations
        .take(_currentIndex + 1)
        .map((loc) => LatLng(loc.lat, loc.lng))
        .toList();
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
            child: _buildMapArea(),
          ),
          Flexible(
            flex: 2,
            child: _buildPlaybackControl(),
          ),
        ],
      ),
    );
  }

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
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, size: 24, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Center(
              child: Text(
                '轨迹回放',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          // 分享按钮
          if (_locations.isNotEmpty)
            GestureDetector(
              onTap: _shareTrajectory,
              child: Container(
                padding: const EdgeInsets.all(8),
                child: const Icon(
                  Icons.share,
                  size: 24,
                  color: AppColors.primary,
                ),
              ),
            )
          else
            const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildMapArea() {
    if (_locations.isEmpty) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE8F4F8), Color(0xFFD4E9F0)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.map_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                '没有轨迹数据\n请先选择日期查看轨迹',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: RepaintBoundary(
          key: _mapKey,
          child: FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(39.909187, 116.397451),
              initialZoom: 15.0,
              minZoom: 3.0,
              maxZoom: 18.0,
            ),
            children: [
              // 高德地图瓦片
              TileLayer(
                urlTemplate: 'http://webrd01.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}',
                userAgentPackageName: 'com.xinghu.xinghu_app',
              ),
              // 轨迹线
              if (_polylinePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _polylinePoints,
                      strokeWidth: 4.0,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              // 当前位置标记
              if (_currentLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(_currentLocation!.lat, _currentLocation!.lng),
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.navigation,
                          color: Colors.white,
                          size: 20,
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

  Widget _buildPlaybackControl() {
    if (_locations.isEmpty) {
      return Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).padding.bottom + 24,
          top: 20,
        ),
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
        child: const Center(
          child: Text('没有轨迹数据'),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 24,
        top: 20,
      ),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 进度信息
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '当前位置: ${_currentIndex + 1}/${_locations.length}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              if (_currentLocation != null)
                Text(
                  _formatTime(_currentLocation!.timestamp),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // 进度条
          Slider(
            value: _currentProgress,
            onChanged: (value) {
              setState(() {
                _currentProgress = value;
                _currentIndex = (value * (_locations.length - 1)).round();
                _pausePlayback();
              });
            },
            activeColor: AppColors.primary,
            inactiveColor: Colors.grey[200],
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('开始', style: TextStyle(fontSize: 12, color: AppColors.textHint)),
              Text('结束', style: TextStyle(fontSize: 12, color: AppColors.textHint)),
            ],
          ),
          const SizedBox(height: 16),
          // 播放速度
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '播放速度: ${_playbackSpeed}x',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Slider(
                value: _playbackSpeed,
                min: 0.5,
                max: 4.0,
                divisions: 7,
                label: '${_playbackSpeed}x',
                onChanged: (value) {
                  setState(() {
                    _playbackSpeed = double.parse(value.toStringAsFixed(1));
                  });
                  // 如果正在播放，重启播放器
                  if (_isPlaying) {
                    _pausePlayback();
                    _startPlayback();
                  }
                },
                activeColor: AppColors.primary,
                inactiveColor: Colors.grey[200],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 播放按钮
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isPlaying ? _pausePlayback : _startPlayback,
              icon: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
              ),
              label: Text(
                _isPlaying ? '暂停' : '开始回放',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // 轨迹统计
          _buildTrackStats(),
          const SizedBox(height: 12),
          // 轨迹信息（可展开收起）
          _buildTrackInfo(),
        ],
      ),
    );
  }

  // 轨迹统计组件
  Widget _buildTrackStats() {
    if (_locations.isEmpty) return const SizedBox.shrink();

    final duration = _locations.last.timestamp.difference(_locations.first.timestamp);
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
              _locations.length.toString(),
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

  // 轨迹信息组件（可展开收起）
  Widget _buildTrackInfo() {
    if (_locations.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // 标题栏（点击展开收起）
          GestureDetector(
            onTap: () {
              setState(() {
                _isTrackInfoExpanded = !_isTrackInfoExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '轨迹信息',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Icon(
                    _isTrackInfoExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
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
                      itemCount: _locations.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        color: Colors.grey[200],
                      ),
                      itemBuilder: (context, index) {
                        final location = _locations[index];
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
                                      : index == _locations.length - 1
                                          ? Colors.red
                                          : AppColors.primary.withValues(alpha: 0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  index == 0
                                      ? Icons.play_arrow
                                      : index == _locations.length - 1
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
    );
  }

  // 格式化时间
  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }

  // 分享轨迹
  Future<void> _shareTrajectory() async {
    try {
      // 显示加载提示
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('正在生成分享内容...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // 等待一帧，确保UI渲染完成
      await Future.delayed(const Duration(milliseconds: 100));

      // 截图地图区域
      final RenderRepaintBoundary boundary =
          _mapKey.currentContext?.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('生成分享内容失败')),
          );
        }
        return;
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // 保存图片到临时目录
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final imagePath = '${directory.path}/trajectory_$timestamp.png';
      final imageFile = File(imagePath);
      await imageFile.writeAsBytes(pngBytes);

      // 构建分享文本
      String shareText = '📍 设备轨迹分享\n\n';
      if (_locations.isNotEmpty) {
        final firstLoc = _locations.first;
        final lastLoc = _locations.last;
        shareText += '开始时间: ${_formatDateTime(firstLoc.timestamp)}\n';
        shareText += '结束时间: ${_formatDateTime(lastLoc.timestamp)}\n';
        shareText += '轨迹点数: ${_locations.length}个\n\n';
      }
      shareText += '来自 Starby 位置守护';

      // 分享
      await Share.shareXFiles(
        [XFile(imagePath)],
        text: shareText,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('分享成功')),
        );
      }
    } catch (e) {
      debugPrint('分享失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败: $e')),
        );
      }
    }
  }

  // 格式化日期时间
  String _formatDateTime(DateTime time) {
    return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
