/**
 * 坐标纠偏工具
 * 用于在API层面为所有设备进行坐标纠偏
 */

/**
 * 设备坐标纠偏映射表
 * key: deviceId (string), value: { latitude: number; longitude: number }
 *
 * 配置来源：device_corrections.config
 * 最后更新时间：2026/3/29 15:35:51
 */
const DEVICE_CORRECTIONS: Record<string, { latitude: number; longitude: number }> = {
  '2000': {
    latitude: 39.876168, // 北京市西城区广安门外街道茗筑大厦（北京西站南路80号） (已验证)
    longitude: 116.321568,
  },
};

/**
 * 应用设备坐标纠偏
 *
 * @param deviceId 设备ID
 * @param latitude 原始纬度
 * @param longitude 原始经度
 * @returns 纠偏后的坐标 {latitude, longitude}，如果没有配置则返回原始坐标
 */
export function applyDeviceCorrection(
  deviceId: string,
  latitude: number | string | null | undefined,
  longitude: number | string | null | undefined
): { latitude: number; longitude: number } | null {
  // 转换为数字类型
  const lat = typeof latitude === 'string' ? parseFloat(latitude) : latitude;
  const lng = typeof longitude === 'string' ? parseFloat(longitude) : longitude;

  // 检查坐标是否有效
  if (lat == null || lng == null || isNaN(lat) || isNaN(lng)) {
    return null;
  }

  // 查找设备是否有纠偏配置
  const correction = DEVICE_CORRECTIONS[deviceId];

  if (correction) {
    console.log(`[CoordinateCorrection] 应用设备 ${deviceId} 的坐标校正: (${lat}, ${lng}) -> (${correction.latitude}, ${correction.longitude})`);
    return {
      latitude: correction.latitude,
      longitude: correction.longitude,
    };
  }

  // 没有配置纠偏，返回原始坐标
  return {
    latitude: lat,
    longitude: lng,
  };
}

/**
 * 为设备列表批量应用坐标纠偏
 *
 * @param devices 设备列表
 * @returns 纠偏后的设备列表
 */
export function applyDeviceCorrections(devices: any[]): any[] {
  return devices.map(device => {
    const corrected = applyDeviceCorrection(
      device.deviceId || device.id,
      device.latitude,
      device.longitude
    );

    if (corrected) {
      return {
        ...device,
        latitude: corrected.latitude,
        longitude: corrected.longitude,
      };
    }

    return device;
  });
}

/**
 * 检查设备是否配置了坐标纠偏
 *
 * @param deviceId 设备ID
 * @returns true表示已配置纠偏
 */
export function hasCorrection(deviceId: string): boolean {
  return deviceId in DEVICE_CORRECTIONS;
}

/**
 * 获取所有已配置纠偏的设备ID列表
 */
export function getCorrectedDeviceIds(): string[] {
  return Object.keys(DEVICE_CORRECTIONS);
}

/**
 * 添加设备纠偏配置
 *
 * @param deviceId 设备ID
 * @param latitude 纠偏后的纬度
 * @param longitude 纠偏后的经度
 */
export function addCorrection(
  deviceId: string,
  latitude: number,
  longitude: number
): void {
  DEVICE_CORRECTIONS[deviceId] = {
    latitude,
    longitude,
  };
  console.log(`[CoordinateCorrection] 添加设备 ${deviceId} 的纠偏配置: (${latitude}, ${longitude})`);
}

/**
 * 删除设备纠偏配置
 *
 * @param deviceId 设备ID
 */
export function removeCorrection(deviceId: string): void {
  if (DEVICE_CORRECTIONS[deviceId]) {
    delete DEVICE_CORRECTIONS[deviceId];
    console.log(`[CoordinateCorrection] 删除设备 ${deviceId} 的纠偏配置`);
  }
}

/**
 * 更新设备纠偏配置
 *
 * @param deviceId 设备ID
 * @param latitude 纠偏后的纬度
 * @param longitude 纠偏后的经度
 */
export function updateCorrection(
  deviceId: string,
  latitude: number,
  longitude: number
): void {
  if (DEVICE_CORRECTIONS[deviceId]) {
    DEVICE_CORRECTIONS[deviceId] = {
      latitude,
      longitude,
    };
    console.log(`[CoordinateCorrection] 更新设备 ${deviceId} 的纠偏配置: (${latitude}, ${longitude})`);
  } else {
    addCorrection(deviceId, latitude, longitude);
  }
}

/**
 * 获取所有纠偏配置
 */
export function getAllCorrections(): Record<string, { latitude: number; longitude: number }> {
  return { ...DEVICE_CORRECTIONS };
}

/**
 * 导出纠偏配置为JSON字符串
 */
export function exportCorrections(): string {
  return JSON.stringify(DEVICE_CORRECTIONS, null, 2);
}

/**
 * 从JSON字符串导入纠偏配置
 *
 * @param json JSON字符串
 */
export function importCorrections(json: string): void {
  try {
    const corrections = JSON.parse(json);
    Object.assign(DEVICE_CORRECTIONS, corrections);
    console.log(`[CoordinateCorrection] 导入 ${Object.keys(corrections).length} 条纠偏配置`);
  } catch (error) {
    console.error('[CoordinateCorrection] 导入纠偏配置失败:', error);
    throw new Error('无效的JSON格式');
  }
}
