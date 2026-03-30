import { Router, Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import prisma from '../lib/prisma';
import { emitLocationUpdate, emitFenceAlert } from './websocket';

const router = Router();

const JWT_SECRET = 'your-super-secret-jwt-key';

// JWT 认证中间件
const authenticate = (req: Request, res: Response, next: NextFunction) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      success: false,
      message: '未提供认证令牌'
    });
  }

  const token = authHeader.substring(7);
  try {
    const decoded = jwt.verify(token, JWT_SECRET) as any;
    req.userId = decoded.userId;
    next();
  } catch (error) {
    return res.status(401).json({
      success: false,
      message: '无效的认证令牌'
    });
  }
};

/**
 * POST /api/location/upload
 * 上报设备位置
 */
router.post('/upload', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { deviceId, latitude, longitude, altitude, speed, direction, accuracy, battery } = req.body;

    if (!deviceId || latitude === undefined || longitude === undefined) {
      return res.status(400).json({
        success: false,
        message: 'deviceId、latitude、longitude不能为空'
      });
    }

    // 验证设备归属
    const device = await prisma.device.findFirst({
      where: {
        deviceId: BigInt(deviceId)
      }
    });

    if (!device) {
      return res.status(404).json({
        success: false,
        message: '设备不存在或无权限'
      });
    }

    // 创建位置记录
    const location = await prisma.location.create({
      data: {
        deviceId: BigInt(deviceId),
        device_code: String(deviceId),
        latitude: Number(latitude),
        longitude: Number(longitude),
        speed: speed ? String(speed) : null,
        direction: direction ? Number(direction) : null,
        location_time: new Date()
      }
    });

    // 检查电子围栏
    if (device.userName) {
      await checkFences(String(deviceId), Number(latitude), Number(longitude), device.userName);
    }

    // WebSocket推送位置更新
    if (device.userName) {
      await emitLocationUpdate(device.userName, {
        deviceId,
        latitude,
        longitude,
        altitude,
        speed,
        direction,
        accuracy,
        battery,
        timestamp: new Date()
      });
    }

    res.json({
      success: true,
      message: '位置上报成功',
      data: { location }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * 检查设备是否进出电子围栏
 */
async function checkFences(device_code: string, latitude: number, longitude: number, userId: string) {
  try {
    const fences = await prisma.fence.findMany({
      where: { device_code }
    });

    for (const fence of fences) {
      const coordinates = JSON.parse(fence.fence_coordinates || '{}');
      const fenceLat = coordinates.latitude || 0;
      const fenceLng = coordinates.longitude || 0;
      const fenceRadius = coordinates.radius || 0;

      const distance = calculateDistance(latitude, longitude, fenceLat, fenceLng);

      // 检查是否刚刚进入/离开围栏
      // TODO: 需要记录设备上一次的围栏状态
      const isInside = distance <= fenceRadius;

      if (isInside) {
        // 创建围栏进入消息
        await prisma.message.create({
          data: {
            deviceId: device_code,
            device_code,
            message_type: 'fence',
            protocol_type: '0x8100',
            message_name: '进入安全围栏',
            decoded_data: `设备已进入「${fence.remark}」安全围栏`,
            receive_time: new Date()
          }
        });

        // WebSocket推送围栏通知
        await emitFenceAlert(userId, {
          deviceId: device_code,
          fenceId: String(fence.id),
          fenceName: fence.remark,
          action: 'enter',
          latitude,
          longitude
        });
      }
    }
  } catch (error) {
    console.error('[checkFences] 检查围栏失败:', error);
  }
}

/**
 * 计算两点之间的距离（Haversine公式）
 */
function calculateDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371e3; // 地球半径，单位：米
  const φ1 = lat1 * Math.PI / 180;
  const φ2 = lat2 * Math.PI / 180;
  const Δφ = (lat2 - lat1) * Math.PI / 180;
  const Δλ = (lon2 - lon1) * Math.PI / 180;

  const a = Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
            Math.cos(φ1) * Math.cos(φ2) *
            Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return R * c; // 返回距离，单位：米
}

export default router;
