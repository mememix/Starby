import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart' as ll;
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';

/// 高德地图组件 - 使用 flutter_map + 高德地图瓦片
///
/// 功能：
/// - 地图显示和交互
/// - 设备标记点
/// - 轨迹线绘制
/// - 电子围栏圆圈
/// - 定位和导航
class AMapWidget extends StatefulWidget {
  final LatLng? initialCameraPosition;
  final Function(fm.MapController)? onMapCreated;
  final Function(LatLng)? onTap;
  final Set<Marker>? markers;
  final Set<Circle>? circles;
  final Set<Polyline>? polylines;
  final bool myLocationEnabled;
  final bool showNavigationButton;
  final LatLng? deviceLocation; // 设备当前位置(用于定位按钮)

  const AMapWidget({
    super.key,
    this.initialCameraPosition,
    this.onMapCreated,
    this.onTap,
    this.markers,
    this.circles,
    this.polylines,
    this.myLocationEnabled = true,
    this.showNavigationButton = false,
    this.deviceLocation,
  });

  @override
  State<AMapWidget> createState() => _AMapWidgetState();
}

class _AMapWidgetState extends State<AMapWidget> {
  final fm.MapController _mapController = fm.MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onMapCreated?.call(_mapController);
      _moveToInitialPosition();
    });
  }

  @override
  void didUpdateWidget(AMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 如果初始位置发生变化,移动地图到新位置
    if (oldWidget.initialCameraPosition != widget.initialCameraPosition &&
        widget.initialCameraPosition != null) {
      debugPrint('[AMapWidget] 初始位置变化,移动地图到: ${widget.initialCameraPosition!.latitude}, ${widget.initialCameraPosition!.longitude}');
      _moveToPosition(widget.initialCameraPosition!);
    }
  }

  void _moveToInitialPosition() {
    if (widget.initialCameraPosition != null) {
      debugPrint('[AMapWidget] 移动地图到初始位置: ${widget.initialCameraPosition!.latitude}, ${widget.initialCameraPosition!.longitude}');
      _moveToPosition(widget.initialCameraPosition!);
    }
  }

  void _moveToPosition(LatLng position) {
    try {
      _mapController.move(
        ll.LatLng(position.latitude, position.longitude),
        15.0,
      );
    } catch (e) {
      debugPrint('[AMapWidget] 移动地图失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[AMapWidget] Building map with initialCameraPosition: ${widget.initialCameraPosition}');

    return Stack(
      children: [
        fm.FlutterMap(
          mapController: _mapController,
          options: fm.MapOptions(
            initialCenter: widget.initialCameraPosition != null
                ? ll.LatLng(widget.initialCameraPosition!.latitude, widget.initialCameraPosition!.longitude)
                : const ll.LatLng(39.9042, 116.4074),
            initialZoom: 15.0,
            minZoom: 3.0,
            maxZoom: 18.0,
            onTap: widget.onTap != null
                ? (tapPosition, point) {
                    widget.onTap!(LatLng(point.latitude, point.longitude));
                  }
                : null,
          ),
          children: [
            // 使用高德地图瓦片（中国大陆访问快，无需转换坐标）
            fm.TileLayer(
              urlTemplate: 'http://webrd01.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}',
              subdomains: const ['01', '02', '03', '04'],
              userAgentPackageName: 'com.xinghu.xinghu_app',
              errorTileCallback: (tile, error, stackTrace) {
                debugPrint('高德地图 Tile loading error: $error');
              },
            ),
            // 轨迹线
            if (widget.polylines != null)
              fm.PolylineLayer(
                polylines: widget.polylines!.map((p) => _convertPolyline(p)).toList(),
              ),
            // 标记点
            if (widget.markers != null)
              fm.MarkerLayer(
                markers: widget.markers!.map((m) => _convertMarker(m)).toList(),
              ),
            // 电子围栏圆圈
            if (widget.circles != null)
              fm.CircleLayer(
                circles: widget.circles!.map((c) => _convertCircle(c)).toList(),
              ),
          ],
        ),
        // 定位按钮
        if (widget.myLocationEnabled)
          Positioned(
            right: 16,
            bottom: widget.showNavigationButton ? 100 : 16,
            child: FloatingActionButton.small(
              onPressed: () {
                // 优先使用设备位置，如果没有则使用第一个标记点
                LatLng? targetLocation;
                if (widget.deviceLocation != null) {
                  targetLocation = widget.deviceLocation;
                } else if (widget.markers != null && widget.markers!.isNotEmpty) {
                  targetLocation = widget.markers!.first.position;
                } else if (widget.initialCameraPosition != null) {
                  targetLocation = widget.initialCameraPosition;
                }

                if (targetLocation != null) {
                  _mapController.move(
                    ll.LatLng(targetLocation.latitude, targetLocation.longitude),
                    16.0,
                  );
                }
              },
              backgroundColor: Colors.white,
              child: const Icon(Icons.my_location, color: Color(0xFF4ECDC4)),
            ),
          ),
        // 导航按钮
        if (widget.showNavigationButton && widget.markers != null && widget.markers!.isNotEmpty)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              onPressed: () => _openNavigation(widget.markers!.first.position),
              backgroundColor: const Color(0xFF4ECDC4),
              child: const Icon(Icons.navigation, color: Colors.white),
            ),
          ),
      ],
    );
  }

  // 转换 Marker
  fm.Marker _convertMarker(Marker marker) {
    return fm.Marker(
      width: 80.0,
      height: 100.0,
      point: ll.LatLng(marker.position.latitude, marker.position.longitude),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 设备图标（不显示信息卡片）
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: marker.isOnline ? const Color(0xFFE797A2) : Colors.grey,
              shape: BoxShape.circle,
              border: Border.all(
                color: marker.isOnline ? const Color(0xFFE797A2) : Colors.grey,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (marker.isOnline ? const Color(0xFFE797A2) : Colors.grey).withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: marker.avatar != null && marker.avatar!.isNotEmpty
                  ? (_getAvatarProvider(marker.avatar!) != null
                      ? Image(
                          image: _getAvatarProvider(marker.avatar!)!,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.person,
                              size: 40,
                              color: Colors.white,
                            );
                          },
                        )
                      : const Icon(
                          Icons.person,
                          size: 40,
                          color: Colors.white,
                        ))
                  : const Icon(
                      Icons.person,
                      size: 40,
                      color: Colors.white,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // 将base64头像数据转换为ImageProvider
  ImageProvider? _getAvatarProvider(String? avatarUrl) {
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
        debugPrint('[AMapWidget] 解析base64头像失败: $e');
        return null;
      }
    } else if (avatarUrl.startsWith('/uploads/')) {
      // 相对路径，需要拼接服务器地址
      final baseUrl = ApiService.baseUrl;
      final serverUrl = baseUrl.replaceAll(RegExp(r'/api$'), '');
      // 去除重复的uploads/remote/前缀
      String cleanPath = avatarUrl;
      if (avatarUrl.contains('/uploads/remote/uploads/remote/')) {
        cleanPath = avatarUrl.replaceAll('/uploads/remote/uploads/remote/', '/uploads/remote/');
      }
      final finalUrl = '$serverUrl$cleanPath';
      debugPrint('[AMapWidget] 拼接头像URL: $finalUrl');
      return NetworkImage(finalUrl);
    } else {
      // 如果是普通的网络URL，使用NetworkImage
      return NetworkImage(avatarUrl);
    }
  }

  // 获取电池颜色
  Color _getBatteryColor(int battery) {
    if (battery > 50) return Colors.green;
    if (battery > 20) return Colors.orange;
    return Colors.red;
  }

  // 格式化时间
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return '${time.month}/${time.day}';
    }
  }

  // 转换 Polyline
  fm.Polyline _convertPolyline(Polyline polyline) {
    final points = polyline.points.map((p) {
      return ll.LatLng(p.latitude, p.longitude);
    }).toList();

    return fm.Polyline(
      points: points,
      color: polyline.color ?? const Color(0xFFE797A2),
      strokeWidth: polyline.width ?? 4,
    );
  }

  // 转换 Circle
  fm.CircleMarker _convertCircle(Circle circle) {
    return fm.CircleMarker(
      point: ll.LatLng(circle.center.latitude, circle.center.longitude),
      radius: circle.radius,
      color: (circle.fillColor ?? const Color(0xFFE797A2)).withValues(alpha: 0.2),
      borderColor: circle.strokeColor ?? const Color(0xFFE797A2),
      borderStrokeWidth: 2,
    );
  }

  // 打开导航
  Future<void> _openNavigation(LatLng destination) async {
    // 使用高德地图导航
    final url = 'androidamap://route/plan/?dlat=${destination.latitude}&dlon=${destination.longitude}&dev=0&t=0';

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // 如果高德地图不可用,尝试使用 Web 导航
      final webUrl = 'https://www.google.com/maps/dir/?api=1&destination=${destination.latitude},${destination.longitude}';
      final webUri = Uri.parse(webUrl);
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法打开导航应用')),
          );
        }
      }
    }
  }
}

/// 坐标类
class LatLng {
  final double latitude;
  final double longitude;

  const LatLng(this.latitude, this.longitude);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LatLng &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;
}

/// 标记类
class Marker {
  final String id;
  final LatLng position;
  final InfoWindow? infoWindow;
  final bool isOnline;
  final String? avatar;          // 设备头像
  final int? battery;            // 电量 0-100
  final DateTime? lastUpdate;    // 最后更新时间

  Marker({
    required this.id,
    required this.position,
    this.infoWindow,
    this.isOnline = true,
    this.avatar,
    this.battery,
    this.lastUpdate,
  });
}

/// 信息窗口
class InfoWindow {
  final String? title;
  final String? snippet;

  InfoWindow({this.title, this.snippet});
}

/// 圆圈类(电子围栏)
class Circle {
  final String id;
  final LatLng center;
  final double radius;
  final Color? fillColor;
  final Color? strokeColor;

  Circle({
    required this.id,
    required this.center,
    required this.radius,
    this.fillColor,
    this.strokeColor,
  });
}

/// 轨迹线类
class Polyline {
  final String id;
  final List<LatLng> points;
  final Color? color;
  final double? width;

  Polyline({
    required this.id,
    required this.points,
    this.color,
    this.width,
  });
}
