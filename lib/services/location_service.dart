// lib/services/location_service.dart
// 位置服务 - 实时定位更新（模拟版）
// 暂时使用模拟数据，等待高德地图SDK更新后替换

import 'dart:async';
import 'dart:math';
import '../models/location.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Timer? _locationTimer;
  
  final StreamController<Location> _locationController = StreamController.broadcast();
  Stream<Location> get locationStream => _locationController.stream;

  bool _isStarted = false;
  Location? _currentLocation;

  // 模拟位置数据（北京天安门附近）
  double _baseLat = 39.909187;
  double _baseLng = 116.397451;

  // 初始化
  Future<void> init() async {
    // 模拟初始化成功
    debugPrint('LocationService: 初始化完成（模拟模式）');
  }

  // 开始定位
  void startLocation() {
    if (_isStarted) return;

    _isStarted = true;

    // 模拟定位更新（每2秒更新一次）
    _locationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _simulateLocationUpdate();
    });

    // 立即发送一次位置
    _simulateLocationUpdate();
  }

  // 停止定位
  void stopLocation() {
    if (!_isStarted) return;

    _isStarted = false;
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  // 模拟位置更新
  void _simulateLocationUpdate() {
    // 模拟小范围移动
    final random = Random();
    _baseLat += (random.nextDouble() - 0.5) * 0.0001;
    _baseLng += (random.nextDouble() - 0.5) * 0.0001;

    _currentLocation = Location(
      id: 'sim_${DateTime.now().millisecondsSinceEpoch}',
      deviceId: 'sim_device',
      lat: _baseLat,
      lng: _baseLng,
      address: '北京市东城区长安街1号（模拟位置）',
      accuracy: 10 + random.nextDouble() * 5,
      timestamp: DateTime.now(),
    );

    _locationController.add(_currentLocation!);
  }

  // 获取当前位置
  Location? get currentLocation => _currentLocation;

  // 销毁
  void dispose() {
    stopLocation();
    _locationController.close();
  }
}
