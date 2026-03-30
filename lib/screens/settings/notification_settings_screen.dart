// lib/screens/settings/notification_settings_screen.dart
// 消息通知设置页

import 'package:flutter/material.dart';
import '../../constants/colors.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  bool _deviceEntryAlert = true;
  bool _deviceExitAlert = true;
  bool _lowBatteryAlert = true;
  bool _sosAlert = true;
  bool _pushEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  _buildNotificationSection(),
                  const SizedBox(height: 24),
                  _buildPushSwitch(),
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
                Icons.arrow_back,
                size: 24,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const Text(
            '通知设置',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  // 通知开关列表
  Widget _buildNotificationSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '消息通知类型',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('进入围栏提醒'),
            value: _deviceEntryAlert,
            onChanged: (value) {
              setState(() {
                _deviceEntryAlert = value;
              });
            },
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            title: const Text('离开围栏提醒'),
            value: _deviceExitAlert,
            onChanged: (value) {
              setState(() {
                _deviceExitAlert = value;
              });
            },
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            title: const Text('低电量提醒'),
            value: _lowBatteryAlert,
            onChanged: (value) {
              setState(() {
                _lowBatteryAlert = value;
              });
            },
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            title: const Text('SOS紧急警报'),
            value: _sosAlert,
            onChanged: (value) {
              setState(() {
                _sosAlert = value;
              });
            },
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  // 推送总开关
  Widget _buildPushSwitch() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: SwitchListTile(
        title: const Text('允许推送通知'),
        subtitle: const Text('关闭后将接收不到任何消息提醒'),
        value: _pushEnabled,
        onChanged: (value) {
          setState(() {
            _pushEnabled = value;
          });
        },
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}
