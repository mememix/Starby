import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:starby_mobile/config/app_config.dart';

class AmapService {
  static final Dio _dio = Dio();

  /// 逆地理编码：根据经纬度获取地址
  /// 优先返回POI信息，如果没有POI则返回完整地址
  /// 返回格式：茗筑大厦 (北京西站南路80号) 或 北京市丰台区太平桥街道精图小区56号院
  static Future<String?> getAddress(double longitude, double latitude) async {
    try {
      // 高德地图逆地理编码 API
      const url = 'https://restapi.amap.com/v3/geocode/regeo';

      final params = {
        'key': AppConfig.AMAP_WEB_KEY,
        'location': '$longitude,$latitude',
        'poitype': '',
        'radius': '1000',
        'extensions': 'all', // 获取更详细的地址信息，包括POI和AOI
        'batch': 'false',
        'roadlevel': '0',
      };

      final response = await _dio.get(
        url,
        queryParameters: params,
        options: Options(
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['status'] == '1') {
        final regeocode = response.data['regeocode'];

        // 优先尝试从POI中获取地址（POI是兴趣点，更精确）
        if (regeocode != null && regeocode['pois'] != null && regeocode['pois'].length > 0) {
          final pois = regeocode['pois'] as List;
          // 取第一个POI（通常是最匹配的）
          final firstPoi = pois[0] as Map<String, dynamic>;
          final poiName = firstPoi['name'] as String?;
          final poiAddress = firstPoi['address'] as String?;

          // 如果POI有名称和地址，组合返回
          if (poiName != null && poiName.isNotEmpty) {
            final poiText = poiAddress != null && poiAddress.isNotEmpty
                ? '$poiName ($poiAddress)'
                : poiName;
            debugPrint('[AmapService] 逆地理编码成功(POI): $longitude,$latitude -> $poiText');
            return poiText;
          }
        }

        // 如果没有POI，尝试从AOI中获取地址（AOI是区域信息）
        if (regeocode != null && regeocode['aois'] != null && regeocode['aois'].length > 0) {
          final aois = regeocode['aois'] as List;
          final firstAoi = aois[0] as Map<String, dynamic>;
          final aoiName = firstAoi['name'] as String?;
          final aoiAddress = firstAoi['address'] as String?;

          if (aoiName != null && aoiName.isNotEmpty) {
            final aoiText = aoiAddress != null && aoiAddress.isNotEmpty
                ? '$aoiName ($aoiAddress)'
                : aoiName;
            debugPrint('[AmapService] 逆地理编码成功(AOI): $longitude,$latitude -> $aoiText');
            return aoiText;
          }
        }

        // 如果没有POI和AOI，返回完整地址
        final address = regeocode?['formatted_address'];
        if (address != null) {
          debugPrint('[AmapService] 逆地理编码成功(完整地址): $longitude,$latitude -> $address');
          return address;
        }
      }

      debugPrint('[AmapService] 逆地理编码失败: ${response.data}');
      return null;
    } catch (e) {
      debugPrint('[AmapService] 逆地理编码异常: $e');
      return null;
    }
  }
}
