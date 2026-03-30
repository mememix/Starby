// lib/screens/profile/profile_edit_screen.dart
// 个人信息编辑页

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../constants/colors.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameController = TextEditingController();
  final _bioController = TextEditingController();
  String? _gender;
  String? _region;
  String? _avatar;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _bioController.dispose();
    super.dispose();
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
        debugPrint('[ProfileEdit] 解析base64头像失败: $e');
        return null;
      }
    } else {
      // 如果是普通的网络URL，使用NetworkImage
      return NetworkImage(avatarUrl);
    }
  }

  // 加载用户资料
  Future<void> _loadUserProfile() async {
    try {
      final response = await ApiService().getCurrentUser();
      if (response['success'] == true) {
        final userData = response['data']['user'];
        debugPrint('[ProfileEdit] 加载用户数据: $userData');
        setState(() {
          _nicknameController.text = userData['nickname'] ?? '';
          _bioController.text = userData['bio'] ?? '';
          _gender = userData['gender'];
          _region = userData['region'];
          _avatar = userData['avatar'];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[ProfileEdit] 加载失败: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载用户资料失败: $e')),
        );
      }
    }
  }

  // 选择头像
  Future<void> _pickAvatar() async {
    try {
      // 请求相机和存储权限
      final status = await Permission.camera.request();
      final photosStatus = await Permission.photos.request();
      
      if (!status.isGranted && !photosStatus.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请授予相机和相册权限')),
          );
        }
        return;
      }

      final ImagePicker picker = ImagePicker();
      final XFile? image = await showModalBottomSheet<XFile>(
        context: context,
        builder: (context) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('拍照'),
                onTap: () async {
                  Navigator.pop(context, await picker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 30,
                    maxWidth: 128,
                    maxHeight: 128,
                  ));
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('从相册选择'),
                onTap: () async {
                  Navigator.pop(context, await picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 30,
                    maxWidth: 128,
                    maxHeight: 128,
                  ));
                },
              ),
            ],
          ),
        ),
      );

      if (image != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('正在上传头像...')),
          );
        }

        try {
          // 注意：这里暂时使用base64上传，实际应该使用multipart/form-data
          final bytes = await image.readAsBytes();
          final base64Image = base64Encode(bytes);
          // 构建图片URL（临时方案，实际应该由后端返回）
          final avatarUrl = 'data:image/jpeg;base64,$base64Image';

          // 检查图片大小（整个URL最大5000字符，这是服务器最终限制）
          const maxUrlLength = 5000; // 服务器最终限制
          const maxOriginalBytes = 3500; // 原始图片字节数限制（base64编码后会增大）
          
          // 先检查原始字节大小
          if (bytes.length > maxOriginalBytes) {
            debugPrint('[ProfileEdit] 图片原始字节过大: ${bytes.length}字节 > 限制$maxOriginalBytes字节');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('图片太大（${(bytes.length / 1024).toStringAsFixed(1)}KB），请选择更小的图片'),
                  duration: const Duration(seconds: 5),
                ),
              );
            }
            return;
          }
          
          // 再检查base64 URL长度
          if (avatarUrl.length > maxUrlLength) {
            debugPrint('[ProfileEdit] 图片过大: URL长度=${avatarUrl.length}, 限制=$maxUrlLength');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('图片过大（${avatarUrl.length}字符），请选择更小的图片'),
                  duration: const Duration(seconds: 5),
                ),
              );
            }
            return;
          }

          // 调用API更新用户头像
          debugPrint('[ProfileEdit] 上传头像URL长度: ${avatarUrl.length}, base64数据长度: ${base64Image.length}');
          final response = await ApiService().uploadUserAvatar(avatarUrl);
          debugPrint('[ProfileEdit] 头像上传响应: $response');

          // 从响应中获取更新后的头像URL
          String? updatedAvatarUrl;
          if (response['success'] == true) {
            updatedAvatarUrl = response['data']['user']['avatar'];
            debugPrint('[ProfileEdit] 更新后的头像URL: $updatedAvatarUrl');
          }

          if (mounted) {
            setState(() => _avatar = updatedAvatarUrl ?? avatarUrl);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('头像已更新')),
            );
          }
        } catch (e) {
          debugPrint('[ProfileEdit] 头像上传失败: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('上传失败: $e')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择头像失败: $e')),
        );
      }
    }
  }

  // 保存用户资料
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final data = <String, dynamic>{
        'nickname': _nicknameController.text.trim(),
        'bio': _bioController.text.trim(),
      };

      // 只添加非空的字段
      if (_gender != null && _gender!.isNotEmpty) {
        data['gender'] = _gender;
      }
      if (_avatar != null && _avatar!.isNotEmpty) {
        data['avatar'] = _avatar;
      }

      debugPrint('[ProfileEdit] 保存数据: $data');

      final response = await ApiService().updateUser(data);
      debugPrint('[ProfileEdit] 保存响应: $response');

      if (response['success'] == true) {
        // 更新本地存储的用户信息
        final userData = response['data']['user'];
        final phone = await StorageService.getUserPhone();
        final token = await StorageService.getAuthToken();

        final updatedUserInfo = {
          'id': userData['id'],
          'phone': phone,
          'nickname': userData['nickname'],
          'avatar': userData['avatar'],
          'gender': userData['gender'],
          'bio': userData['bio'],
          'token': token ?? '',
        };

        await StorageService.saveUserInfo(updatedUserInfo);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('保存成功')),
          );
          Navigator.pop(context, true);
        }
      } else {
        throw Exception(response['message'] ?? '保存失败');
      }
    } catch (e) {
      debugPrint('[ProfileEdit] 保存失败: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // 顶部导航栏
          _buildHeader(),

          const SizedBox(height: 20),

          // 编辑表单
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Form(
                key: _formKey,
                child: _buildEditForm(),
              ),
            ),
          ),

          // 保存按钮
          Padding(
            padding: const EdgeInsets.all(20),
            child: _buildSaveButton(),
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
        children: [
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
            },
            child: const Icon(
              Icons.arrow_back,
              size: 24,
              color: AppColors.textSecondary,
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                '编辑资料',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
        ],
      ),
    );
  }

  // 编辑表单
  Widget _buildEditForm() {
    return Column(
      children: [
        // 头像区域
        GestureDetector(
          onTap: _pickAvatar,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[100]!),
            ),
            child: Column(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE8EB),
                        shape: BoxShape.circle,
                        image: _avatar != null
                            ? DecorationImage(
                                image: _getAvatarImage(_avatar)!,
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _avatar == null
                          ? const Icon(
                              Icons.person,
                              size: 40,
                              color: AppColors.primary,
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  '点击更换头像',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 表单字段
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[100]!),
          ),
          child: Column(
            children: [
              _buildFormField(
                label: '昵称',
                hintText: '请输入昵称',
                controller: _nicknameController,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入昵称';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildFormField(
                label: '性别',
                hintText: _gender ?? '请选择性别',
                value: _gender,
                enabled: false,
                onTap: () {
                  _showGenderPicker();
                },
              ),
              const SizedBox(height: 16),
              // 地区暂时隐藏（数据库没有这个字段）
              // _buildFormField(
              //   label: '地区',
              //   hintText: _region ?? '请选择地区',
              //   value: _region,
              //   enabled: false,
              //   onTap: () {
              //     _showRegionPicker();
              //   },
              // ),
              // const SizedBox(height: 16),
              _buildFormField(
                label: '个人简介',
                hintText: '请输入个人简介',
                controller: _bioController,
                maxLines: 3,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 表单字段
  Widget _buildFormField({
    required String label,
    required String hintText,
    TextEditingController? controller,
    String? value,
    bool enabled = true,
    int maxLines = 1,
    String? Function(String?)? validator,
    VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: AbsorbPointer(
            absorbing: onTap != null || !enabled,
            child: TextFormField(
              enabled: enabled,
              maxLines: maxLines,
              controller: controller,
              initialValue: value,
              validator: validator,
              decoration: InputDecoration(
                hintText: hintText,
                filled: true,
                fillColor: enabled ? Colors.grey[50] : Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.red, width: 1),
                ),
                suffixIcon: onTap != null
                    ? Icon(
                        Icons.chevron_right,
                        color: Colors.grey[400],
                      )
                    : null,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 保存按钮
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: AppColors.primary.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                '保存',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  // 性别选择器
  void _showGenderPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '选择性别',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              title: const Text('男'),
              trailing: _gender == '男'
                  ? const Icon(Icons.check, color: AppColors.primary)
                  : null,
              onTap: () {
                setState(() => _gender = '男');
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              title: const Text('女'),
              trailing: _gender == '女'
                  ? const Icon(Icons.check, color: AppColors.primary)
                  : null,
              onTap: () {
                setState(() => _gender = '女');
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // 地区选择器
  void _showRegionPicker() {
    final regions = ['北京市', '上海市', '广东省', '浙江省', '江苏省', '四川省', '湖北省', '湖南省'];
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '选择地区',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ...regions.map((region) => ListTile(
                  title: Text(region),
                  onTap: () {
                    setState(() => _region = region);
                    Navigator.pop(context);
                  },
                )),
          ],
        ),
      ),
    );
  }
}
