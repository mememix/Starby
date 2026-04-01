// lib/screens/profile/profile_screen.dart
// 个人中心页 - 简化版

import 'dart:convert';
import 'package:flutter/material.dart';
import '../../constants/colors.dart';
import '../../models/user.dart';
import '../../routes.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool isPhoneLogin = true;
  User? _currentUser;
  bool _isLoading = true;

  int _myPartners = 0;
  int _sharedMembers = 0;
  int _checkInDays = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // 将base64头像数据转换为ImageProvider
  ImageProvider? _getAvatarImage(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return null;
    }
    
    // 检查是否为data:image/开头的base64数据URI
    if (avatarUrl.startsWith('data:image/') && avatarUrl.contains(';base64,')) {
      try {
        // 提取base64部分
        final base64String = avatarUrl.split(';base64,').last;
        if (base64String.isEmpty) {
          return null;
        }
        final bytes = base64.decode(base64String);
        return MemoryImage(bytes);
      } catch (e) {
        debugPrint('[ProfileScreen] 解析base64头像失败: $e');
        return null;
      }
    } else if (avatarUrl.startsWith('/')) {
      // 相对路径，需要拼接服务器地址
      final baseUrl = ApiService.baseUrl;
      final serverUrl = baseUrl.replaceAll(RegExp(r'/api$'), '');
      debugPrint('[ProfileScreen] 原始avatarUrl: $avatarUrl');
      debugPrint('[ProfileScreen] serverUrl: $serverUrl');
      // 去除重复的uploads/remote/前缀
      String cleanPath = avatarUrl;
      if (avatarUrl.contains('/uploads/remote/uploads/remote/')) {
        cleanPath = avatarUrl.replaceAll('/uploads/remote/uploads/remote/', '/uploads/remote/');
        debugPrint('[ProfileScreen] 去重后的cleanPath: $cleanPath');
      }
      final finalUrl = '$serverUrl$cleanPath';
      debugPrint('[ProfileScreen] 拼接头像URL: $finalUrl');
      return NetworkImage(finalUrl);
    } else {
      // 如果是普通的网络URL，使用NetworkImage
      return NetworkImage(avatarUrl);
    }
  }

  Future<void> _loadData() async {
    // 检查登录类型
    final isDevice = await StorageService.isDeviceLogin();
    setState(() {
      isPhoneLogin = !isDevice;
    });

    // 如果是手机号登录，加载用户信息
    if (isPhoneLogin) {
      try {
        debugPrint('[ProfileScreen] 开始加载用户信息');
        // 优先从API获取最新用户信息
        final response = await ApiService().getCurrentUser();
        debugPrint('[ProfileScreen] API响应: $response');

        if (response['success'] == true && response['data'] != null) {
          final userData = response['data']['user'] as Map<String, dynamic>?;
          debugPrint('[ProfileScreen] 用户数据: $userData');

          if (userData == null || userData.isEmpty) {
            debugPrint('[ProfileScreen] 用户数据为空，尝试从本地加载');
            throw Exception('用户数据为空');
          }

          // 从本地获取phone和token（因为API可能不返回phone和token）
          final localPhone = await StorageService.getUserPhone();
          final token = await StorageService.getAuthToken();

          // 合并数据，确保包含phone和token
          final mergedUserData = Map<String, dynamic>.from(userData);
          if (localPhone != null && (mergedUserData['phone'] == null || mergedUserData['phone'].toString().isEmpty)) {
            mergedUserData['phone'] = localPhone;
          }
          // 确保token存在
          if (token != null && token.isNotEmpty && (mergedUserData['token'] == null || mergedUserData['token'].toString().isEmpty)) {
            mergedUserData['token'] = token;
          }

          debugPrint('[ProfileScreen] 合并后的数据: $mergedUserData');

          // 保存到本地存储
          await StorageService.saveUserInfo({
            'id': mergedUserData['id'],
            'phone': mergedUserData['phone'],
            'nickname': mergedUserData['nickname'] ?? '',
            'avatar': mergedUserData['avatar'],
            'token': token ?? mergedUserData['token'] ?? '',
          });

          // 尝试创建User对象
          try {
            setState(() {
              _currentUser = User.fromJson(mergedUserData);
              _isLoading = false;
            });
            debugPrint('[ProfileScreen] 用户信息加载成功');
          } catch (userError) {
            debugPrint('[ProfileScreen] User.fromJson失败: $userError');
            debugPrint('[ProfileScreen] mergedUserData: $mergedUserData');
            rethrow;
          }
        } else {
          debugPrint('[ProfileScreen] API返回失败，尝试从本地加载');
          // 如果API失败，尝试从本地存储加载
          final userInfo = await StorageService.getUserInfo();
          debugPrint('[ProfileScreen] 本地用户信息: $userInfo');
          if (userInfo != null && userInfo['phone'] != null) {
            setState(() {
              _currentUser = User.fromJson(userInfo);
              _isLoading = false;
            });
          } else {
            setState(() => _isLoading = false);
          }
        }
      } catch (e) {
        debugPrint('[ProfileScreen] 加载用户信息失败: $e');
        debugPrint('[ProfileScreen] 错误类型: ${e.runtimeType}');
        debugPrint('[ProfileScreen] 错误详情: ${e.toString()}');
        // 如果API失败，尝试从本地存储加载
        try {
          final userInfo = await StorageService.getUserInfo();
          debugPrint('[ProfileScreen] 本地用户信息: $userInfo');
          if (userInfo != null && userInfo['phone'] != null) {
            setState(() {
              _currentUser = User.fromJson(userInfo);
              _isLoading = false;
            });
            debugPrint('[ProfileScreen] 从本地加载成功');
          } else {
            debugPrint('[ProfileScreen] 本地用户信息为空或缺少phone字段');
            setState(() => _isLoading = false);
          }
        } catch (e2) {
          debugPrint('[ProfileScreen] 本地加载也失败: $e2');
          debugPrint('[ProfileScreen] 本地加载错误类型: ${e2.runtimeType}');
          debugPrint('[ProfileScreen] 本地加载错误详情: ${e2.toString()}');
          setState(() => _isLoading = false);
        }
      }

      // 加载统计数据
      await _loadStats();
    } else {
      setState(() => _isLoading = false);
    }
  }

  // 单独加载统计数据
  Future<void> _loadStats() async {
    try {
      final statsResponse = await ApiService().getUserStats();
      if (statsResponse['success'] == true && statsResponse['data'] != null) {
        final statsData = statsResponse['data'];
        debugPrint('[ProfileScreen] 统计数据: $statsData');
        setState(() {
          _myPartners = statsData['myPartners'] ?? 0;
          _sharedMembers = statsData['sharedMembers'] ?? 0;
          _checkInDays = statsData['checkInDays'] ?? 0;
        });
      }
    } catch (e) {
      debugPrint('[ProfileScreen] 加载统计数据失败: $e');
      // 保持现有数据不变
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // 顶部标题
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey),
                ),
              ),
              child: const Center(
                child: Text(
                  '我的',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),

            // 内容区域
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // 用户信息卡片 - 仅手机号登录显示
                    if (isPhoneLogin) ...[
                      _buildUserInfoCard(),
                      const SizedBox(height: 16),
                    ],
                    // 设置菜单
                    _buildSettingsMenu(),
                    const SizedBox(height: 20),
                    // 退出登录按钮
                    _buildLogoutButton(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 用户信息卡片
  Widget _buildUserInfoCard() {
    // 确保使用最新的数据
    final displayName = _currentUser?.nickname ?? _currentUser?.name ?? '未设置昵称';
    final displayPhone = _currentUser?.phonenumber ?? _currentUser?.phone ?? '';

    // 格式化手机号：只显示前3位和后4位
    String formattedPhone = '';
    if (displayPhone.length >= 7) {
      formattedPhone = '${displayPhone.substring(0, 3)}****${displayPhone.substring(displayPhone.length - 4)}';
    } else {
      formattedPhone = displayPhone;
    }

    debugPrint('[ProfileScreen] 显示信息: name=$displayName, phone=$displayPhone, avatar=${_currentUser?.avatar}');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            Color(0xFFFFB7C0),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 2,
                  ),
                  image: _currentUser?.avatar != null && _currentUser!.avatar!.isNotEmpty
                      ? (_getAvatarImage(_currentUser!.avatar) != null
                          ? DecorationImage(
                              image: _getAvatarImage(_currentUser!.avatar)!,
                              fit: BoxFit.cover,
                            )
                          : null)
                      : null,
                ),
                child: _currentUser?.avatar == null || _currentUser!.avatar!.isEmpty
                    ? const Icon(
                        Icons.person,
                        size: 32,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formattedPhone,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem('$_myPartners', '我的伙伴'),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              Expanded(
                child: _buildStatItem('$_sharedMembers', '共享成员'),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              Expanded(
                child: _buildStatItem('$_checkInDays', '打卡天数'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 统计项
  Widget _buildStatItem(String count, String label) {
    return GestureDetector(
      onTap: () async {
        // 打卡天数点击跳转到打卡页面
        if (label == '打卡天数') {
          await Navigator.pushNamed(context, AppRoutes.checkin);
          // 从打卡页面返回后刷新统计数据
          if (mounted && isPhoneLogin) {
            _loadStats();
          }
        }
      },
      child: Column(
        children: [
          Text(
            count,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  // 设置菜单
  Widget _buildSettingsMenu() {
    final List<Map<String, dynamic>> menuItems = [
      {
        'icon': Icons.notifications_outlined,
        'title': '通知设置',
        'onTap': () {
          Navigator.pushNamed(context, AppRoutes.settingsNotification);
        },
      },
    ];

    // 个人资料、账号安全、界面风格 - 仅手机号登录显示
    if (isPhoneLogin) {
      menuItems.addAll([
        {
          'icon': Icons.edit_outlined,
          'title': '个人资料',
          'onTap': () async {
            final result = await Navigator.pushNamed(context, AppRoutes.profileEdit);
            if (result == true) {
              // 刷新用户信息
              _loadData();
            }
          },
        },
        {
          'icon': Icons.security_outlined,
          'title': '账号安全',
          'onTap': () {
            Navigator.pushNamed(context, AppRoutes.settingsAccountSecurity);
          },
        },
        {
          'icon': Icons.palette_outlined,
          'title': '界面风格',
          'onTap': () {
            Navigator.pushNamed(context, AppRoutes.settingsTheme);
          },
        },
        {
          'icon': Icons.help_outline,
          'title': '帮助中心',
          'onTap': () {
            Navigator.pushNamed(context, AppRoutes.settingsHelp);
          },
        },
      ]);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        children: List.generate(menuItems.length, (index) {
          final item = menuItems[index];
          final isLast = index == menuItems.length - 1;
          return Column(
            children: [
              ListTile(
                leading: Icon(
                  item['icon'] as IconData,
                  color: AppColors.primary,
                ),
                title: Text(item['title'] as String),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: item['onTap'] as VoidCallback,
              ),
              if (!isLast)
                Container(
                  height: 1,
                  color: Colors.grey[100],
                  margin: const EdgeInsets.only(left: 64),
                ),
            ],
          );
        }),
      ),
    );
  }

  // 退出登录按钮
  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('退出登录'),
              content: const Text('确定要退出登录吗？'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // 清除所有用户数据
                    await StorageService.clearAllUserData();
                    ApiService().clearAuthToken();
                    
                    if (mounted) {
                      Navigator.pop(context);
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        AppRoutes.login,
                        (route) => false,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF44336),
                  ),
                  child: const Text('确认退出'),
                ),
              ],
            ),
          );
        },
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFF44336)),
          foregroundColor: const Color(0xFFF44336),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          '退出登录',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
