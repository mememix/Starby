// lib/screens/device/partner_share_list_screen.dart
// 伙伴共享成员列表页

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dio/dio.dart';
import '../../constants/colors.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';

class PartnerShareListScreen extends StatefulWidget {
  const PartnerShareListScreen({super.key});

  @override
  State<PartnerShareListScreen> createState() => _PartnerShareListScreenState();
}

class _PartnerShareListScreenState extends State<PartnerShareListScreen> {
  String? _deviceId;
  int _sharedMemberCount = 0;
  bool _isLoading = true;
  String? _errorMessage;

  // 共享成员列表
  final List<Map<String, dynamic>> _members = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 从路由参数获取数据
    final args = ModalRoute.of(context)?.settings.arguments;
    debugPrint('[PartnerShareListScreen] 路由参数: $args');
    if (args != null && args is Map<String, dynamic>) {
      _deviceId = args['deviceId'] as String?;
      _sharedMemberCount = args['sharedMemberCount'] as int? ?? 0;
      debugPrint('[PartnerShareListScreen] 设备ID: $_deviceId, 共享成员数: $_sharedMemberCount');

      // 加载共享成员列表
      if (_deviceId != null) {
        _loadShares();
      }
    }
  }

  // 加载共享成员列表
  Future<void> _loadShares() async {
    if (_deviceId == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await StorageService.getAuthToken();
      if (token != null) {
        ApiService().setAuthToken(token);
      }

      final response = await ApiService().getDeviceShares(_deviceId!);
      debugPrint('[PartnerShareListScreen] 共享成员API响应: $response');

      if (response['success'] == true && response['data'] != null) {
        final shares = response['data']['shares'] as List;
        setState(() {
          _members.clear();
          for (var share in shares) {
            // 格式化手机号：只显示前3位和后4位
            String phone = share['phone'] ?? '';
            String formattedPhone = '';
            if (phone.length >= 7) {
              formattedPhone = '${phone.substring(0, 3)}****${phone.substring(phone.length - 4)}';
            } else {
              formattedPhone = phone;
            }

            // 映射角色名称
            String roleLabel = share['role'];
            if (roleLabel == 'admin') {
              roleLabel = '管理员';
            } else if (roleLabel == 'member') {
              roleLabel = '成员';
            }

            // 生成头像emoji
            String avatar = _getAvatarEmoji(share['name'] ?? formattedPhone);

            _members.add({
              'id': share['id'],
              'name': share['name'],
              'phone': formattedPhone,
              'avatar': avatar,
              'role': roleLabel,
              'roleKey': share['role'],
              'status': share['status'],
            });
          }
          _sharedMemberCount = _members.length;
          _isLoading = false;
        });
        debugPrint('[PartnerShareListScreen] 共享成员加载成功，共 ${_members.length} 人');
      } else {
        setState(() {
          _errorMessage = response['message'] ?? '加载共享成员失败';
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      String message = '网络错误，请稍后重试';
      if (e.response != null) {
        final data = e.response?.data as Map<String, dynamic>;
        message = data['message'] ?? message;
      }
      if (mounted) {
        setState(() {
          _errorMessage = message;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[PartnerShareListScreen] 加载共享成员失败: $e');
      if (mounted) {
        setState(() {
          _errorMessage = '加载失败: $e';
          _isLoading = false;
        });
      }
    }
  }

  // 生成头像emoji
  String _getAvatarEmoji(String name) {
    const avatars = ['👨', '👩', '👴', '👵', '👶', '👷', '👨‍👩‍👧', '👨‍👩‍👦'];
    final hashCode = name.hashCode;
    return avatars[hashCode.abs() % avatars.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _buildErrorView()
                    : _members.isEmpty
                        ? _buildEmptyView()
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _members.length,
                            itemBuilder: (context, index) {
                              return _buildMemberItem(_members[index]);
                            },
                          ),
          ),
          _buildAddButton(),
        ],
      ),
    );
  }

  // 构建错误视图
  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? '加载失败',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadShares,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }

  // 构建空视图
  Widget _buildEmptyView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            '暂无共享成员',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            '点击下方按钮添加共享成员',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

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
          const Expanded(
            child: Center(
              child: Text(
                '共享成员',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildMemberItem(Map<String, dynamic> member) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(
              child: Text(
                member['avatar'],
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      member['name'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: member['role'] == '管理员'
                            ? const Color(0xFFFFE8EB)
                            : const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        member['role'],
                        style: TextStyle(
                          fontSize: 12,
                          color: member['role'] == '管理员'
                              ? AppColors.primary
                              : const Color(0xFF2196F3),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  member['phone'],
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (member['roleKey'] != 'admin' && member['role'] != '管理员')
            TextButton(
              onPressed: () {
                // 移除成员 - 显示确认弹窗
                _showRemoveConfirmDialog(member);
              },
              child: const Text(
                '移除',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () {
              _showAddMemberDialog();
            },
            icon: const Icon(Icons.person_add),
            label: const Text(
              '添加共享成员',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 显示添加共享成员对话框
  void _showAddMemberDialog() {
    final phoneController = TextEditingController();
    bool isAdding = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('添加共享成员'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: '请输入成员手机号',
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[200]!),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _shareToOtherApps();
                        },
                        icon: const Icon(Icons.share),
                        label: const Text('分享到其他应用'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: isAdding
                    ? null
                    : () async {
                        final phone = phoneController.text.trim();
                        if (phone.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('请输入手机号')),
                          );
                          return;
                        }

                        setDialogState(() => isAdding = true);

                        try {
                          final response = await ApiService().addDeviceShare(
                            _deviceId!,
                            phone,
                          );

                          if (mounted) {
                            Navigator.pop(context);

                            if (response['success'] == true) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('共享成员已添加')),
                              );
                              // 重新加载列表
                              _loadShares();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      response['message'] ?? '添加失败'),
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          debugPrint('[PartnerShareListScreen] 添加共享成员失败: $e');
                          if (mounted) {
                            setDialogState(() => isAdding = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('添加失败: $e')),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: isAdding
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('确认添加'),
              ),
            ],
          );
        },
      ),
    );
  }

  // 显示移除确认对话框
  void _showRemoveConfirmDialog(Map<String, dynamic> member) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('移除共享成员'),
        content: Text('确定要移除 ${member['name']} 吗？移除后该成员将无法查看此伙伴位置。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                final response = await ApiService().removeDeviceShare(
                  _deviceId!,
                  member['id'],
                );

                if (response['success'] == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('已移除 ${member['name']}')),
                  );
                  // 重新加载列表
                  _loadShares();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(response['message'] ?? '移除失败'),
                    ),
                  );
                }
              } catch (e) {
                debugPrint('[PartnerShareListScreen] 移除共享成员失败: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('移除失败: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('确认移除'),
          ),
        ],
      ),
    );
  }

  // 分享到其他应用
  Future<void> _shareToOtherApps() async {
    try {
      await Share.share(
        '快来加入Starby，和我们一起守护家人安全！\n\n下载链接：https://example.com/download',
        subject: '邀请您加入Starby',
      );
    } catch (e) {
      debugPrint('[PartnerShareListScreen] 分享失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败: ${e.toString()}')),
        );
      }
    }
  }
}
