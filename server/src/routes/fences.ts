import { Router, Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import prisma from '../lib/prisma';

const router = Router();

const JWT_SECRET: jwt.Secret = process.env.JWT_SECRET || 'your-super-secret-jwt-key';

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
 * GET /api/fences
 * 获取电子围栏列表
 */
router.get('/', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    // 查询所有围栏
    const fences = await prisma.fence.findMany({
      orderBy: { createTime: 'desc' }
    });

    // 转换为前端期望的格式
    const fencesData = fences.map(fence => {
      const coords = fence.fence_coordinates ? JSON.parse(fence.fence_coordinates) : {};
      return {
        id: fence.id.toString(),
        deviceId: fence.device_code, // 前端期望的deviceId字段
        name: fence.fence_name || '未命名围栏', // 前端期望的name字段
        latitude: coords.latitude || 0,
        longitude: coords.longitude || 0,
        radius: coords.radius || 0,
        createdAt: fence.createTime?.toISOString() || new Date().toISOString(),
        fenceType: fence.fence_type,
        alarmType: fence.alarm_type,
        status: fence.status,
        description: fence.description
      };
    });

    res.json({
      success: true,
      data: { fences: fencesData }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/fences
 * 创建电子围栏
 */
router.post('/', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { deviceId, name, latitude, longitude, radius, alarmType = 'both' } = req.body;

    if (!deviceId || latitude === undefined || longitude === undefined || !radius) {
      return res.status(400).json({
        success: false,
        message: '缺少必要参数'
      });
    }

    // 验证设备是否存在
    const device = await prisma.device.findFirst({
      where: { deviceId: BigInt(deviceId) }
    });

    if (!device) {
      return res.status(404).json({
        success: false,
        message: '设备不存在'
      });
    }

    // 创建围栏
    const fence = await prisma.fence.create({
      data: {
        device_code: String(deviceId),
        fence_name: name || '未命名围栏',
        fence_coordinates: JSON.stringify({
          latitude: Number(latitude),
          longitude: Number(longitude),
          radius: Number(radius)
        }),
        alarm_type: alarmType || 'both'
      }
    });

    // 转换为前端期望的格式
    const fenceData = {
      id: fence.id.toString(),
      deviceId: fence.device_code,
      name: fence.fence_name || '未命名围栏',
      latitude: Number(latitude),
      longitude: Number(longitude),
      radius: Number(radius),
      createdAt: fence.createTime?.toISOString() || new Date().toISOString(),
      fenceType: fence.fence_type,
      alarmType: fence.alarm_type,
      status: fence.status,
      description: fence.description
    };

    res.status(201).json({
      success: true,
      message: '围栏创建成功',
      data: { fence: fenceData }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * PUT /api/fences/:id
 * 更新电子围栏
 */
router.put('/:id', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;
    const { name, latitude, longitude, radius, alarmType } = req.body;

    // 验证围栏是否存在
    const fence = await prisma.fence.findFirst({
      where: { id: BigInt(id) }
    });

    if (!fence) {
      return res.status(404).json({
        success: false,
        message: '围栏不存在'
      });
    }

    // 更新围栏
    const updateData: any = {};
    if (name !== undefined) {
      updateData.fence_name = name;
    }
    if (latitude !== undefined || longitude !== undefined || radius !== undefined) {
      const coords = fence.fence_coordinates ? JSON.parse(fence.fence_coordinates) : {};
      updateData.fence_coordinates = JSON.stringify({
        latitude: latitude !== undefined ? Number(latitude) : coords.latitude || 0,
        longitude: longitude !== undefined ? Number(longitude) : coords.longitude || 0,
        radius: radius !== undefined ? Number(radius) : coords.radius || 0
      });
    }
    if (alarmType !== undefined) {
      updateData.alarm_type = alarmType;
    }

    const updatedFence = await prisma.fence.update({
      where: { id: BigInt(id) },
      data: updateData
    });

    // 转换为前端期望的格式
    const coords = updatedFence.fence_coordinates ? JSON.parse(updatedFence.fence_coordinates) : {};
    const fenceData = {
      id: updatedFence.id.toString(),
      deviceId: updatedFence.device_code,
      name: updatedFence.fence_name || '未命名围栏',
      latitude: coords.latitude || 0,
      longitude: coords.longitude || 0,
      radius: coords.radius || 0,
      createdAt: updatedFence.createTime?.toISOString() || new Date().toISOString(),
      fenceType: updatedFence.fence_type,
      alarmType: updatedFence.alarm_type,
      status: updatedFence.status,
      description: updatedFence.description
    };

    res.json({
      success: true,
      message: '围栏更新成功',
      data: { fence: fenceData }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * DELETE /api/fences/:id
 * 删除电子围栏
 */
router.delete('/:id', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;

    // 验证围栏是否存在
    const fence = await prisma.fence.findFirst({
      where: { id: BigInt(id) }
    });

    if (!fence) {
      return res.status(404).json({
        success: false,
        message: '围栏不存在'
      });
    }

    // 删除围栏
    await prisma.fence.delete({
      where: { id: BigInt(id) }
    });

    res.json({
      success: true,
      message: '围栏删除成功'
    });
  } catch (error) {
    next(error);
  }
});

export default router;
