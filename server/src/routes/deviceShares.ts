import { Router, Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import prisma from '../lib/prisma';

const router = Router();

const JWT_SECRET = 'your-super-secret-jwt-key';

/**
 * JWT 认证中间件
 */
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
 * 注意: 设备共享功能需要 lot_device_share 表支持
 * 当前数据库中暂无此表,所有功能暂时禁用
 */

/*
router.get('/:id/shares', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  // ... 完整的设备共享代码被注释 ...
});

router.post('/:id/shares', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  // ... 完整的设备共享代码被注释 ...
});

router.delete('/:id/shares/:userId', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  // ... 完整的设备共享代码被注释 ...
});

router.put('/:id/shares/:userId', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  // ... 完整的设备共享代码被注释 ...
});
*/

// 提供设备共享计数接口，返回0
router.get('/:id/shares/count', authenticate, async (req: Request, res: Response) => {
  res.json({
    success: true,
    count: 0,
    message: '设备共享功能暂不可用'
  });
});

// 提供一个简单的响应,说明功能暂不可用
router.get('/', authenticate, async (req: Request, res: Response) => {
  res.json({
    success: true,
    message: '设备共享功能暂不可用,需要在数据库中创建 lot_device_share 表',
    data: []
  });
});

export default router;
