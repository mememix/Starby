// lib/screens/device/partner_settings_screen.dart
// 伙伴设置页

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../constants/colors.dart';
import '../../models/device.dart';
import '../../routes.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';

class PartnerSettingsScreen extends StatefulWidget {
  const PartnerSettingsScreen({super.key, this.deviceId});

  final String? deviceId;

  @override
  State<PartnerSettingsScreen> createState() => _PartnerSettingsScreenState();
}

class _PartnerSettingsScreenState extends State<PartnerSettingsScreen> {
  late String deviceId;
  Device? _device;
  bool _isLoading = true;
  bool _isUnbinding = false;
  bool _isChangingPassword = false;
  String? _errorMessage;
  String? _customAvatar; // 自定义头像URL
  int _sharedMemberCount = 0; // 共享成员数量

  // 通知设置状态
  bool _fenceEnterNotification = true;
  bool _fenceExitNotification = true;
  bool _lowBatteryNotification = true;
  bool _sosNotification = true;


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 优先使用构造函数传递的 deviceId，其次使用路由参数
    final id = widget.deviceId ?? ModalRoute.of(context)?.settings.arguments as String?;
    if (id != null && id.isNotEmpty) {
      deviceId = id;
      _loadDeviceDetail();
    }
  }

  // 加载设备详情
  Future<void> _loadDeviceDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await StorageService.getAuthToken();
      if (token != null) {
        ApiService().setAuthToken(token);
      }

      // 并行加载设备详情和共享成员数量
      final results = await Future.wait([
        ApiService().getDeviceDetail(deviceId),
        ApiService().getDeviceSharesCount(deviceId),
      ]);

      final device = results[0] as Device;
      final shareCount = results[1] as int;

      if (mounted) {
        setState(() {
          _device = device;
          _sharedMemberCount = shareCount;
          _isLoading = false;
        });
        debugPrint('[PartnerSettingsScreen] 设备详情加载成功，共享成员数: $shareCount');
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.response?.data?['message'] ?? '加载设备详情失败';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '加载设备详情失败: $e';
          _isLoading = false;
        });
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

    if (_errorMessage != null || _device == null) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _errorMessage ?? '设备不存在',
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadDeviceDetail,
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

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
                  _buildPartnerName(),
                  const SizedBox(height: 16),
                  _buildPartnerAvatar(),
                  const SizedBox(height: 16),
                  _buildShareList(),
                  const SizedBox(height: 16),
                  _buildNotificationSettings(),
                  const SizedBox(height: 16),
                  _buildPartnerInfo(),
                  const SizedBox(height: 40),
                  _buildUnbindButton(),
                  const SizedBox(height: 40),
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
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey),
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
            '伙伴设置',
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

  // 修改伙伴名称
  Widget _buildPartnerName() {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '伙伴名称',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _device!.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              // 修改按钮仅手机号登录可点击
              FutureBuilder<bool>(
                future: StorageService.isDeviceLogin(),
                builder: (context, snapshot) {
                  final isDeviceLogin = snapshot.data ?? false;
                  if (!isDeviceLogin) {
                    return TextButton(
                      onPressed: () {
                        _showEditNameDialog();
                      },
                      child: const Text(
                        '修改',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 14,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 获取默认头像emoji
  String _getDefaultAvatar(String deviceName) {
    const avatars = ['🦁', '👶', '🐱', '👴', '👧', '👦', '🐶', '🐼', '🐯', '🦊'];
    final hashCode = deviceName.hashCode;
    return avatars[hashCode % avatars.length];
  }

  // 显示修改名称对话框
  void _showEditNameDialog() {
    final TextEditingController controller = TextEditingController(text: _device!.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改伙伴名称'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: '请输入伙伴名称',
                filled: true,
                fillColor: Colors.grey[50],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入伙伴名称')),
                );
                return;
              }
              // 更新设备名称
              try {
                await ApiService().updateDevice(deviceId, {'deviceName': newName});
                if (mounted) {
                  Navigator.pop(context);
                  _loadDeviceDetail();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('伙伴名称已修改')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('修改失败: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  // 修改伙伴头像
  Widget _buildPartnerAvatar() {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '伙伴头像',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<bool>(
                    future: StorageService.isDeviceLogin(),
                    builder: (context, snapshot) {
                      final isDeviceLogin = snapshot.data ?? false;
                      return GestureDetector(
                        onTap: !isDeviceLogin ? _showChangeAvatarDialog : null,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: _buildAvatarWidget(),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              // 修改按钮仅手机号登录可点击
              FutureBuilder<bool>(
                future: StorageService.isDeviceLogin(),
                builder: (context, snapshot) {
                  final isDeviceLogin = snapshot.data ?? false;
                  if (!isDeviceLogin) {
                    return TextButton(
                      onPressed: _showChangeAvatarDialog,
                      child: const Text(
                        '修改',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 14,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  // 构建头像Widget
  Widget _buildAvatarWidget() {
    // 优先使用自定义头像，其次使用设备头像
    String? avatarUrl = _customAvatar ?? _device?.avatar;

    // 如果头像URL为空，使用默认emoji头像
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return Text(
        _getDefaultAvatar(_device!.name),
        style: const TextStyle(fontSize: 32),
      );
    }

    // 检查是否是emoji（长度小于等于4个字符且不包含URL格式）
    final isEmoji = avatarUrl.length <= 4 && !avatarUrl.contains(RegExp(r'^(http|data|/)'));
    if (isEmoji) {
      return Text(
        avatarUrl,
        style: const TextStyle(fontSize: 32),
      );
    }

    // 检查是否是base64数据URI
    if (avatarUrl.startsWith('data:image/') && avatarUrl.contains(';base64,')) {
      try {
        final base64Data = avatarUrl.split(';base64,').last;
        if (base64Data.isEmpty) {
          return Text(
            _getDefaultAvatar(_device!.name),
            style: const TextStyle(fontSize: 32),
          );
        }
        final imageBytes = base64Decode(base64Data);
        return Image.memory(
          imageBytes,
          fit: BoxFit.cover,
          width: 64,
          height: 64,
          errorBuilder: (context, error, stackTrace) {
            return Text(
              _getDefaultAvatar(_device!.name),
              style: const TextStyle(fontSize: 32),
            );
          },
        );
      } catch (e) {
        // 解码失败，显示默认头像
        debugPrint('[PartnerSettings] 解码base64头像失败: $e');
        return Text(
          _getDefaultAvatar(_device!.name),
          style: const TextStyle(fontSize: 32),
        );
      }
    }

    // 网络图片URL（包括相对路径）
    String finalUrl = avatarUrl;
    if (avatarUrl.startsWith('/uploads/')) {
      // 获取API基础URL（静态属性）
      final baseUrl = ApiService.baseUrl;
      // 移除baseUrl末尾的 /api 部分
      final serverUrl = baseUrl.replaceAll(RegExp(r'/api$'), '');
      
      // 去除avatarUrl中重复的uploads/remote/前缀
      String cleanPath = avatarUrl;
      // 处理 /uploads/remote/uploads/remote/ 重复情况
      if (avatarUrl.contains('/uploads/remote/uploads/remote/')) {
        cleanPath = avatarUrl.replaceAll('/uploads/remote/uploads/remote/', '/uploads/remote/');
      }
      
      finalUrl = '$serverUrl$cleanPath';
      debugPrint('[PartnerSettings] 拼接头像URL: $finalUrl');
    }

    return Image.network(
      finalUrl,
      fit: BoxFit.cover,
      width: 64,
      height: 64,
      errorBuilder: (context, error, stackTrace) {
        return Text(
          _getDefaultAvatar(_device!.name),
          style: const TextStyle(fontSize: 32),
        );
      },
    );
  }
  
  // 显示更换头像对话框
  void _showChangeAvatarDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('更换伙伴头像'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('请选择上传方式'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _pickImage(ImageSource.gallery);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('从相册选择'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _pickImage(ImageSource.camera);
                },
                child: const Text('拍照'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  // 选择图片
  Future<void> _pickImage(ImageSource source) async {
    try {
      // 先显示权限请求确认对话框（仅相册）
      // 注意：Android平台通常不需要这个确认步骤，直接请求权限即可
      final isAndroid = Theme.of(context).platform == TargetPlatform.android;
      if (source == ImageSource.gallery && !isAndroid) {
        debugPrint('[Permission] iOS平台，显示权限确认对话框');
        final confirmed = await _showPermissionConfirmDialog('相册');
        if (!confirmed) {
          debugPrint('[Permission] 用户取消了权限确认');
          return;
        }
        debugPrint('[Permission] 用户确认了权限请求，开始请求相册权限');
      } else if (source == ImageSource.gallery && isAndroid) {
        debugPrint('[Permission] Android平台，直接请求相册权限（跳过确认对话框）');
      }

      // 请求相机或存储权限
      if (source == ImageSource.camera) {
        final status = await Permission.camera.request();
        debugPrint('[Permission] 相机权限状态: ${status.isGranted}, ${status.isPermanentlyDenied}');
        if (!status.isGranted) {
          // 如果权限被拒绝，检查是否可以打开应用设置
          if (status.isPermanentlyDenied) {
            if (mounted) {
              _showPermissionDialog('相机', () async {
                // 打开应用设置
                await openAppSettings();
              });
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('请授予相机权限以拍摄照片')),
              );
            }
          }
          return;
        }
      } else {
        // Android 13+ 使用 READ_MEDIA_IMAGES，Android 12 及以下使用 READ_EXTERNAL_STORAGE
        Permission permission = Permission.photos;

        // 先检查 Permission.photos 状态
        final status = await permission.status;
        debugPrint('[Permission] Permission.photos 状态: granted=${status.isGranted}, denied=${status.isDenied}, permanentlyDenied=${status.isPermanentlyDenied}, limited=${status.isLimited}');

        if (status.isGranted || status.isLimited) {
          debugPrint('[Permission] Permission.photos 已授权，直接选择照片');
          // 权限已授予，继续
        } else if (status.isPermanentlyDenied) {
          debugPrint('[Permission] Permission.photos 被永久拒绝，尝试使用 READ_EXTERNAL_STORAGE');
          // 尝试使用旧版权限
          permission = Permission.storage;
          final storageStatus = await permission.status;
          debugPrint('[Permission] READ_EXTERNAL_STORAGE 状态: granted=${storageStatus.isGranted}, permanentlyDenied=${storageStatus.isPermanentlyDenied}');

          if (storageStatus.isGranted) {
            debugPrint('[Permission] READ_EXTERNAL_STORAGE 已授权，使用旧版权限');
            // 权限已授予，继续
          } else if (storageStatus.isPermanentlyDenied) {
            debugPrint('[Permission] 所有相册权限都被永久拒绝，打开应用设置');
            if (mounted) {
              _showPermissionDialog('相册', () async {
                await openAppSettings();
              });
            }
            return;
          } else {
            // 请求 READ_EXTERNAL_STORAGE
            debugPrint('[Permission] 请求 READ_EXTERNAL_STORAGE 权限');
            final requestStatus = await permission.request();
            debugPrint('[Permission] 请求后 READ_EXTERNAL_STORAGE 状态: granted=${requestStatus.isGranted}, denied=${requestStatus.isDenied}, permanentlyDenied=${requestStatus.isPermanentlyDenied}');

            if (!requestStatus.isGranted) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请授予相册权限以选择照片')),
                );
              }
              return;
            }
          }
        } else {
          // Permission.photos 被拒绝但不是永久拒绝，请求权限
          debugPrint('[Permission] 请求 Permission.photos');
          final requestStatus = await permission.request();
          debugPrint('[Permission] 请求后 Permission.photos 状态: granted=${requestStatus.isGranted}, denied=${requestStatus.isDenied}, permanentlyDenied=${requestStatus.isPermanentlyDenied}, limited=${requestStatus.isLimited}');

          if (!requestStatus.isGranted && !requestStatus.isLimited) {
            // 尝试使用旧版权限
            debugPrint('[Permission] Permission.photos 授权失败，尝试使用 READ_EXTERNAL_STORAGE');
            permission = Permission.storage;
            final storageStatus = await permission.status;

            if (storageStatus.isGranted) {
              debugPrint('[Permission] READ_EXTERNAL_STORAGE 已授权，使用旧版权限');
              // 权限已授予，继续
            } else if (storageStatus.isPermanentlyDenied) {
              debugPrint('[Permission] 所有相册权限都被永久拒绝，打开应用设置');
              if (mounted) {
                _showPermissionDialog('相册', () async {
                  await openAppSettings();
                });
              }
              return;
            } else {
              // 请求 READ_EXTERNAL_STORAGE
              debugPrint('[Permission] 请求 READ_EXTERNAL_STORAGE 权限');
              final storageRequestStatus = await permission.request();
              debugPrint('[Permission] 请求后 READ_EXTERNAL_STORAGE 状态: granted=${storageRequestStatus.isGranted}, denied=${storageRequestStatus.isDenied}');

              if (!storageRequestStatus.isGranted) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请授予相册权限以选择照片')),
                  );
                }
                return;
              }
            }
          }
        }
        debugPrint('[Permission] 相册权限已授予，继续选择照片');
      }

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 60,
        maxWidth: 400,
        maxHeight: 400,
      );

      if (image != null) {
        try {
          debugPrint('[Avatar Upload] 开始上传设备头像: ${image.path}');

          // 显示加载提示
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('正在上传头像...')),
            );
          }

          // 使用新的文件上传接口
          final result = await ApiService().uploadDeviceAvatarFile(deviceId, image.path);
          debugPrint('[Avatar Upload] Server response: $result');

          // 先重新加载设备详情以获取服务器压缩后的头像
          await _loadDeviceDetail();

          // 重新加载后清除自定义头像，使用服务器返回的头像
          if (mounted) {
            setState(() => _customAvatar = null);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('头像上传成功')),
            );
            // 返回上一页，通知详情页刷新
            Navigator.pop(context, true);
          }
        } catch (e) {
          debugPrint('[Avatar Upload] Error: $e');

          // 解析错误信息
          String errorMessage = '上传头像失败';
          if (e is DioException) {
            if (e.response?.data != null) {
              final serverMessage = e.response!.data['message'];
              if (serverMessage != null) {
                errorMessage = serverMessage;
              }
            } else if (e.type == DioExceptionType.receiveTimeout) {
              errorMessage = '上传超时，请检查网络连接或尝试更小的图片';
            } else if (e.type == DioExceptionType.connectionTimeout) {
              errorMessage = '连接超时，请检查网络连接';
            }
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(errorMessage)),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: $e')),
        );
      }
    }
  }

  // 显示权限请求对话框
  void _showPermissionDialog(String permissionType, VoidCallback onOpenSettings) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('需要$permissionType权限'),
        content: Text('请在设置中授予应用$permissionType权限，以便您可以使用此功能。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onOpenSettings();
            },
            child: const Text('去设置'),
          ),
        ],
      ),
    );
  }

  // 显示权限请求确认对话框
  Future<bool> _showPermissionConfirmDialog(String permissionType) async {
    debugPrint('[Permission] 显示权限确认对话框: $permissionType');
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('请求$permissionType权限'),
        content: Text('需要访问您的$permissionType以选择照片，是否授予权限？'),
        actions: [
          TextButton(
            onPressed: () {
              debugPrint('[Permission] 用户点击取消');
              Navigator.pop(context, false);
            },
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              debugPrint('[Permission] 用户点击确认授予');
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('确认授予'),
          ),
        ],
      ),
    );
    debugPrint('[Permission] 对话框返回结果: $result');
    return result ?? false;
  }

  // 共享伙伴名单
  Widget _buildShareList() {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '共享伙伴',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '已共享给 $_sharedMemberCount 人',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  // 跳转到共享成员列表页，传递deviceId和sharedMemberCount
                  Navigator.pushNamed(context, AppRoutes.deviceShareList, arguments: {
                    'deviceId': deviceId,
                    'sharedMemberCount': _sharedMemberCount,
                  });
                },
                child: const Text(
                  '管理',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 通知设置
  Widget _buildNotificationSettings() {
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
            '通知设置',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('进入围栏提醒'),
            value: _fenceEnterNotification,
            onChanged: (value) {
              setState(() => _fenceEnterNotification = value);
              _saveNotificationSettings();
            },
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            title: const Text('离开围栏提醒'),
            value: _fenceExitNotification,
            onChanged: (value) {
              setState(() => _fenceExitNotification = value);
              _saveNotificationSettings();
            },
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            title: const Text('低电量提醒'),
            value: _lowBatteryNotification,
            onChanged: (value) {
              setState(() => _lowBatteryNotification = value);
              _saveNotificationSettings();
            },
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            title: const Text('SOS警报'),
            value: _sosNotification,
            onChanged: (value) {
              setState(() => _sosNotification = value);
              _saveNotificationSettings();
            },
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  // 伙伴信息
  Widget _buildPartnerInfo() {
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
            '伙伴信息',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow('伙伴号', _device!.deviceNo),
          const SizedBox(height: 8),
          if (_device!.battery != null)
            _buildInfoRow('当前电量', '${_device!.battery}%')
          else
            _buildInfoRow('当前电量', '--'),
          const SizedBox(height: 8),
          _buildInfoRow('绑定时间', () {
            final bindTimeStr = _device!.bindTime?.toString();
            if (bindTimeStr != null && bindTimeStr.length >= 10) {
              return bindTimeStr.substring(0, 10);
            }
            return bindTimeStr ?? '--';
          }()),
          const SizedBox(height: 16),
          // 设备密码修改
          _buildChangePasswordRow(),
        ],
      ),
    );
  }

  // 修改密码行
  Widget _buildChangePasswordRow() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(
                Icons.lock_outline,
                size: 20,
                color: AppColors.textSecondary,
              ),
              SizedBox(width: 8),
              Text(
                '设备密码',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: _showChangePasswordDialog,
            child: const Text(
              '修改',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 显示修改密码对话框
  void _showChangePasswordDialog() {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('修改设备密码'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: oldPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: '旧密码',
                    hintText: '请输入旧密码',
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入旧密码';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: '新密码',
                    hintText: '请输入新密码（至少6位）',
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.lock),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入新密码';
                    }
                    if (value.length < 6) {
                      return '密码长度不能少于6位';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: '确认新密码',
                    hintText: '请再次输入新密码',
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.lock),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请再次输入新密码';
                    }
                    if (value != newPasswordController.text) {
                      return '两次输入的密码不一致';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) {
                  return;
                }

                final oldPassword = oldPasswordController.text.trim();
                final newPassword = newPasswordController.text.trim();

                setState(() => _isChangingPassword = true);

                try {
                  await ApiService().changeDevicePassword(
                    deviceId,
                    oldPassword,
                    newPassword,
                  );

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('设备密码修改成功')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('修改失败: ${e.toString()}')),
                    );
                  }
                } finally {
                  if (mounted) {
                    setState(() => _isChangingPassword = false);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: _isChangingPassword
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  // 信息行
  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // 解绑按钮
  Widget _buildUnbindButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _isUnbinding ? null : _handleUnbind,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isUnbinding
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                '解除伙伴绑定',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  // 处理解绑
  Future<void> _handleUnbind() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('解除绑定'),
        content: const Text('确定要解除这个伙伴的绑定吗？解绑后将无法再看到它的位置信息。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('确认解绑'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isUnbinding = true);

    try {
      final token = await StorageService.getAuthToken();
      if (token != null) {
        ApiService().setAuthToken(token);
      }

      await ApiService().unbindDevice(deviceId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('解绑成功')),
        );
        Navigator.pop(context, true);
      }
    } on DioException catch (e) {
      String message = '网络错误，请稍后重试';
      if (e.response != null) {
        final data = e.response?.data as Map<String, dynamic>;
        message = data['message'] ?? message;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        setState(() => _isUnbinding = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('解绑失败: $e')),
        );
        setState(() => _isUnbinding = false);
      }
    }
  }

  // 保存通知设置
  Future<void> _saveNotificationSettings() async {
    try {
      final settings = {
        'fenceEnterNotification': _fenceEnterNotification,
        'fenceExitNotification': _fenceExitNotification,
        'lowBatteryNotification': _lowBatteryNotification,
        'sosNotification': _sosNotification,
      };

      await ApiService().updateDeviceSettings(deviceId, settings);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('通知设置已保存')),
        );
      }
    } catch (e) {
      debugPrint('[PartnerSettingsScreen] 保存通知设置失败: $e');
    }
  }
}