// lib/screens/message/message_detail_screen.dart
// 消息详情页

import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../models/message.dart';

class MessageDetailScreen extends StatefulWidget {
  const MessageDetailScreen({super.key});

  @override
  State<MessageDetailScreen> createState() => _MessageDetailScreenState();
}

class _MessageDetailScreenState extends State<MessageDetailScreen> {
  Message? _message;
  bool _isLoading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isLoading) {
      final args = ModalRoute.of(context)?.settings.arguments;
      debugPrint('[MessageDetailScreen] Received arguments type: ${args.runtimeType}, value: $args');

      if (args is Message) {
        final message = args;
        debugPrint('[MessageDetailScreen] Message id: ${message.id}, title: ${message.title}');
        debugPrint('[MessageDetailScreen] Message content: ${message.content}');
        debugPrint('[MessageDetailScreen] Message data: ${message.data}');

        setState(() {
          _message = message;
          _isLoading = false;
          _error = null;
        });
      } else if (args is Map<String, dynamic>) {
        debugPrint('[MessageDetailScreen] Received Map instead of Message, trying to parse...');
        try {
          final message = Message.fromJson(args);
          debugPrint('[MessageDetailScreen] Parsed message id: ${message.id}, title: ${message.title}');
          setState(() {
            _message = message;
            _isLoading = false;
            _error = null;
          });
        } catch (e) {
          debugPrint('[MessageDetailScreen] Failed to parse Map to Message: $e');
          setState(() {
            _message = null;
            _isLoading = false;
            _error = '消息格式错误';
          });
        }
      } else {
        debugPrint('[MessageDetailScreen] No valid message received, args type: ${args?.runtimeType}');
        setState(() {
          _message = null;
          _isLoading = false;
          _error = '消息不存在';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[MessageDetailScreen] Building, isLoading: $_isLoading, message: $_message, error: $_error');

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_message == null || _error != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error ?? '消息不存在', style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('返回'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // 顶部导航栏
          _buildHeader(),

          // 消息内容
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildMessageContent(),
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
        children: [
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
            },
            child: const Icon(
              Icons.arrow_back,
              size: 24,
              color: AppColors.textSecondary,
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                '消息详情',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
        ],
      ),
    );
  }

  // 消息内容
  Widget _buildMessageContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 消息类型标识
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getBackgroundColor(),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getIcon(),
                size: 16,
                color: _getIconColor(),
              ),
              const SizedBox(width: 4),
              Text(
                _message!.typeText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _getIconColor(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 消息标题
        Text(
          _message!.title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),

        // 消息时间
        Text(
          _formatDateTime(_message!.createdAt),
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 24),

        // 分隔线
        Container(
          height: 1,
          color: Colors.grey[200],
        ),
        const SizedBox(height: 24),

        // 消息正文
        Text(
          _message!.content,
          style: const TextStyle(
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 24),

        // 附加数据（如果有位置信息）
        if (_message!.data != null && _message!.data!['decoded_data'] != null)
          _buildLocationCard(),
      ],
    );
  }

  // 位置信息卡片
  Widget _buildLocationCard() {
    debugPrint('[MessageDetailScreen] _message!.data: ${_message!.data}');

    // 尝试从不同位置获取设备名称和位置信息
    String deviceName = '未知设备';
    String address = '未知位置';

    // 从 decoded_data 获取
    if (_message!.data != null && _message!.data!['decoded_data'] != null) {
      final decodedData = _message!.data!['decoded_data'];
      deviceName = decodedData['deviceName']?.toString() ??
                    decodedData['device_name']?.toString() ??
                    '未知设备';
      address = decodedData['address']?.toString() ??
                 decodedData['location']?.toString() ??
                 '未知位置';

      debugPrint('[MessageDetailScreen] From decoded_data - deviceName: $deviceName, address: $address');
    }

    // 从顶层 data 获取（备用）
    if (deviceName == '未知设备' && _message!.data != null) {
      final deviceCode = _message!.data!['device_code']?.toString() ??
                        _message!.deviceId?.toString() ??
                        '';
      deviceName = deviceCode.isNotEmpty ? '设备 ($deviceCode)' : '未知设备';

      debugPrint('[MessageDetailScreen] From top level - deviceName: $deviceName');
    }

    debugPrint('[MessageDetailScreen] Final - deviceName: $deviceName, address: $address');

    return Container(
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
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  size: 20,
                  color: Color(0xFF4CAF50),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      address.toString(),
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '设备：$deviceName',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 获取图标
  IconData _getIcon() {
    switch (_message!.type) {
      case MessageType.fence:
        return Icons.location_on_outlined;
      case MessageType.sos:
        return Icons.warning_outlined;
      case MessageType.lowBattery:
        return Icons.battery_alert;
      case MessageType.offline:
        return Icons.offline_bolt;
      case MessageType.online:
        return Icons.online_prediction;
      default:
        return Icons.notifications_outlined;
    }
  }

  // 获取图标颜色
  Color _getIconColor() {
    switch (_message!.type) {
      case MessageType.fence:
        return const Color(0xFF4CAF50);
      case MessageType.sos:
        return const Color(0xFFF44336);
      case MessageType.lowBattery:
        return const Color(0xFFFF9800);
      case MessageType.offline:
        return Colors.grey;
      case MessageType.online:
        return const Color(0xFF2196F3);
      default:
        return AppColors.textSecondary;
    }
  }

  // 获取背景颜色
  Color _getBackgroundColor() {
    switch (_message!.type) {
      case MessageType.fence:
        return const Color(0xFFE8F5E9);
      case MessageType.sos:
        return const Color(0xFFFFEBEE);
      case MessageType.lowBattery:
        return const Color(0xFFFFF3E0);
      case MessageType.offline:
        return Colors.grey[100]!;
      case MessageType.online:
        return const Color(0xFFE3F2FD);
      default:
        return Colors.grey[100]!;
    }
  }

  // 格式化日期时间
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
