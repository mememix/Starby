/**
 * 坐标转换工具
 * 统一处理 WGS-84 转 GCJ-02 和统一偏移修正
 */

/**
 * 基于狗子（设备2000）的正确纠偏值
 *
 * 狗子原始坐标: 39.874616, 116.31596
 * GCJ-02转换后: 39.875903, 116.320643
 * 狗子正确坐标: 39.876168, 116.321568 (北京市西城区北京西站南路80号1号楼)
 * 计算偏移: (39.876168 - 39.875903 = 0.000265, 116.321568 - 116.320643 = 0.000925)
 */
const UNIFIED_OFFSET = {
  latitude: 0.000265,   // 纬度偏移（基于狗子验证）
  longitude: 0.000925    // 经度偏移（基于狗子验证）
};

/**
 * WGS-84 转 GCJ-02 (火星坐标系)
 * 使用标准算法
 */
function transformWGS84ToGCJ02(lat: number, lng: number): { lat: number; lng: number } | null {
  const a = 6378245.0; // 长半轴
  const ee = 0.00669342162296594323; // 扁率

  // 输入验证
  if (typeof lat !== 'number' || typeof lng !== 'number' || isNaN(lat) || isNaN(lng)) {
    console.error('[transformWGS84ToGCJ02] 无效的输入:', lat, lng);
    return null;
  }

  // 检查是否在中国境外
  if (lng < 72.004 || lng > 137.8347 || lat < 0.8293 || lat > 55.8271) {
    console.warn('[transformWGS84ToGCJ02] 坐标在中国境外:', lat, lng);
    return { lat, lng };
  }

  let dLat = transformLat(lng - 105.0, lat - 35.0);
  let dLng = transformLng(lng - 105.0, lat - 35.0);

  const radLat = lat / 180.0 * Math.PI;
  let magic = Math.sin(radLat);
  magic = 1 - ee * magic * magic;
  const sqrtMagic = Math.sqrt(magic);

  if (sqrtMagic === 0 || magic === 0) {
    console.error('[transformWGS84ToGCJ02] 计算错误: magic=', magic, 'sqrtMagic=', sqrtMagic);
    return { lat, lng };
  }

  dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * Math.PI);
  dLng = (dLng * 180.0) / (a / sqrtMagic * Math.PI);

  const resultLat = lat + dLat;
  const resultLng = lng + dLng;

  // 验证结果
  if (isNaN(resultLat) || isNaN(resultLng) || !isFinite(resultLat) || !isFinite(resultLng)) {
    console.error('[transformWGS84ToGCJ02] 转换结果无效:', resultLat, resultLng);
    return { lat, lng };
  }

  return {
    lat: resultLat,
    lng: resultLng
  };
}

/**
 * 判断是否在中国境内
 */
function outOfChina(lat: number, lng: number): boolean {
  if (lng < 72.004 || lng > 137.8347) return true;
  if (lat < 0.8293 || lat > 55.8271) return true;
  return false;
}

/**
 * 纬度转换
 */
function transformLat(lng: number, lat: number): number {
  let ret = -100.0 + 2.0 * lng + 3.0 * lat + 0.2 * lat * lat + 0.1 * lng * lat + 0.2 * Math.sqrt(Math.abs(lng));
  ret += (20.0 * Math.sin(6.0 * lng * Math.PI) + 20.0 * Math.sin(2.0 * lng * Math.PI)) * 2.0 / 3.0;
  ret += (20.0 * Math.sin(lat * Math.PI) + 40.0 * Math.sin(lat / 3.0 * Math.PI)) * 2.0 / 3.0;
  ret += (160.0 * Math.sin(lat / 12.0 * Math.PI) + 320 * Math.sin(lat * Math.PI / 30.0)) * 2.0 / 3.0;
  return ret;
}

/**
 * 经度转换
 */
