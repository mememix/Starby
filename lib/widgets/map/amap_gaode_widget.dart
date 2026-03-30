/// 高德地图组件 - 使用 amap_flutter_map SDK
///
/// 功能：
/// - 地图显示和交互
/// - 设备标记点
/// - 轨迹线绘制
/// - 电子围栏圆圈
/// - 定位和导航
library;

import 'package:flutter/material.dart';
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'package:amap_location/amap_location.dart';

/// 高德地图组件
class AMapWidget extends StatefulWidget {
  final LatLng? initialCameraPosition;
  final Function(AMapController)? onMapCreated;
  final Function(LatLng)? onTap;
  final Set<Marker>? markers;
  final Set<Circle>? circles;
  final Set<Polyline>? polylines;
  final bool myLocationEnabled;
  final bool showNavigationButton;

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
  });

  @override
  State<AMapWidget> createState() => _AMapWidgetState();
}

class _AMapWidgetState extends State<AMapWidget> {
  AMapController? _mapController;
  final bool _myLocationEnabled = false;

  @override
  Widget build(BuildContext context) {
    debugPrint('[AMapWidget] Building map with initialCameraPosition: ${widget.initialCameraPosition}');

    return Stack(
      children: [
        AMapWidget(
          initialCameraPosition: CameraPosition(
            target: widget.initialCameraPosition != null
                ? LatLng(widget.initialCameraPosition!.latitude, widget.initialCameraPosition!.longitude)
                : const LatLng(39.9042, 116.4074),
            zoom: 15,
          ),
          onMapCreated: (controller) {
            _mapController = controller;
            widget.onMapCreated?.call(controller);
          },
          onTap: (position) {
            widget.onTap?.call(LatLng(position.latitude, position.longitude));
          },
          myLocationEnabled: widget.myLocationEnabled,
          myLocationButtonEnabled: false, // 使用自定义定位按钮
          mapType: MapType.normal,
          zoomGesturesEnabled: true,
          scrollGesturesEnabled: true,
          tiltGesturesEnabled: true,
          rotateGesturesEnabled: true,
          markers: widget.markers?.map(_convertMarker).toSet() ?? {},
          circles: widget.circles?.map(_convertCircle).toSet() ?? {},
          polylines: widget.polylines?.map(_convertPolyline).toSet() ?? {},
        ),
        // 定位按钮
        if (widget.myLocationEnabled)
          Positioned(
            right: 16,
            bottom: widget.showNavigationButton ? 100 : 16,
            child: FloatingActionButton.small(
              onPressed: () {
                if (widget.markers != null && widget.markers!.isNotEmpty) {
                  final marker = widget.markers!.first;
                  _mapController?.animateCamera(
                    CameraUpdate.newLatLngZoom(
                      LatLng(marker.position.latitude, marker.position.longitude),
                      16,
                    ),
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
  Marker _convertMarker(Marker marker) {
    return Marker(
      markerId: MarkerId(marker.id),
      position: LatLng(marker.position.latitude, marker.position.longitude),
      infoWindow: marker.infoWindow != null
          ? InfoWindow(
              title: marker.infoWindow!.title,
              snippet: marker.infoWindow!.snippet,
            )
          : InfoWindow.noText,
      icon: marker.avatar != null && marker.avatar!.isNotEmpty
          ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)
          : null,
      onTap: () {
        // 可以在这里添加标记点击事件
      },
    );
  }

  // 转换 Circle
  Circle _convertCircle(Circle circle) {
    return Circle(
      circleId: CircleId(circle.id),
      center: LatLng(circle.center.latitude, circle.center.longitude),
      radius: circle.radius,
      fillColor: (circle.fillColor ?? const Color(0xFFE797A2)).withOpacity(0.2),
      strokeColor: circle.strokeColor ?? const Color(0xFFE797A2),
      strokeWidth: 2,
    );
  }

  // 转换 Polyline
  Polyline _convertPolyline(Polyline polyline) {
    return Polyline(
      polylineId: PolylineId(polyline.id),
      points: polyline.points
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList(),
      color: polyline.color ?? const Color(0xFFE797A2),
      width: polyline.width ?? 4,
    );
  }

  // 打开导航
  Future<void> _openNavigation(LatLng destination) async {
    // 使用高德地图导航
    final url =
        'androidamap://route/plan/?dlat=${destination.latitude}&dlon=${destination.longitude}&dev=0&t=0';

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // 如果高德地图不可用,尝试使用 Web 导航
      final webUrl =
          'https://www.google.com/maps/dir/?api=1&destination=${destination.latitude},${destination.longitude}';
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

  static const noText = InfoWindow();
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
