import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:starby_mobile/config/app_config.dart';

class AmapService {
  static final Dio _dio = Dio();

  /// 逆地理编码：根据经纬度获取地址
  /// 返回格式：北京市丰台区太平桥街道精图小区56号院
  static Future<String?> getAddress(double longitude, double latitude) async {
    try {
      // 高德地图逆地理编码 API
      const url = 'https://restapi.amap.com/v3/geocode/regeo';

      final params = {
        'key': AppConfig.AMAP_WEB_KEY,
        'location': '$longitude,$latitude',
        'poitype': '',
        'radius': '1000',
        'extensions': 'base',
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
        final address = response.data['regeocode']?['formatted_address'];
        if (address != null) {
          debugPrint('[AmapService] 逆地理编码成功: $longitude,$latitude -> $address');
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
