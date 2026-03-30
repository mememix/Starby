import { Router, Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import prisma from '../lib/prisma';

const router = Router();

// JWT 认证中间件
const authenticate = (req: Request, res: Response, next: NextFunction) => {
  const JWT_SECRET = 'your-super-secret-jwt-key';
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
 * GET /api/sos/contacts
 * 获取SOS紧急联系人列表
 *
 * 注意: SOS联系人功能需要 lot_sos_contact 表支持
 * 当前数据库中暂无此表,功能暂时禁用
 */
/*
router.get('/contacts', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { deviceId } = req.query;

    const where: any = { userId: BigInt(req.userId) };
    if (deviceId) {
      where.deviceId = BigInt(deviceId);
    }

    // TODO: 需要在数据库中创建 lot_sos_contact 表
    const contacts = await prisma.sOSContact.findMany({
      where,
      orderBy: { order: 'asc' }
    });

    res.json({
      success: true,
      data: { contacts }
    });
  } catch (error) {
    next(error);
  }
});
*/

/**
 * POST /api/sos/contacts
 * 添加SOS紧急联系人
 *
 * 注意: SOS联系人功能需要 lot_sos_contact 表支持
 * 当前数据库中暂无此表,功能暂时禁用
 */
/*
router.post('/contacts', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { deviceId, name, phone, relation, isPrimary } = req.body;

    if (!name || !phone) {
      return res.status(400).json({
        success: false,
        message: '姓名和手机号不能为空'
      });
    }

    // TODO: 需要在数据库中创建 lot_sos_contact 表
    const contact = await prisma.sOSContact.create({
      data: {
        userId: BigInt(req.userId),
        deviceId: deviceId ? BigInt(deviceId) : null,
        name,
        phone,
        relation: relation || null,
        isPrimary: isPrimary || false,
        order: 1
      }
    });

    res.status(201).json({
      success: true,
      message: '添加成功',
      data: { contact }
    });
  } catch (error) {
    next(error);
  }
});
*/

/**
 * PUT /api/sos/contacts/:id
 * 更新SOS紧急联系人
 *
 * 注意: SOS联系人功能需要 lot_sos_contact 表支持
 * 当前数据库中暂无此表,功能暂时禁用
 */
/*
router.put('/contacts/:id', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;
    const { name, phone, relation, isPrimary } = req.body;

    // TODO: 需要在数据库中创建 lot_sos_contact 表
    const contact = await prisma.sOSContact.findFirst({
      where: {
        id: BigInt(id),
        userId: BigInt(req.userId)
      }
    });

    if (!contact) {
      return res.status(404).json({
        success: false,
        message: '联系人不存在'
      });
    }

    const updated = await prisma.sOSContact.update({
      where: { id: BigInt(id) },
      data: {
        name: name || contact.name,
        phone: phone || contact.phone,
        relation: relation !== undefined ? relation : contact.relation,
        isPrimary: isPrimary !== undefined ? isPrimary : contact.isPrimary
      }
    });

    res.json({
      success: true,
      message: '更新成功',
      data: { contact: updated }
    });
  } catch (error) {
    next(error);
  }
});
*/

/**
 * DELETE /api/sos/contacts/:id
 * 删除SOS紧急联系人
 *
 * 注意: SOS联系人功能需要 lot_sos_contact 表支持
 * 当前数据库中暂无此表,功能暂时禁用
 */
/*
router.delete('/contacts/:id', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;

    // TODO: 需要在数据库中创建 lot_sos_contact 表
    const contact = await prisma.sOSContact.findFirst({
      where: {
        id: BigInt(id),
        userId: BigInt(req.userId)
      }
    });

    if (!contact) {
      return res.status(404).json({
        success: false,
        message: '联系人不存在'
      });
    }

    await prisma.sOSContact.delete({
      where: { id: BigInt(id) }
    });

    res.json({
      success: true,
      message: '删除成功'
    });
  } catch (error) {
    next(error);
  }
});
*/

/**
 * POST /api/sos/trigger
 * 触发SOS报警
 */
router.post('/trigger', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { deviceId, location } = req.body;

    if (!deviceId) {
      return res.status(400).json({
        success: false,
        message: '设备ID不能为空'
      });
    }

    // 获取设备信息
    const device = await prisma.device.findUnique({
      where: { deviceId: BigInt(deviceId) },
    });

    if (!device) {
      return res.status(404).json({
        success: false,
        message: '设备不存在'
      });
    }

    // 创建SOS消息记录 (使用 Message 表)
    const message = await prisma.message.create({
      data: {
        deviceId: deviceId,
        device_code: device.deviceCode,
        message_type: 'SOS',
        protocol_type: 'JT808',
        message_id: '0002',
        message_name: 'SOS紧急报警',
        decoded_data: JSON.stringify({
          type: 'SOS',
          location: location,
          timestamp: new Date().toISOString()
        }),
        business_data: JSON.stringify({
          deviceName: device.deviceName,
          userPhone: device.userPhone,
        }),
        receive_time: new Date(),
        process_time: new Date(),
      }
    });

    // TODO: 创建报警记录
    // TODO: 发送三重通知
    // 1. 推送通知（极光推送）
    // 2. 短信通知（阿里云SMS）
    // 3. 电话通知（阿里云语音）

    // TODO: WebSocket实时推送

    res.json({
      success: true,
      message: 'SOS报警已触发',
      data: { message, device }
    });
  } catch (error) {
    next(error);
  }
});

export default router;
