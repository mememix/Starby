// lib/screens/debug/debug_storage_screen.dart
// 调试页面 - 查看存储的数据

import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/storage_service.dart';
import '../../services/api_service.dart';

class DebugStorageScreen extends StatefulWidget {
  const DebugStorageScreen({super.key});

  @override
  State<DebugStorageScreen> createState() => _DebugStorageScreenState();
}

class _DebugStorageScreenState extends State<DebugStorageScreen> {
  Map<String, dynamic> _debugData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDebugData();
  }

  Future<void> _loadDebugData() async {
    final data = <String, dynamic>{};

    // 获取所有存储数据
    data['isLoggedIn'] = await StorageService.isLoggedIn();
    data['loginType'] = await StorageService.getLoginType();
    data['userId'] = await StorageService.getUserId();
    data['userPhone'] = await StorageService.getUserPhone();
    data['authToken'] = await StorageService.getAuthToken();
    data['userInfo'] = await StorageService.getUserInfo();
    data['isDeviceLogin'] = await StorageService.isDeviceLogin();
    data['homeStyle'] = await StorageService.getHomeStyle();

    // 尝试调用 API
    try {
      final apiResponse = await ApiService().getCurrentUser();
      data['apiResponse'] = apiResponse;
    } catch (e) {
      data['apiError'] = e.toString();
    }

    setState(() {
      _debugData = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('存储调试信息'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _loadDebugData();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSection('登录状态', [
                  _buildItem('isLoggedIn', _debugData['isLoggedIn']),
                  _buildItem('loginType', _debugData['loginType']),
                  _buildItem('isDeviceLogin', _debugData['isDeviceLogin']),
                ]),
                _buildSection('用户基本信息', [
                  _buildItem('userId', _debugData['userId']),
                  _buildItem('userPhone', _debugData['userPhone']),
                  _buildItem('homeStyle', _debugData['homeStyle']),
                ]),
                _buildSection('Token信息', [
                  _buildItem(
                    'authToken',
                    _getDisplayToken(_debugData['authToken']),
                    isSensitive: true,
                  ),
                ]),
                _buildSection('完整用户信息 (userInfo)', [
                  _buildJsonItem('userInfo', _debugData['userInfo']),
                ]),
                _buildSection('API响应', [
                  _buildJsonItem('apiResponse', _debugData['apiResponse']),
                  if (_debugData.containsKey('apiError'))
                    _buildItem('apiError', _debugData['apiError'], isError: true),
                ]),
              ],
            ),
    );
  }

  String _getDisplayToken(dynamic token) {
    if (token == null || token.toString().isEmpty) {
      return 'null';
    }
    final tokenStr = token.toString();
    if (tokenStr.length > 50) {
      return '${tokenStr.substring(0, 50)}...';
    }
    return tokenStr;
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...children,
        const Divider(height: 32),
      ],
    );
  }

  Widget _buildItem(String label, dynamic value, {bool isSensitive = false, bool isError = false}) {
    final displayValue = value?.toString() ?? 'null';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isError ? Colors.red : Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              displayValue,
              style: TextStyle(
                color: isError ? Colors.red : Colors.black87,
                fontFamily: isSensitive ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJsonItem(String label, dynamic value) {
    final jsonStr = value != null
        ? const JsonEncoder.withIndent('  ').convert(value)
        : 'null';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label:',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            jsonStr,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      ],
    );
  }
}
