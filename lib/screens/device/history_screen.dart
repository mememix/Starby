// lib/screens/device/history_screen.dart
// 历史轨迹页

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../constants/colors.dart';
import '../../models/location.dart';
import '../../routes.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';

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

      final locations = await ApiService().getDeviceHistory(
        deviceId,
        start: start,
        end: end,
        limit: 10000,
      );

      if (mounted) {
        setState(() {
          _locations = locations;
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

  // 按时间分组位置点
  Map<String, List<Location>> _groupByHour() {
    final Map<String, List<Location>> grouped = {};
    for (var location in _locations) {
      final hourStr = '${location.timestamp.hour.toString().padLeft(2, '0')}:00';
      if (!grouped.containsKey(hourStr)) {
        grouped[hourStr] = [];
      }
      grouped[hourStr]!.add(location);
    }
    return grouped;
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

    final grouped = _groupByHour();

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
    final estimatedDistance = (totalPoints * 0.05).toStringAsFixed(1);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 数据统计卡片
          _buildStatsCard(estimatedDistance, totalPoints),
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
  Widget _buildStatsCard(String distance, int points) {
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
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(distance, '公里'),
          ),
          Expanded(
            child: _buildStatItem(points.toString(), '位置点'),
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

  // 轨迹项
  Widget _buildTrackItem(String hour, List<Location> locations) {
    final firstLocation = locations.first;
    final timeStr = '${firstLocation.timestamp.hour.toString().padLeft(2, '0')}:${firstLocation.timestamp.minute.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: () {
        // TODO: 在地图上查看该时间段轨迹
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('查看轨迹详情')),
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
                  hour,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  timeStr,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${locations.length} 个位置点',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
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
        onPressed: _locations.isEmpty
            ? null
            : () {
                Navigator.pushNamed(
                  context,
                  AppRoutes.trackReplay,
                  arguments: {
                    'deviceId': deviceId,
                    'locations': _locations,
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
