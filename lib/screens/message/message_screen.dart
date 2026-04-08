// lib/screens/message/message_screen.dart
// 消息中心页

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../constants/colors.dart';
import '../../models/message.dart';
import '../../routes.dart';
import '../../services/api_service.dart';

class MessageScreen extends StatefulWidget {
  const MessageScreen({super.key});

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  int _selectedTab = 0; // 0: 全部, 1: 围栏, 2: SOS, 3: 系统
  bool _isLoading = true;
  List<Message> _messages = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  // 加载消息列表
  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      String? type;
      switch (_selectedTab) {
        case 1:
          type = 'lowBattery';
          break;
        case 2:
          type = 'fence';
          break;
        case 3:
          type = 'sos';
          break;
        default:
          type = null;
      }

      // 恢复消息API调用，后端消息已完善
      final messages = await ApiService().getMessages(type: type);

      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.response?.data?['message'] ?? '加载消息失败';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '加载消息失败: $e';
          _isLoading = false;
        });
      }
    }
  }

  // 标记全部已读
  Future<void> _markAllAsRead() async {
    try {
      String? type;
      switch (_selectedTab) {
        case 1:
          type = 'lowBattery';
          break;
        case 2:
          type = 'fence';
          break;
        case 3:
          type = 'sos';
          break;
      }

      await ApiService().markAllMessagesAsRead(type: type);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已标记为全部已读')),
        );
        _loadMessages();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  // 清空消息列表
  Future<void> _clearMessages() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空消息'),
        content: const Text('确定要清空当前列表的所有消息吗？\n\n注意：只能清空已读消息，未读消息无法清空。如需清空未读消息，请先将其标记为已读。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('清空'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // 清空消息，暂时不支持按类型清空
      await ApiService().clearReadMessages();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已清空已读消息')),
        );
        _loadMessages();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // 顶部导航栏
          _buildHeader(),
          
          // 标签切换
          _buildTabSwitch(),
          
          // 消息列表
          Expanded(
            child: _buildMessageList(),
          ),
          
          // 底部导航
          _buildBottomNav(),
        ],
      ),
    );
  }

  // 顶部导航栏
  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 24,
        right: 24,
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
          const Text(
            '消息中心',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: _markAllAsRead,
                child: const Text(
                  '全部已读',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              TextButton(
                onPressed: _clearMessages,
                child: const Text(
                  '清空',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 标签切换
  Widget _buildTabSwitch() {
    final tabs = ['全部', '电量', '围栏', 'SOS'];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = _selectedTab == index;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedTab = index;
                });
                _loadMessages();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  tabs[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // 消息列表
  Widget _buildMessageList() {
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
              onPressed: _loadMessages,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '暂无消息',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMessages,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _messages.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final message = _messages[index];
          return _buildMessageItem(message);
        },
      ),
    );
  }

  // 消息项
  Widget _buildMessageItem(Message message) {
    IconData icon;
    Color iconColor;
    Color bgColor;

    switch (message.type) {
      case MessageType.lowBattery:
        icon = Icons.battery_alert_outlined;
        iconColor = const Color(0xFFFF9500);
        bgColor = const Color(0xFFFFF3E0);
        break;
      case MessageType.fence:
        icon = Icons.location_on_outlined;
        iconColor = const Color(0xFF4CAF50);
        bgColor = const Color(0xFFE8F5E9);
        break;
      case MessageType.sos:
        icon = Icons.warning_outlined;
        iconColor = const Color(0xFFF44336);
        bgColor = const Color(0xFFFFEBEE);
        break;
      default:
        icon = Icons.notifications_outlined;
        iconColor = AppColors.textSecondary;
        bgColor = Colors.grey[100]!;
    }

    final timeStr = _formatTime(message.createdAt);

    return GestureDetector(
      onTap: () async {
        debugPrint('[MessageScreen] Tapped message: id=${message.id}, title=${message.title}');

        // 标记为已读
        if (!message.isRead) {
          try {
            await ApiService().markMessageAsRead(message.id);
            debugPrint('[MessageScreen] Marked as read: ${message.id}');
            // 更新本地消息状态
            final index = _messages.indexWhere((m) => m.id == message.id);
            if (index != -1) {
              setState(() {
                _messages[index] = message.markAsRead();
              });
            }
          } catch (e) {
            debugPrint('[MessageScreen] Failed to mark as read: $e');
            // 忽略错误
          }
        }
        // 跳转到详情页 - 传递JSON格式以避免对象序列化问题
        if (!mounted) return;
        debugPrint('[MessageScreen] Navigating to detail with JSON');
        Navigator.pushNamed(
          context,
          AppRoutes.messageDetail,
          arguments: message.toJson(),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: message.type == MessageType.sos
                ? const Color(0xFFFFCDD2)
                : message.type == MessageType.lowBattery
                    ? const Color(0xFFFFE0B2)
                    : Colors.grey[100]!,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                icon,
                size: 20,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        message.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: message.type == MessageType.sos
                              ? const Color(0xFFF44336)
                              : message.type == MessageType.lowBattery
                                  ? const Color(0xFFFF9500)
                                  : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        timeStr,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message.content,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!message.isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(left: 8),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
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
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return '${time.month}月${time.day}日';
    }
  }

  // 底部导航
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home_outlined, '首页', 0),
              _buildNavItem(Icons.message, '消息', 1),
              _buildNavItem(Icons.person_outline, '我的', 2),
            ],
          ),
        ),
      ),
    );
  }

  // 导航项
  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = index == 1;
    return GestureDetector(
      onTap: () {
        if (index == 0) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.home,
            (route) => false,
          );
        } else if (index == 2) {
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
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? AppColors.primary : Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }
}

