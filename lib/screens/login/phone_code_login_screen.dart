// lib/screens/login/phone_code_login_screen.dart
// 手机号验证码登录页

import 'dart:async';
import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../routes.dart';
import '../../services/storage_service.dart';
import '../../services/api_service.dart';
import '../../services/device_info_service.dart';

class PhoneCodeLoginScreen extends StatefulWidget {
  const PhoneCodeLoginScreen({super.key});

  @override
  State<PhoneCodeLoginScreen> createState() => _PhoneCodeLoginScreenState();
}

class _PhoneCodeLoginScreenState extends State<PhoneCodeLoginScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  
  bool _isSendingCode = false;
  bool _isLoading = false;
  int _countdown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    final isLoggedIn = await StorageService.isLoggedIn();
    final token = await StorageService.getAuthToken();
    final actuallyLoggedIn = isLoggedIn && token != null && token.isNotEmpty;
    
    if (actuallyLoggedIn && mounted) {
      final homeStyle = await StorageService.getHomeStyle();
      Navigator.pushNamedAndRemoveUntil(
        context,
        homeStyle == 'classic' ? AppRoutes.home : AppRoutes.homeImmersive,
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFCE8EA),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),
                _buildHeader(),
                const SizedBox(height: 32),
                Expanded(
                  child: _buildLoginForm(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.arrow_back,
              size: 24,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          '验证码登录',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '使用手机号验证码快速登录',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '手机号码',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            hintText: '请输入手机号码',
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '验证码',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: '请输入验证码',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary, width: 2),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 128,
              height: 48,
              child: ElevatedButton(
                onPressed: (_countdown > 0 || _isSendingCode) ? null : _sendVerificationCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFE8EB),
                  foregroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSendingCode
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      )
                    : Text(
                        _countdown > 0 ? '${_countdown}s' : '获取验证码',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _countdown > 0 ? AppColors.textSecondary : AppColors.primary,
                        ),
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _loginWithCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: AppColors.primary.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    '登录',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '还没有账号? ',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.register);
              },
              child: const Text(
                '注册账号',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 发送验证码
  Future<void> _sendVerificationCode() async {
    final phone = _phoneController.text.trim();
    
    // 验证手机号格式
    if (phone.isEmpty || !RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请输入正确的手机号码')),
        );
      }
      return;
    }

    if (_isSendingCode || _countdown > 0) {
      return;
    }

    setState(() {
      _isSendingCode = true;
    });

    try {
      final response = await ApiService().sendVerificationCode(phone, type: 'login');
      
      if (response['success'] == true) {
        // 开始倒计时
        _startCountdown();

        // 开发环境显示验证码
        if (response['data'] != null && response['data']['code'] != null) {
          debugPrint('[PhoneCodeLogin] 验证码: ${response['data']['code']}');
          // 自动填入验证码
          _codeController.text = response['data']['code'];
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? '验证码已发送'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // 发送失败时，清除旧的验证码，防止用户使用过期验证码登录
        _codeController.clear();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['message'] ?? '发送验证码失败')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送验证码失败: $e')),
        );
      }
    } finally {
      setState(() {
        _isSendingCode = false;
      });
    }
  }

  // 开始倒计时
  void _startCountdown() {
    setState(() {
      _countdown = 60;
    });
    
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  // 验证码登录
  Future<void> _loginWithCode() async {
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();

    // 验证手机号
    if (phone.isEmpty || !RegExp(r'^1[3-9]\d{9}$').hasMatch(phone)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请输入正确的手机号码')),
        );
      }
      return;
    }

    // 验证验证码
    if (code.isEmpty || code.length != 6) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请输入6位验证码')),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 获取设备信息
      final deviceId = await DeviceInfoService.getDeviceId();
      final deviceName = await DeviceInfoService.getDeviceName();
      final deviceType = await DeviceInfoService.getDeviceType();

      print('[Login] 获取到的设备信息:');
      print('  - deviceId: $deviceId');
      print('  - deviceName: $deviceName');
      print('  - deviceType: $deviceType');

      final response = await ApiService().loginWithCode(
        phone,
        code,
        deviceId: deviceId,
        deviceName: deviceName,
        deviceType: deviceType,
      );

      if (response['success'] == true) {
        final data = response['data'];
        final token = data['token'];
        
        if (token == null || token.isEmpty) {
          throw Exception('登录成功但未获取到token');
        }

        // 保存token和登录状态
        await StorageService.setAuthToken(token);
        await StorageService.setLoggedIn(true);
        await StorageService.setLoginType('phone');

        if (mounted) {
          final homeStyle = await StorageService.getHomeStyle();
          Navigator.pushNamedAndRemoveUntil(
            context,
            homeStyle == 'classic' ? AppRoutes.home : AppRoutes.homeImmersive,
            (route) => false,
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['message'] ?? '登录失败')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('登录失败: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
