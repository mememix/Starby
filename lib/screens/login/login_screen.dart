// lib/screens/login/login_screen.dart
// 登录页 - 主登录页 v5
// 展示两种登录方式标签：手机号登录 / 伙伴号登录

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../constants/colors.dart';
import '../../routes.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  int _selectedTab = 0; // 0: 手机号登录, 1: 伙伴号登录
  bool _checking = true;

  // 手机号登录的 controllers
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _phonePasswordController = TextEditingController();

  // 伙伴号登录的 controllers
  final TextEditingController _deviceController = TextEditingController();
  final TextEditingController _devicePasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phonePasswordController.dispose();
    _deviceController.dispose();
    _devicePasswordController.dispose();
    super.dispose();
  }

  // 检查是否已经登录，如果已登录直接跳首页
  Future<void> _checkLoginStatus() async {
    final isLoggedIn = await StorageService.isLoggedIn();
    final token = await StorageService.getAuthToken();
    final actuallyLoggedIn = isLoggedIn && token != null && token.isNotEmpty;
    
    if (actuallyLoggedIn && mounted) {
      final isClassic = await StorageService.isClassicStyle();
      if (isClassic) {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.homeImmersive);
      }
    } else {
      setState(() {
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
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
          child: const Center(child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          )),
        ),
      );
    }
    return Scaffold(
      resizeToAvoidBottomInset: true,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 48),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildLogo(),
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildTabSwitch(),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  ),
                  child: _selectedTab == 0
                      ? _buildPhonePasswordForm()
                      : _buildDevicePasswordForm(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Logo区域
  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFE797A2),
                Color(0xFFF5B5BD),
              ],
            ),
          ),
          child: const Icon(
            Icons.location_on_outlined,
            size: 40,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '星护伙伴',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '随时守护家人安全',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  // 标签切换
  Widget _buildTabSwitch() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedTab = 0;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _selectedTab == 0 
                          ? AppColors.primary 
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '手机号登录',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _selectedTab == 0 
                            ? Colors.white 
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedTab = 1;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _selectedTab == 1 
                          ? AppColors.primary 
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '伙伴号登录',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _selectedTab == 1 
                            ? Colors.white 
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  // 手机号密码登录表单
  Widget _buildPhonePasswordForm() {
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
          '密码',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _phonePasswordController,
          obscureText: true,
          decoration: InputDecoration(
            hintText: '请输入密码',
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
        const SizedBox(height: 24),
        // 登录按钮
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () async {
              final phone = _phoneController.text.trim();
              final password = _phonePasswordController.text.trim();
              
              if (phone.isEmpty || password.isEmpty) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请输入手机号和密码')),
                  );
                }
                return;
              }
              
              try {
                final response = await ApiService().login(phone, password);
                debugPrint('[LoginScreen] Response: $response');
                debugPrint('[LoginScreen] Response type: ${response.runtimeType}');

                // 先检查登录是否成功
                if (response['success'] != true) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(response['message'] ?? '登录失败')),
                    );
                  }
                  return;
                }

                // 检查 data 字段是否存在
                if (!response.containsKey('data') || response['data'] == null) {
                  throw Exception('响应中缺少data字段');
                }

                final data = response['data'];
                if (data is! Map<String, dynamic>) {
                  throw Exception('data字段格式错误: 期望Map，收到${data.runtimeType}');
                }

                if (!data.containsKey('token') || data['token'] == null) {
                  throw Exception('响应中缺少token字段');
                }

                final token = data['token'].toString();
                debugPrint('[LoginScreen] Token extracted: ${token.length > 20 ? '${token.substring(0, 20)}...' : token}');

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
              } catch (e) {
                debugPrint('[LoginScreen] Login error: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('登录失败: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: AppColors.primary.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '登录',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // 添加验证码登录入口
        Center(
          child: TextButton(
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.phoneCodeLogin);
            },
            child: const Text(
              '验证码登录',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // 底部注册按钮
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

  // 伙伴号密码登录表单
  Widget _buildDevicePasswordForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '伙伴号',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _deviceController,
          decoration: InputDecoration(
            hintText: '请输入伙伴号',
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
            suffixIcon: IconButton(
              icon: const Icon(Icons.qr_code_scanner, color: AppColors.primary),
              onPressed: () => _showDeviceScanner(_deviceController),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '伙伴密码',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _devicePasswordController,
          obscureText: true,
          decoration: InputDecoration(
            hintText: '请输入密码',
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
        const SizedBox(height: 24),
        // 登录按钮
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () async {
              final deviceNo = _deviceController.text.trim();
              final password = _devicePasswordController.text.trim();
              
              if (deviceNo.isEmpty || password.isEmpty) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请输入伙伴号和密码')),
                  );
                }
                return;
              }
              
              try {
                // 伙伴号登录需要使用 deviceNo 参数
                final response = await ApiService().loginByDevice(deviceNo, password);
                debugPrint('[LoginScreen] Device login response: $response');
                debugPrint('[LoginScreen] Response type: ${response.runtimeType}');

                // 先检查登录是否成功
                if (response['success'] != true) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(response['message'] ?? '登录失败')),
                    );
                  }
                  return;
                }

                // 检查 data 字段是否存在
                if (!response.containsKey('data') || response['data'] == null) {
                  throw Exception('响应中缺少data字段');
                }

                final data = response['data'];
                if (data is! Map<String, dynamic>) {
                  throw Exception('data字段格式错误: 期望Map，收到${data.runtimeType}');
                }

                if (!data.containsKey('token') || data['token'] == null) {
                  throw Exception('响应中缺少token字段');
                }

                final token = data['token'].toString();
                debugPrint('[LoginScreen] Device login token: ${token.length > 20 ? '${token.substring(0, 20)}...' : token}');

                await StorageService.setAuthToken(token);
                await StorageService.setImmersiveStyle();
                await StorageService.setLoggedIn(true);
                await StorageService.setLoginType('device');
                if (mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.homeImmersive,
                    (route) => false,
                  );
                }
              } catch (e) {
                debugPrint('[LoginScreen] Device login error: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('登录失败: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: AppColors.primary.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '登录',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // 底部验证码登录入口
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '使用验证码登录? ',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.phoneCodeLogin);
              },
              child: const Text(
                '切换验证码',
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

  // 显示设备扫码页面
  void _showDeviceScanner(TextEditingController controller) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (scanContext) => Scaffold(
          appBar: AppBar(
            title: const Text('扫描二维码'),
            backgroundColor: AppColors.primary,
          ),
          body: MobileScanner(
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final String code = barcodes.first.rawValue ?? '';
                debugPrint('[LoginScreen] 扫码结果: $code');
                // 解析二维码内容，提取设备号
                String deviceNo = code;
                // 如果二维码包含完整URL，提取deviceNo参数
                if (code.contains('deviceNo=')) {
                  final parts = code.split('deviceNo=');
                  if (parts.length > 1) {
                    deviceNo = parts[1].split('&')[0];
                  }
                }
                debugPrint('[LoginScreen] 解析后的设备号: $deviceNo');
                // 先关闭扫码页面
                Navigator.pop(scanContext);
                // 然后填入设备号并显示提示
                controller.text = deviceNo;
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已自动填入设备号')),
                  );
                }
              }
            },
          ),
        ),
      ),
    );
  }
}
