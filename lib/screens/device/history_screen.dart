// lib/screens/device/history_screen.dart
// 历史轨迹页

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../constants/colors.dart';
import '../../models/location.dart';
import '../../routes.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../../utils/trajectory_calibrator.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, this.deviceId});

  final String? deviceId;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  late String deviceId;
  List<Location> _originalLocations = [];
  List<Location> _locations = [];
  DateTime _selectedDate = DateTime.now();
  String? _displayDateStr; // 用于显示选择的日期字符串

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 优先使用构造函数传递的 deviceId，其次使用路由参数
    final id = widget.deviceId ?? ModalRoute.of(context)?.settings.arguments as String?;
    if (id != null && id.isNotEmpty) {
      deviceId = id;
      _loadHistory();
    }
  }

  // 加载历史轨迹
  Future<void> _loadHistory() async {
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
      final start = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final end = start.add(const Duration(days: 1));

      // 更新显示的日期字符串
      _displayDateStr = '${_selectedDate.year}年${_selectedDate.month}月${_selectedDate.day}日';

      _originalLocations = await ApiService().getDeviceHistory(
        deviceId,
        start: start,
        end: end,
        limit: 10000,
      );

      // 轨迹校准：过滤掉几乎一致的点位
      _locations = TrajectoryCalibrator.calibrate(_originalLocations);
      
      // 打印校准统计信息
      if (_originalLocations.length > _locations.length) {
        final stats = TrajectoryCalibrator.getCalibrationStats(_originalLocations, _locations);
        debugPrint('轨迹校准: 原始${stats['originalCount']}点 → 校准后${stats['calibratedCount']}点 (减少${stats['reduction']}%)');
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
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

  // 检测移动时间段（按移动时段分组，而非按小时）
  Map<String, List<Location>> _groupByMovingPeriod() {
    if (_locations.isEmpty) return {};

    final Map<String, List<Location>> periods = {};
    List<Location> currentPeriod = [];
    
    // 静止判断阈值（米）
    const double stationaryThreshold = 10.0;
    // 时间间隔阈值（秒）- 超过这个时间视为新的移动段
    const int timeGapThreshold = 300; // 5分钟
    
    Location? prevLocation;
    
    for (int i = 0; i < _locations.length; i++) {
      final location = _locations[i];
      
      if (prevLocation == null) {
        // 第一个点，开始新时段
        currentPeriod.add(location);
        prevLocation = location;
        continue;
      }
      
      // 计算与前一点的距离
      final distance = TrajectoryCalibrator.calculateDistance(
        prevLocation.lat,
        prevLocation.lng,
        location.lat,
        location.lng,
      );
      
      // 计算时间差
      final timeDiff = location.timestamp.difference(prevLocation.timestamp).inSeconds;
      
      // 判断是否需要新时段：
      // 1. 距离超过阈值，或者
      // 2. 时间间隔超过阈值
      if (distance > stationaryThreshold || timeDiff > timeGapThreshold) {
        // 如果当前时段有多个点，保存该时段
        if (currentPeriod.length >= 2) {
          final periodKey = _formatPeriodKey(currentPeriod);
          periods[periodKey] = List.from(currentPeriod);
        }
        // 开始新时段
        currentPeriod = [location];
      } else {
        // 同一时段，继续添加
        currentPeriod.add(location);
      }
      
      prevLocation = location;
    }
    
    // 保存最后一个时段（如果有多个点）
    if (currentPeriod.length >= 2) {
      final periodKey = _formatPeriodKey(currentPeriod);
      periods[periodKey] = currentPeriod;
    }
    
    return periods;
  }

  // 格式化时段键（显示开始和结束时间）
  String _formatPeriodKey(List<Location> period) {
    if (period.isEmpty) return '';
    final start = period.first;
    final end = period.last;
    final startTime = '${start.timestamp.hour.toString().padLeft(2, '0')}:${start.timestamp.minute.toString().padLeft(2, '0')}';
    final endTime = '${end.timestamp.hour.toString().padLeft(2, '0')}:${end.timestamp.minute.toString().padLeft(2, '0')}';
    return '$startTime - $endTime';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // 顶部导航栏
          _buildHeader(),
          
          // 内容区域
          Expanded(
            child: _buildContent(),
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
            onTap: () {
              Navigator.pop(context);
            },
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(
                Icons.arrow_back,
                size: 24,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const Text(
            '历史轨迹',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          TextButton(
            onPressed: () async {
              // 选择日期
              final date = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime.now().subtract(const Duration(days: 90)),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                setState(() {
                  _selectedDate = date;
                });
                _loadHistory();
              }
            },
            child: Text(
              _displayDateStr ?? '${_selectedDate.month}月${_selectedDate.day}日',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 内容区域
  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
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
              onPressed: _loadHistory,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    final grouped = _groupByMovingPeriod();

    if (_locations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '${_selectedDate.month}月${_selectedDate.day}日\n没有找到历史轨迹',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // 计算总里程（简单估算，实际需要计算路径）
    final totalPoints = _locations.length;
    final originalPoints = _originalLocations.length;
    final estimatedDistance = (totalPoints * 0.05).toStringAsFixed(1);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 数据统计卡片
          _buildStatsCard(estimatedDistance, totalPoints, originalPoints),
          const SizedBox(height: 16),
          // 播放轨迹按钮（移到列表上方）
          _buildPlayButton(),
          const SizedBox(height: 16),
          // 轨迹列表
          _buildTrackList(grouped),
        ],
      ),
    );
  }

  // 数据统计卡片
  Widget _buildStatsCard(String distance, int points, int originalPoints) {
    final reductionPercent = originalPoints > 0
        ? ((originalPoints - points) / originalPoints * 100).toStringAsFixed(1)
        : '0.0';
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFE8EB),
            Color(0xFFFFF3F5),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatItem(distance, '公里'),
              ),
              Expanded(
                child: _buildStatItem('$points/$originalPoints', '位置点'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '已优化: 减少 $reductionPercent% 点位',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 统计项
  Widget _buildStatItem(String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 4),
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

  // 轨迹列表
  Widget _buildTrackList(Map<String, List<Location>> grouped) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _displayDateStr ?? '${_selectedDate.year}年${_selectedDate.month}月${_selectedDate.day}日',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textHint,
          ),
        ),
        const SizedBox(height: 12),
        ...grouped.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildTrackItem(entry.key, entry.value),
          );
        }),
      ],
    );
  }

  // 轨迹项（显示移动时间段）
  Widget _buildTrackItem(String period, List<Location> locations) {
    final firstLocation = locations.first;
    final lastLocation = locations.last;

    return GestureDetector(
      onTap: () {
        // 传递该时间段的位置点到轨迹回放页
        Navigator.pushNamed(
          context,
          AppRoutes.trackReplay,
          arguments: {
            'deviceId': deviceId,
            'locations': locations,
          },
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  period,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${locations.length} 点',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
                    firstLocation.address ?? '起点: ${firstLocation.lat.toStringAsFixed(4)}, ${firstLocation.lng.toStringAsFixed(4)}',
                    style: const TextStyle(
                      fontSize: 12,
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
                  Icons.flag,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    lastLocation.address ?? '终点: ${lastLocation.lat.toStringAsFixed(4)}, ${lastLocation.lng.toStringAsFixed(4)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 播放轨迹按钮
  Widget _buildPlayButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _originalLocations.isEmpty
            ? null
            : () {
                Navigator.pushNamed(
                  context,
                  AppRoutes.trackReplay,
                  arguments: {
                    'deviceId': deviceId,
                    'locations': _originalLocations,
                  },
                );
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: AppColors.primary.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        child: const Text(
          '播放轨迹回放',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
