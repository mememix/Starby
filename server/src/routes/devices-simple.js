import { Router, Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import mysql from 'mysql2/promise';
import dotenv from 'dotenv';

dotenv.config();

const router = Router();

const JWT_SECRET: jwt.Secret = 'your-super-secret-jwt-key';

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

// 创建数据库连接
const createConnection = async () => {
  return await mysql.createConnection({
    host: '116.204.117.57',
    port: 3307,
    user: 'root',
    password: 'StrongPass!',
    database: 'starby-dev'
  });
};

/**
 * GET /api/devices
 * 获取设备列表
 */
router.get('/', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    console.log('[GET /api/devices] userId:', req.userId);
    const connection = await createConnection();

    try {
      // 获取用户的手机号
      const [users] = await connection.execute(
        'SELECT phonenumber FROM sys_user WHERE user_id = ?',
        [req.userId]
      );

      if (users.length === 0) {
        return res.json({
          success: true,
          data: {
            devices: []
          }
        });
      }

      const phonenumber = users[0].phonenumber;

      // 查询用户的设备
      const [devices] = await connection.execute(
        `SELECT
          device_id,
          device_code,
          device_name,
          latitude,
          longitude,
          address,
          battery,
          status,
          avatar,
          last_location_time,
          bind_date,
          create_time
        FROM lot_device
        WHERE user_phone = ? AND del_flag = '0'
        ORDER BY create_time DESC`,
        [phonenumber]
      );

      console.log('[GET /api/devices] Found devices:', devices.length);

      res.json({
        success: true,
        data: {
          devices: devices.map((device: any) => ({
            id: device.device_id.toString(),
            name: device.device_name || '未命名设备',
            avatar: device.avatar,
            deviceNo: device.device_code || '',
            latitude: device.latitude,
            longitude: device.longitude,
            address: device.address,
            battery: device.battery,
            isOnline: device.status === '1',
            lastUpdate: device.last_location_time,
            ownerId: req.userId,
            bindTime: device.bind_date || device.create_time,
            isShared: false,
            ip: null,
            port: null
          }))
        }
      });
    } finally {
      await connection.end();
    }
  } catch (error) {
    next(error);
  }
});

export default router;
