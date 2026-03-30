// lib/screens/splash/splash_screen.dart
// 启动页面 - 检查用户风格偏好

import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../routes.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  Future<void> _navigateToHome() async {
    // 等待2秒展示启动页
    await Future.delayed(const Duration(seconds: 2));

    // 检查用户是否登录
    final isLoggedIn = await StorageService.isLoggedIn();
    final token = await StorageService.getAuthToken();
    final tokenPreview = token != null && token.length > 20 
        ? '${token.substring(0, 20)}...' 
        : (token ?? 'null');
    debugPrint('[Splash] isLoggedIn: $isLoggedIn, token: $tokenPreview');

    // 如果已登录且token存在，提前设置到ApiService
    if (isLoggedIn && token != null && token.isNotEmpty) {
      ApiService().setAuthToken(token);
      debugPrint('[Splash] Set token to ApiService, navigate to home');
    }

    if (mounted) {
      // 只有当 isLoggedIn 为 true 且 token 不为空时，才认为是真正登录
      final actuallyLoggedIn = isLoggedIn && token != null && token.isNotEmpty;
      
      if (!actuallyLoggedIn) {
        // 未登录或token无效，清除状态并跳转到登录页
        debugPrint('[Splash] No valid token, redirect to login');
        await StorageService.setLoggedIn(false);
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      } else {
        // 已登录，检查用户风格偏好后跳首页
        final isClassic = await StorageService.isClassicStyle();
        debugPrint('[Splash] actuallyLoggedIn = true, navigate to ${isClassic ? 'home classic' : 'home immersive'}');
        if (isClassic) {
          Navigator.pushReplacementNamed(context, AppRoutes.home);
        } else {
          Navigator.pushReplacementNamed(context, AppRoutes.homeImmersive);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary,
              Color(0xFFF0B0B8),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 星图标
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.star,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              // 标题
              const Text(
                '星护伙伴',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              // 副标题
              Text(
                '守护你爱的人',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.85),
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 48),
              // 加载指示器
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
