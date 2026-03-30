// lib/models/user.dart
// 用户数据模型

import 'package:flutter/foundation.dart';

class User {
  final String id;              // 用户ID
  final String? phonenumber;     // 手机号（API返回）
  final String? phone;           // 手机号（本地存储）
  final String? name;           // 姓名
  final String? nickname;       // 昵称
  final String? avatar;         // 头像
  final String token;           // 认证Token
  final DateTime? createdAt;    // 创建时间
  final DateTime? lastLoginAt;  // 最后登录时间
  final String? gender;         // 性别
  final String? bio;            // 个人简介

  User({
    required this.id,
    this.phonenumber,
    this.phone,
    this.name,
    this.nickname,
    this.avatar,
    required this.token,
    this.createdAt,
    this.lastLoginAt,
    this.gender,
    this.bio,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    debugPrint('[User.fromJson] 输入数据: $json');

    try {
      final user = User(
        id: json['id']?.toString() ?? '',
        phonenumber: json['phonenumber']?.toString() ?? json['phone']?.toString(),
        phone: json['phone']?.toString(),
        name: json['name']?.toString(),
        nickname: json['nickname']?.toString(),
        avatar: json['avatar']?.toString(),
        token: json['token']?.toString() ?? '',
        createdAt: json['createdAt'] != null
            ? (json['createdAt'] is DateTime
                ? json['createdAt'] as DateTime
                : DateTime.parse(json['createdAt'].toString()))
            : null,
        lastLoginAt: json['lastLoginAt'] != null
            ? (json['lastLoginAt'] is DateTime
                ? json['lastLoginAt'] as DateTime
                : DateTime.parse(json['lastLoginAt'].toString()))
            : null,
        gender: json['gender']?.toString(),
        bio: json['bio']?.toString(),
      );

      debugPrint('[User.fromJson] 解析成功: id=${user.id}, phone=${user.phonenumber ?? user.phone}, nickname=${user.nickname}');
      return user;
    } catch (e) {
      debugPrint('[User.fromJson] 解析失败: $e');
      debugPrint('[User.fromJson] 错误详情: ${e.runtimeType}');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phonenumber': phonenumber,
      'phone': phone,
      'name': name,
      'nickname': nickname,
      'avatar': avatar,
      'token': token,
      'createdAt': createdAt?.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'gender': gender,
      'bio': bio,
    };
  }
}

// 登录类型
enum LoginType {
  phone,    // 手机号登录（主账号）
  device,   // 设备号登录（共享账号）
}