function transformLng(lng: number, lat: number): number {
  let ret = 300.0 + lng + 2.0 * lat + 0.1 * lng * lng + 0.1 * lng * lat + 0.1 * Math.sqrt(Math.abs(lng));
  ret += (20.0 * Math.sin(6.0 * lng * Math.PI) + 20.0 * Math.sin(2.0 * lng * Math.PI)) * 2.0 / 3.0;
  ret += (20.0 * Math.sin(lng * Math.PI) + 40.0 * Math.sin(lng / 3.0 * Math.PI)) * 2.0 / 3.0;
  ret += (150.0 * Math.sin(lng / 12.0 * Math.PI) + 300.0 * Math.sin(lng / 30.0 * Math.PI)) * 2.0 / 3.0;
  return ret;
}

/**
 * 应用统一偏移（基于狗子的纠偏算法）
 */
function applyUnifiedOffset(lat: number, lng: number): { lat: number; lng: number } {
  return {
    lat: lat + UNIFIED_OFFSET.latitude,
    lng: lng + UNIFIED_OFFSET.longitude
  };
}

/**
 * 统一坐标转换流程：
 * 1. WGS-84 转 GCJ-02
 * 2. 应用狗子纠偏算法的统一偏移
 *
 * @param latitude 原始纬度
 * @param longitude 原始经度
 * @returns 转换并纠偏后的坐标
 */
export function transformCoordinate(
  latitude: number | string | null | undefined,
  longitude: number | string | null | undefined
): { latitude: number; longitude: number } | null {
  // 转换为数字类型
  let lat: number;
  let lng: number;

  if (typeof latitude === 'string') {
    lat = parseFloat(latitude);
  } else if (typeof latitude === 'number') {
    lat = latitude;
  } else if (latitude && typeof latitude === 'object' && 'toNumber' in latitude) {
    // Prisma Decimal 类型
    lat = (latitude as any).toNumber();
  } else {
    console.warn('[CoordinateTransform] 无效的 latitude 类型:', typeof latitude);
    return null;
  }

  if (typeof longitude === 'string') {
    lng = parseFloat(longitude);
  } else if (typeof longitude === 'number') {
    lng = longitude;
  } else if (longitude && typeof longitude === 'object' && 'toNumber' in longitude) {
    // Prisma Decimal 类型
    lng = (longitude as any).toNumber();
  } else {
    console.warn('[CoordinateTransform] 无效的 longitude 类型:', typeof longitude);
    return null;
  }

  // 检查坐标是否有效
  if (isNaN(lat) || isNaN(lng) || !isFinite(lat) || !isFinite(lng)) {
    console.warn(`[CoordinateTransform] 坐标值无效: lat=${lat}, lng=${lng}`);
    return null;
  }

  // 第一步：WGS-84 转 GCJ-02
  const gcj02 = transformWGS84ToGCJ02(lat, lng);

  // 检查转换结果是否有效
  if (!gcj02 || typeof gcj02.lat !== 'number' || typeof gcj02.lng !== 'number') {
    console.warn(`[CoordinateTransform] 坐标转换失败: (${lat}, ${lng})`);
    return {
      latitude: lat,
      longitude: lng
    };
  }

  // 第二步：应用统一偏移（狗子纠偏算法）
  const corrected = applyUnifiedOffset(gcj02.lat, gcj02.lng);

  console.log(`[CoordinateTransform] 原始坐标: (${lat.toFixed(6)}, ${lng.toFixed(6)}) -> GCJ-02: (${gcj02.lat.toFixed(6)}, ${gcj02.lng.toFixed(6)}) -> 纠偏后: (${corrected.lat.toFixed(6)}, ${corrected.lng.toFixed(6)})`);

  return {
    latitude: corrected.lat,
    longitude: corrected.lng
  };
}

/**
 * 为设备列表批量应用坐标转换
 *
 * @param devices 设备列表
 * @returns 转换后的设备列表
 */
export function transformCoordinates(devices: any[]): any[] {
  return devices.map(device => {
    const transformed = transformCoordinate(
      device.latitude,
      device.longitude
    );

    if (transformed) {
      return {
        ...device,
        latitude: transformed.latitude,
        longitude: transformed.longitude,
      };
    }

    return device;
  });
}

/**
 * 获取统一偏移量（用于调试）
 */
export function getUnifiedOffset() {
  return { ...UNIFIED_OFFSET };
}
