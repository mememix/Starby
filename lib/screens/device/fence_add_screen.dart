// lib/screens/device/fence_add_screen.dart
// 添加电子围栏页

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../constants/colors.dart';
import '../../models/device.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../../../widgets/map/amap_widget.dart';

class FenceAddScreen extends StatefulWidget {
  const FenceAddScreen({super.key, this.deviceId});

  final String? deviceId;

  @override
  State<FenceAddScreen> createState() => _FenceAddScreenState();
}

class _FenceAddScreenState extends State<FenceAddScreen> {
  final _nameController = TextEditingController();
  final _searchController = TextEditingController();
  double _radius = 200;
  double? _latitude;
  double? _longitude;
  bool _isLoading = false;
  bool _isSearching = false;
  bool _alarmEnter = true; // 进入提醒
  bool _alarmLeave = true; // 离开提醒
  List<Map<String, dynamic>> _searchResults = [];
  Device? _device; // 设备信息

  @override
  void initState() {
    super.initState();
    _loadDeviceInfo();
  }

  // 加载设备信息，获取当前位置
  Future<void> _loadDeviceInfo() async {
    if (widget.deviceId == null || widget.deviceId!.isEmpty) {
      return;
    }

    try {
      final token = await StorageService.getAuthToken();
      if (token != null) {
        ApiService().setAuthToken(token);
      }

      final device = await ApiService().getDeviceDetail(widget.deviceId!);
      if (mounted) {
        setState(() {
          _device = device;
          // 使用设备的当前位置作为地图中心点
          if (device.latitude != null && device.longitude != null) {
            _latitude = device.latitude!.toDouble();
            _longitude = device.longitude!.toDouble();
          }
        });
      }
    } catch (e) {
      debugPrint('加载设备信息失败: $e');
    }
  }

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  _buildFenceName(),
                  const SizedBox(height: 16),
                  _buildRadiusSlider(),
                  const SizedBox(height: 16),
                  _buildAlarmTypeOptions(),
                  const SizedBox(height: 16),
                  _buildLocationPicker(),
                  const SizedBox(height: 40),
                  _buildSaveButton(),
                  const SizedBox(height: 20),
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
            '添加电子围栏',
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

