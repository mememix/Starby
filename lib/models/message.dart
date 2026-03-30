// lib/models/message.dart
// 消息数据模型

import 'package:flutter/foundation.dart';

enum MessageType {
  system,    // 系统消息
  fence,     // 围栏报警
  sos,       // SOS报警
  lowBattery,// 电量不足
  offline,   // 设备离线
  online,    // 设备上线
}

enum MessagePriority {
  normal,    // 普通
  important, // 重要
  urgent,    // 紧急
}

class Message {
  final String id;
  final String userId;        // 接收用户ID
  final String? deviceId;     // 相关设备ID
  final MessageType type;     // 消息类型
  final MessagePriority priority; // 优先级
  final String title;         // 标题
  final String content;       // 内容
  final Map<String, dynamic>? data; // 附加数据
  final bool isRead;          // 是否已读
  final DateTime createdAt;   // 创建时间
  final DateTime? readAt;     // 阅读时间

  Message({
    required this.id,
    required this.userId,
    this.deviceId,
    required this.type,
    this.priority = MessagePriority.normal,
    required this.title,
    required this.content,
    this.data,
    this.isRead = false,
    required this.createdAt,
    this.readAt,
  });

  // 从JSON解析
  factory Message.fromJson(Map<String, dynamic> json) {
    debugPrint('[Message.fromJson] Input JSON: $json');

    // 后端type是字符串，需要转换为枚举
    String typeStr = json['type'] ?? 'system';
    MessageType type;
    switch (typeStr) {
      case 'fence':
        type = MessageType.fence;
        break;
      case 'sos':
        type = MessageType.sos;
        break;
      case 'lowBattery':
        type = MessageType.lowBattery;
        break;
      case 'offline':
        type = MessageType.offline;
        break;
      case 'online':
        type = MessageType.online;
        break;
      default:
        type = MessageType.system;
    }

    // 处理日期时间
    DateTime createdAt;
    try {
      createdAt = json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now();
    } catch (e) {
      debugPrint('[Message.fromJson] Failed to parse createdAt: ${json['createdAt']}');
      createdAt = DateTime.now();
    }

    DateTime? readAt;
    if (json['readAt'] != null) {
      try {
        readAt = DateTime.parse(json['readAt']);
      } catch (e) {
        debugPrint('[Message.fromJson] Failed to parse readAt: ${json['readAt']}');
        readAt = null;
      }
    }

    final message = Message(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      deviceId: json['deviceId']?.toString(),
      type: type,
      priority: MessagePriority.values.firstWhere(
        (e) => e.toString() == 'MessagePriority.${json['priority']}',
        orElse: () => type == MessageType.sos ? MessagePriority.urgent : MessagePriority.normal,
      ),
      title: json['title']?.toString() ?? '未知消息',
      content: json['content']?.toString() ?? '',
      data: json['data'],
      isRead: json['isRead'] ?? false,
      createdAt: createdAt,
      readAt: readAt,
    );

    debugPrint('[Message.fromJson] Created message: id=${message.id}, title=${message.title}, type=${message.type}');
    return message;
  }

  // 转JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'deviceId': deviceId,
      'type': type.toString().split('.').last,
      'priority': priority.toString().split('.').last,
      'title': title,
      'content': content,
      'data': data,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
    };
  }

  // 标记已读
  Message markAsRead() {
    return Message(
      id: id,
      userId: userId,
      deviceId: deviceId,
      type: type,
      priority: priority,
      title: title,
      content: content,
      data: data,
      isRead: true,
      createdAt: createdAt,
      readAt: DateTime.now(),
    );
  }

  // 获取类型显示文字
  String get typeText {
    switch (type) {
      case MessageType.system:
        return '系统消息';
      case MessageType.fence:
        return '围栏提醒';
      case MessageType.sos:
        return '紧急求助';
      case MessageType.lowBattery:
        return '电量不足';
      case MessageType.offline:
        return '设备离线';
      case MessageType.online:
        return '设备上线';
    }
  }

  // 获取优先级颜色
  String get priorityColor {
    switch (priority) {
      case MessagePriority.normal:
        return '#E797A2';
      case MessagePriority.important:
        return '#FF9500';
      case MessagePriority.urgent:
        return '#FF3B30';
    }
  }
}

// 消息查询参数
class MessageQuery {
  final MessageType? type;
  final bool? isRead;
  final int page;
  final int limit;

  MessageQuery({
    this.type,
    this.isRead,
    this.page = 1,
    this.limit = 20,
  });

  Map<String, dynamic> toJson() {
    return {
      if (type != null) 'type': type.toString().split('.').last,
      if (isRead != null) 'isRead': isRead,
      'page': page,
      'limit': limit,
    };
  }
}
