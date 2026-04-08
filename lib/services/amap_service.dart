import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:starby_mobile/config/app_config.dart';

class AmapService {
  static final Dio _dio = Dio();

  /// 逆地理编码：根据经纬度获取地址
  /// 优先返回完整地址（formatted_address），显示最详细的地址信息
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

        // 优先返回完整地址（formatted_address）- 这是最详细的地址
        final address = regeocode?['formatted_address'];
        if (address != null && address.isNotEmpty) {
          debugPrint('[AmapService] 逆地理编码成功(完整地址): $longitude,$latitude -> $address');
          return address;
        }

        // 如果没有formatted_address，再尝试从POI中获取地址（POI是兴趣点）
        if (regeocode != null && regeocode['pois'] != null && regeocode['pois'].length > 0) {
          final pois = regeocode['pois'] as List;
          final firstPoi = pois[0] as Map<String, dynamic>;
          final poiName = firstPoi['name'] as String?;
          final poiAddress = firstPoi['address'] as String?;

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
      }

      debugPrint('[AmapService] 逆地理编码失败: ${response.data}');
      return null;
    } catch (e) {
      debugPrint('[AmapService] 逆地理编码异常: $e');
      return null;
    }
  }
}
