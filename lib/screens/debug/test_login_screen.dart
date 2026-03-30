import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../constants/colors.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';

// 测试登录功能的独立页面
class TestLoginScreen extends StatefulWidget {
  // 移除 const 构造函数
  const TestLoginScreen({super.key});

  @override
  State<TestLoginScreen> createState() => _TestLoginScreenState();
}

class _TestLoginScreenState extends State<TestLoginScreen> {
  final _phoneController = TextEditingController(text: '13888888888');
  final _passwordController = TextEditingController(text: '123456');
  final _logController = TextEditingController();
  bool _isLoading = false;

  void _log(String message) {
    _logController.text += '[${DateTime.now().toIso8601String()}] $message\n';
    debugPrint(message);
  }

  Future<void> _testLogin() async {
    setState(() => _isLoading = true);
    _logController.clear();
    _log('开始测试登录...');

    try {
      _log('1. 调用 ApiService().login()');
      final response = await ApiService().login(
        _phoneController.text.trim(),
        _passwordController.text.trim(),
      );

      _log('2. 登录调用成功');
      _log('   Response type: ${response.runtimeType}');
      _log('   Response: $response');

      _log('3. Response is Map<String, dynamic>');
      _log('   Keys: ${response.keys.join(", ")}');

      if (response.containsKey('data')) {
        final data = response['data'];
        _log('4. Data field found, type: ${data.runtimeType}');

        if (data is Map<String, dynamic>) {
          _log('5. Data is Map<String, dynamic>');
          _log('   Data keys: ${data.keys.join(", ")}');

          if (data.containsKey('token')) {
            final token = data['token'];
            _log('6. Token field found, type: ${token.runtimeType}');

            if (token is String) {
              _log('7. Token is String, length: ${token.length}');
              _log('   Token preview: ${token.length > 20 ? token.substring(0, 20) : token}...');

              await StorageService.setAuthToken(token);
              _log('8. Token saved to storage');

              final savedToken = await StorageService.getAuthToken();
              _log('9. Token retrieved from storage: ${savedToken != null ? savedToken.length : 'null'}');

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('测试登录成功! 查看下方日志')),
                );
              }
            } else {
              _log('✗ ERROR: Token is not String!');
            }
          } else {
            _log('✗ ERROR: Token field not found in data');
          }
        } else {
          _log('✗ ERROR: Data is not Map<String, dynamic>');
        }
      } else {
        _log('✗ ERROR: Data field not found in response');
      }
        } on DioException catch (e) {
      _log('✗ DioException: ${e.message}');
      _log('   Type: ${e.type}');
      _log('   Response: ${e.response}');
      _log('   Status Code: ${e.response?.statusCode}');
    } catch (e) {
      _log('✗ Exception: $e');
      _log('   Type: ${e.runtimeType}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('登录测试'),
        backgroundColor: AppColors.primary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: '手机号',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: '密码',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _testLogin,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('测试登录'),
            ),
            const SizedBox(height: 24),
            const Text(
              '日志输出:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              height: 400,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _logController,
                maxLines: null,
                expands: true,
                readOnly: true,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