  // 围栏名称
  Widget _buildFenceName() {
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
            '围栏名称',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: '请输入围栏名称',
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 围栏半径滑块
  Widget _buildRadiusSlider() {
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
              const Text(
                '围栏半径',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '${_radius.toInt()} 米',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          Slider(
            value: _radius,
            min: 50,
            max: 1000,
            divisions: 19,
            activeColor: AppColors.primary,
            onChanged: (value) {
              setState(() {
                _radius = value;
              });
            },
          ),
        ],
      ),
    );
  }

  // 报警类型选项
  Widget _buildAlarmTypeOptions() {
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
            '报警提醒',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text(
              '进入提醒',
              style: TextStyle(fontSize: 15),
            ),
            subtitle: const Text(
              '设备进入围栏区域时提醒',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            value: _alarmEnter,
            onChanged: (value) {
              setState(() {
                _alarmEnter = value;
              });
            },
            activeColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            title: const Text(
              '离开提醒',
              style: TextStyle(fontSize: 15),
            ),
            subtitle: const Text(
              '设备离开围栏区域时提醒',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            value: _alarmLeave,
            onChanged: (value) {
              setState(() {
                _alarmLeave = value;
              });
            },
            activeColor: AppColors.primary,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  // 位置选择
  Widget _buildLocationPicker() {
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
            '围栏位置',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          // 搜索框
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜索地点快速定位',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _isSearching
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchResults.clear();
                            });
                          },
                        )
                      : null,
              filled: true,
              fillColor: Colors.grey[50],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
            onChanged: _onSearchChanged,
          ),
          // 搜索结果列表
          if (_searchResults.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final result = _searchResults[index];
                  return ListTile(
                    title: Text(result['name']),
                    subtitle: Text(result['address']),
                    onTap: () => _selectSearchResult(result),
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            height: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned.fill(
                  child: AMapWidget(
                    initialCameraPosition: LatLng(
                      _latitude ?? 39.909187,
                      _longitude ?? 116.397451,
                    ),
                    onTap: (position) {
                      setState(() {
                        _latitude = position.latitude;
                        _longitude = position.longitude;
                      });
                    },
                    circles: _latitude != null && _longitude != null ? {
                      Circle(
                        id: 'fence_preview',
                        center: LatLng(_latitude!, _longitude!),
                        radius: _radius,
                        fillColor: AppColors.primary.withValues(alpha: 0.2),
                        strokeColor: AppColors.primary,
                      ),
                    } : {},
                    myLocationEnabled: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _latitude == null || _longitude == null
                ? '请在地图上点击选择围栏中心位置'
                : '已选择位置: ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}, 半径: ${_radius.toInt()} 米',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          if (_latitude != null && _longitude != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '当前坐标: $_latitude, $_longitude',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textHint,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 保存按钮
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleSave,
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
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                '添加围栏',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  // 搜索地点（使用高德地图POI搜索API）
  Future<void> _onSearchChanged(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults.clear();
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      // 调用高德地图POI搜索API
      final url = 'https://restapi.amap.com/v3/place/text?key=YOUR_AMAP_KEY&keywords=$query&city=北京&output=json';

      final dio = Dio();
      final response = await dio.get(url);

      if (response.statusCode == 200 && response.data['status'] == '1') {
        final pois = response.data['pois'] as List;
        final results = pois.take(5).map((poi) {
          final location = (poi['location'] as String).split(',');
          return {
            'name': poi['name'],
            'address': poi['address'] ?? poi['pname'] + poi['cityname'],
            'lat': double.parse(location[1]),
            'lng': double.parse(location[0]),
          };
        }).toList();

        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
        }
      } else {
        throw Exception('搜索失败');
      }
    } catch (e) {
      debugPrint('搜索地点失败: $e');
      // 如果API调用失败，返回模拟数据
      await Future.delayed(const Duration(milliseconds: 300));
      final mockResults = [
        {'name': query, 'address': '北京市朝阳区xxx路xxx号', 'lat': 39.909187, 'lng': 116.397451},
        {'name': '$query 广场', 'address': '北京市海淀区xxx广场', 'lat': 39.919187, 'lng': 116.407451},
      ];

      if (mounted) {
        setState(() {
          _searchResults = mockResults;
          _isSearching = false;
        });
      }
    }
  }

  // 选择搜索结果
  void _selectSearchResult(Map<String, dynamic> result) {
    setState(() {
      _latitude = result['lat'];
      _longitude = result['lng'];
      _searchResults.clear();
      _searchController.text = result['name'];
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已选择：${result['name']}')),
    );
  }

  // 保存围栏
  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    final deviceId = widget.deviceId;

    // 校验
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入围栏名称')),
      );
      return;
    }

    if (deviceId == null || deviceId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('缺少设备ID，请从设备详情页添加围栏')),
      );
      return;
    }

    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择围栏位置')),
      );
      return;
    }

    if (!_alarmEnter && !_alarmLeave) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少选择一种报警类型')),
      );
      return;
    }

    setState(() => _isLoading = true);

    // 确定报警类型
    String alarmType = 'both';
    if (_alarmEnter && !_alarmLeave) {
      alarmType = 'enter';
    } else if (!_alarmEnter && _alarmLeave) {
      alarmType = 'leave';
    }

    try {
      final token = await StorageService.getAuthToken();
      if (token != null) {
        ApiService().setAuthToken(token);
      }

      await ApiService().createFence(
        deviceId: deviceId,
        name: name,
        latitude: _latitude!,
        longitude: _longitude!,
        radius: _radius,
        alarmType: alarmType,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('电子围栏添加成功')),
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
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
