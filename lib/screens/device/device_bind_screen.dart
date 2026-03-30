import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/device.dart';

/// 设备绑定页面
/// 用于绑定 JT808 设备到当前用户
class DeviceBindScreen extends StatefulWidget {
  const DeviceBindScreen({super.key});

  @override
  State<DeviceBindScreen> createState() => _DeviceBindScreenState();
}

class _DeviceBindScreenState extends State<DeviceBindScreen> {
  final ApiService _apiService = ApiService();
  List<Device> _unboundDevices = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUnboundDevices();
  }

  /// 加载可绑定的设备列表
  Future<void> _loadUnboundDevices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final devices = await _apiService.getUnboundDevices();
      setState(() {
        _unboundDevices = devices;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  /// 绑定设备
  Future<void> _bindDevice(Device device) async {
    try {
      await _apiService.bindDeviceById(device.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('设备 "${device.name}" 绑定成功'),
            backgroundColor: Colors.green,
          ),
        );
        // 刷新列表
        _loadUnboundDevices();
        // 返回上一页并刷新
        if (mounted) {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('绑定失败: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 显示设备详情对话框
  void _showDeviceDetail(Device device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(device.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('设备ID', device.id),
              _buildDetailRow('设备号', device.deviceNo),
              _buildDetailRow('在线状态', device.isOnline ? '在线' : '离线'),
              if (device.latitude != null && device.longitude != null)
                _buildDetailRow(
                  '最后位置',
                  '${device.latitude!.toStringAsFixed(6)}, ${device.longitude!.toStringAsFixed(6)}',
                ),
              if (device.address != null && device.address!.isNotEmpty)
                _buildDetailRow('地址', device.address),
              if (device.battery != null)
                _buildDetailRow('电量', '${device.battery}%'),
              if (device.lastUpdate != null)
                _buildDetailRow(
                  '最后更新',
                  _formatDateTime(device.lastUpdate!),
                ),
              if (device.bindTime != null)
                _buildDetailRow(
                  '绑定时间',
                  _formatDateTime(device.bindTime!),
                ),
              if (device.ownerId != null)
                _buildDetailRow('绑定用户ID', device.ownerId!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _bindDevice(device);
            },
            child: const Text('绑定设备'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value ?? '-'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('绑定 JT808 设备'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUnboundDevices,
            tooltip: '刷新',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUnboundDevices,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_unboundDevices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.devices_other,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '暂无可绑定的设备',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '请确保 JT808 设备已连接并上报数据',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadUnboundDevices,
              icon: const Icon(Icons.refresh),
              label: const Text('刷新'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUnboundDevices,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _unboundDevices.length,
        itemBuilder: (context, index) {
          final device = _unboundDevices[index];
          return _buildDeviceCard(device);
        },
      ),
    );
  }

  Widget _buildDeviceCard(Device device) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showDeviceDetail(device),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // 在线状态指示器
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: device.isOnline ? Colors.green : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 设备名称
                  Expanded(
                    child: Text(
                      device.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // 设备号标签
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '设备号: ${device.deviceNo}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 设备信息
              if (device.address != null && device.address!.isNotEmpty)
                _buildInfoRow(Icons.location_on, device.address),
              if (device.battery != null)
                _buildInfoRow(Icons.battery_full, '${device.battery}%'),
              // 绑定按钮
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _bindDevice(device),
                  icon: const Icon(Icons.link),
                  label: const Text('绑定设备'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
