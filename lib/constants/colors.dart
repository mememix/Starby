// lib/constants/colors.dart
// 星护伙伴App - 颜色常量
// 最终品牌色: #E797A2 (柔和粉)

import 'package:flutter/material.dart';

class AppColors {
  // 品牌色 (最终确定: #E797A2 柔和粉)
  static const Color primary = Color(0xFFE797A2);           // 主粉色
  static const Color primaryLight = Color(0xFFF0B0B8);      // 浅粉色
  static const Color primaryDark = Color(0xFFD88590);       // 深粉色
  static const Color primaryPale = Color(0xFFF5C8CD);       // 淡粉色
  
  // 背景色
  static const Color background = Color(0xFFFCE8EA);        // 页面背景渐变起点
  static const Color backgroundLight = Color(0xFFFDF2F3);   // 浅粉背景
  static const Color surface = Colors.white;                // 卡片背景
  
  // 文字色
  static const Color textPrimary = Color(0xFF1A1A1A);       // 主文字
  static const Color textSecondary = Color(0xFF888888);     // 次要文字
  static const Color textHint = Color(0xFF999999);          // 提示文字
  
  // 状态色
  static const Color success = Color(0xFF4ECDC4);           // 成功/在线
  static const Color warning = Color(0xFFFFD93D);           // 警告/电量低
  static const Color danger = Color(0xFFFF4757);            // 危险/SOS
  static const Color offline = Color(0xFFCCCCCC);           // 离线
  
  // 边框/分割线
  static const Color border = Color(0xFFEEEEEE);
  static const Color divider = Color(0xFFF0F0F0);
  
  // 地图相关
  static const Color mapMarkerOnline = Color(0xFF4ECDC4);
  static const Color mapMarkerOffline = Color(0xFFFF4757);
  static const Color mapFence = Color(0xFFE797A2);          // 使用品牌色
}
