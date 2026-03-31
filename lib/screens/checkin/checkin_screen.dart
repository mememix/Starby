import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../services/api_service.dart';

class CheckinScreen extends StatefulWidget {
  const CheckinScreen({super.key});

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  bool _isLoading = true;
  bool _hasCheckedIn = false;
  int _continuousDays = 0;
  int _monthlyDays = 0;
  int _totalPoints = 0;
  int _availablePoints = 0;
  int _potentialPoints = 0;
  String? _lastCheckinTime;
  List<Map<String, dynamic>> _weekData = [];
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _pointsRecords = [];

  @override
  void initState() {
    super.initState();
    _loadCheckinData();
  }

  // 计算可得积分
  int _calculatePotentialPoints(int continuousDays) {
    if (continuousDays < 4) {
      // 连续1-3天
      return 1;
    } else if (continuousDays < 6) {
      // 连续4-5天
      return 2;
    } else if (continuousDays < 10) {
      // 连续6-9天
      return 3;
    } else {
      // 连续10天及以上
      return 5;
    }
  }

  Future<void> _loadCheckinData() async {
    setState(() => _isLoading = true);

    try {
      // 并行请求多个接口
      final results = await Future.wait([
        ApiService().getCheckinStatus(),
        ApiService().getCheckinStats(),
        ApiService().getCheckinHistory(),
        ApiService().getPointsRecords(),
      ]);

      // 处理打卡状态
      if (results[0]['success'] == true) {
        final statusData = results[0]['data'];
        setState(() {
          _hasCheckedIn = statusData['hasCheckedIn'] ?? false;
          _continuousDays = statusData['continuousDays'] ?? 0;
          _lastCheckinTime = statusData['lastCheckinTime'];
          _totalPoints = statusData['totalPoints'] ?? 0;
          _availablePoints = statusData['availablePoints'] ?? 0;
          _potentialPoints = statusData['potentialPoints'] ?? 1;
        });
      }

      // 处理统计数据
      if (results[1]['success'] == true) {
        final statsData = results[1]['data'];
        setState(() {
          _monthlyDays = statsData['monthlyDays'] ?? 0;
          _weekData = List<Map<String, dynamic>>.from(
            statsData['weekData'] ?? [],
          );
        });
      }

      // 处理历史记录
      if (results[2]['success'] == true) {
        final historyData = results[2]['data'];
        setState(() {
          _history = List<Map<String, dynamic>>.from(
            historyData['checkins'] ?? [],
          );
        });
      }

      // 处理积分记录
      if (results[3]['success'] == true) {
        final pointsData = results[3]['data'];
        setState(() {
          _pointsRecords = List<Map<String, dynamic>>.from(
            pointsData['records'] ?? [],
          );
        });
      }
    } catch (e) {
      debugPrint('[CheckinScreen] 加载数据失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('加载数据失败')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _performCheckin() async {
    try {
      setState(() => _isLoading = true);

      final response = await ApiService().performCheckin();

      if (response['success'] == true) {
        final data = response['data'];

        setState(() {
          _hasCheckedIn = true;
          _continuousDays = data['continuousDays'] ?? 0;
          _totalPoints = data['totalPoints'] ?? 0;
          _availablePoints = data['availablePoints'] ?? 0;
          // 更新下次可得积分(连续天数+1)
          _potentialPoints = _calculatePotentialPoints(_continuousDays + 1);
        });

        if (mounted) {
          // 显示成功弹窗
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => _buildSuccessDialog(data),
          ).then((_) {
            // 刷新数据
            _loadCheckinData();
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['message'] ?? '打卡失败')),
          );
        }
      }
    } catch (e) {
      debugPrint('[CheckinScreen] 打卡失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('打卡失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildSuccessDialog(Map<String, dynamic> data) {
    final pointsEarned = data['pointsEarned'] ?? 0;
    final continuousDays = data['continuousDays'] ?? 0;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      content: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 成功图标
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                size: 50,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '打卡成功！',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('本次获得积分'),
                      Text(
                        '+$pointsEarned',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('连续打卡天数'),
                      Text(
                        '$continuousDays天',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('累计积分'),
                      Text(
                        '${_availablePoints}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '确定',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('每日打卡'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCheckinCard(),
                  const SizedBox(height: 20),
                  _buildPointsCard(),
                  const SizedBox(height: 20),
                  _buildWeekCalendar(),
                  const SizedBox(height: 20),
                  _buildHistorySection(),
                  const SizedBox(height: 20),
                  _buildPointsRecordsSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildCheckinCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            Color(0xFFFFB7C0),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            '今日打卡',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          if (_hasCheckedIn) ...[
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '今日已打卡',
              style: TextStyle(
                fontSize: 20,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '已连续打卡 $_continuousDays 天',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ] else ...[
            GestureDetector(
              onTap: _isLoading ? null : _performCheckin,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: _isLoading ? Colors.grey[300]! : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.touch_app,
                      size: 40,
                      color: _isLoading
                          ? Colors.grey
                          : AppColors.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '打卡',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _isLoading
                            ? Colors.grey
                            : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isLoading ? '正在打卡...' : '点击按钮完成打卡',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _hasCheckedIn ? '下次可得 $_potentialPoints 积分' : '本次可得 $_potentialPoints 积分',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPointsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                const Text(
                  '可用积分',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_availablePoints',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 50,
            color: Colors.grey[200],
          ),
          Expanded(
            child: Column(
              children: [
                const Text(
                  '累计积分',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_totalPoints',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 50,
            color: Colors.grey[200],
          ),
          Expanded(
            child: Column(
              children: [
                const Text(
                  '本月打卡',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$_monthlyDays天',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekCalendar() {
    final now = DateTime.now();
    final weekDays = ['一', '二', '三', '四', '五', '六', '日'];
    
    // 找到本周一的日期
    final todayWeekday = now.weekday; // 1=周一, 7=周日
    final monday = now.subtract(Duration(days: todayWeekday - 1));
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '本周打卡',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) {
              final date = monday.add(Duration(days: index));
              final dayStr = weekDays[index]; // 周一到周日依次
              final isToday = index == todayWeekday - 1;
              
              // 查找该日期的打卡记录
              final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
              final record = _weekData.cast<Map<String, dynamic>?>().firstWhere(
                (item) => item?['date'] == dateStr,
                orElse: () => null,
              );
              
              final hasCheckedIn = record != null && (record['checkedIn'] == true || record['checkedIn'] == 'true');
              final continuousDays = record?['continuousDays'] ?? 0;

              return Column(
                children: [
                  Text(
                    dayStr,
                    style: TextStyle(
                      fontSize: 14,
                      color: hasCheckedIn ? AppColors.primary : (isToday ? AppColors.primary : Colors.grey),
                      fontWeight: isToday || hasCheckedIn ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: hasCheckedIn
                          ? AppColors.primary
                          : Colors.grey[200],
                      shape: BoxShape.circle,
                    ),
                    child: hasCheckedIn
                        ? const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 24,
                          )
                        : null,
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 12),
          if (_continuousDays > 0)
            Text(
              '已连续打卡 $_continuousDays 天',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.primary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '打卡历史',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  // TODO: 查看更多历史
                },
                child: const Text('查看更多'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_history.isEmpty)
            const Center(
              child: Text(
                '暂无打卡记录',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _history.take(5).length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final record = _history[index];
                final checkinTime = DateTime.parse(record['checkinTime']);
                final continuousDays = record['continuousDays'] ?? 0;
                final address = record['address'] ?? '未知位置';

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.calendar_today,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    '${checkinTime.year}-${checkinTime.month.toString().padLeft(2, '0')}-${checkinTime.day.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(address),
                      Text('连续打卡 $continuousDays 天'),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPointsRecordsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '积分记录',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  // TODO: 查看更多记录
                },
                child: const Text('查看更多'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_pointsRecords.isEmpty)
            const Center(
              child: Text(
                '暂无积分记录',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _pointsRecords.take(5).length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final record = _pointsRecords[index];
                final points = record['points'] ?? 0;
                final description = record['description'] ?? '打卡奖励';
                final createTime = DateTime.parse(record['createTime']);

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: points > 0
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.red.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      points > 0 ? Icons.add : Icons.remove,
                      color: points > 0 ? Colors.green : Colors.red,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    description,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${createTime.year}-${createTime.month.toString().padLeft(2, '0')}-${createTime.day.toString().padLeft(2, '0')} ${createTime.hour.toString().padLeft(2, '0')}:${createTime.minute.toString().padLeft(2, '0')}',
                  ),
                  trailing: Text(
                    '${points > 0 ? '+' : ''}$points',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: points > 0 ? Colors.green : Colors.red,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
