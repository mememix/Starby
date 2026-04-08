import { Router, Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import prisma from '../lib/prisma';
import { manualCheckBattery } from '../services/batteryMonitor';

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
 * 获取用户绑定的设备ID列表
 */
async function getUserDeviceIds(userId: string): Promise<string[]> {
  // 查询用户绑定的设备
  const bindings = await prisma.deviceBinding.findMany({
    where: {
      userId: BigInt(userId),
      bindStatus: true,
    },
    select: {
      deviceNo: true,
    },
  });

  // 查询这些设备的实际deviceId
  const devices = await prisma.device.findMany({
    where: {
      deviceCode: {
        in: bindings.map(b => b.deviceNo),
      },
    },
    select: {
      deviceId: true,
      deviceCode: true,
    },
  });

  return devices.map(d => d.deviceId.toString());
}

/**
 * POST /api/messages/battery-alert
 * 创建电量告警消息
 */
router.post('/battery-alert', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { deviceId, battery, deviceName } = req.body;

    if (!deviceId || battery === undefined) {
      return res.status(400).json({
        success: false,
        message: '缺少必要参数'
      });
    }

    // 查询设备信息
    const device = await prisma.device.findFirst({
      where: {
        deviceId: BigInt(deviceId),
      },
    });

    if (!device) {
      return res.status(404).json({
        success: false,
        message: '设备不存在'
      });
    }

    // 查询绑定此设备的用户
    const bindings = await prisma.deviceBinding.findMany({
      where: {
        deviceNo: device.deviceCode,
        bindStatus: true,
      },
      select: {
        userId: true,
      },
    });

    if (bindings.length === 0) {
      return res.status(404).json({
        success: false,
        message: '设备未绑定任何用户'
      });
    }

    // 为每个绑定的用户创建电量告警消息
    const messages = await Promise.all(
      bindings.map(async (binding) => {
        return prisma.message.create({
          data: {
            deviceId: device.deviceId.toString(),
            device_code: device.deviceCode,
            message_type: battery < 10 ? 'lowBattery' : 'lowBattery',
            protocol_type: 'SYSTEM',
            message_id: '0x0002',
            message_name: '电量不足告警',
            decoded_data: JSON.stringify({
              deviceName: deviceName || device.deviceName || device.deviceCode,
              battery: battery,
              deviceCode: device.deviceCode,
              timestamp: new Date().toISOString(),
            }),
            business_data: JSON.stringify({
              userId: binding.userId.toString(),
              battery,
              alertLevel: battery < 10 ? 'critical' : 'warning',
            }),
            receive_time: new Date(),
            process_status: false,
          },
        });
      })
    );

    console.log(`[Battery Alert] Created ${messages.length} battery alert messages for device ${device.deviceCode}`);

    res.json({
      success: true,
      message: `已为${bindings.length}个用户发送电量告警`,
      data: {
        count: messages.length,
        deviceCode: device.deviceCode,
        battery,
        alertLevel: battery < 10 ? 'critical' : 'warning',
      }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/messages
 * 获取消息列表（仅显示当前用户绑定设备的消息）
 */
router.get('/', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { type, unreadOnly } = req.query;

    // 获取用户绑定的设备ID列表
    const deviceIds = await getUserDeviceIds(req.userId?.toString() || '0');

    if (deviceIds.length === 0) {
      return res.json({
        success: true,
        data: {
          messages: []
        }
      });
    }

    const where: any = {
      deviceId: {
        in: deviceIds,
      },
    };

    if (type) {
      if (type === 'fence') {
        // 围栏消息特殊处理：查询message_type=REQUEST且message_id=0x0200的消息
        where.message_type = 'REQUEST';
        where.message_id = '0x0200';
      } else {
        where.message_type = type;
      }
    }
    if (unreadOnly === 'true') {
      where.process_status = false;
    }

    const messages = await prisma.message.findMany({
      where,
      orderBy: { receive_time: 'desc' },
      take: 100
    });

    res.json({
      success: true,
      data: {
        messages: messages.map(m => {
          // 映射消息类型
          let messageType = 'system';
          let title = '系统消息';
          let content = m.message_name || m.message_id || '系统通知';
          let priority = 'normal';
          let decodedData: any = null;

          try {
            // 尝试解析decoded_data JSON字符串
            if (m.decoded_data) {
              decodedData = JSON.parse(m.decoded_data);
            }
          } catch (e) {
            // 如果解析失败，保留原始字符串
            decodedData = m.decoded_data;
          }

          // 设备低电量消息
          if (m.message_type === 'lowBattery' || m.message_id === '0x0002') {
            messageType = 'lowBattery';
            title = '电量不足';
            content = decodedData?.deviceName ? `${decodedData.deviceName}电量不足，请及时充电` : '设备电量不足，请及时充电';
            priority = 'important';
          }
          // 设备离线消息
          else if (m.message_type === 'offline') {
            messageType = 'offline';
            title = '设备离线';
            content = decodedData?.deviceName ? `${decodedData.deviceName}已离线` : '设备已离线';
            priority = 'important';
          }
          // 设备上线消息
          else if (m.message_type === 'online') {
            messageType = 'online';
            title = '设备上线';
            content = decodedData?.deviceName ? `${decodedData.deviceName}已上线` : '设备已上线';
          }
          // 围栏消息
          else if (m.message_type === 'REQUEST' && m.message_id === '0x0200') {
            messageType = 'fence';
            title = '位置信息更新';
            priority = 'important';

            // 解析围栏相关的数据
            if (decodedData && typeof decodedData === 'object') {
              const action = decodedData.action || decodedData.type || '未知';
              const deviceName = decodedData.deviceName || decodedData.device_name || '设备';
              content = `${deviceName}${action === 0 ? '进入' : action === 1 ? '离开' : ''}了围栏区域`;
            } else {
              content = '位置信息更新';
            }
          }
          // SOS消息
          else if (m.message_type === 'SOS') {
            messageType = 'sos';
            title = '紧急求助';
            priority = 'urgent';

            // 解析SOS数据
            if (decodedData && typeof decodedData === 'object') {
              const deviceName = decodedData.deviceName || decodedData.device_name || '设备';
              const address = decodedData.address || decodedData.location || '未知位置';
              const time = decodedData.time || decodedData.location_time || '';
              content = `${deviceName}在${address}触发SOS报警${time ? ` (${time})` : ''}`;
            } else {
              content = '设备触发了SOS报警';
            }
          }
          // 设备响应消息
          else if (m.message_type === 'RESPONSE' && m.message_id === '0x0100') {
            title = '设备响应';
            content = '设备已响应指令';
          }

          return {
            id: m.id.toString(),
            userId: req.userId?.toString() || '100',
            deviceId: m.deviceId,
            type: messageType,
            priority: priority,
            title: title,
            content: content,
            data: {
              deviceId: m.deviceId,
              message_id: m.message_id,
              decoded_data: decodedData,
              device_code: m.device_code
            },
            isRead: m.process_status || false,
            createdAt: (m.receive_time || m.createTime)?.toISOString() || new Date().toISOString(),
            readAt: m.process_time?.toISOString()
          };
        })
      }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/messages/:id
 * 获取消息详情
 */
router.get('/:id', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;

    // 获取用户绑定的设备ID列表
    const deviceIds = await getUserDeviceIds(req.userId?.toString() || '0');

    const message = await prisma.message.findFirst({
      where: {
        id: BigInt(id),
        deviceId: {
          in: deviceIds,
        },
      }
    });

    if (!message) {
      return res.status(404).json({
        success: false,
        message: '消息不存在'
      });
    }

    // 标记为已读
    if (!message.process_status) {
      await prisma.message.update({
        where: { id: BigInt(id) },
        data: {
          process_status: true,
          process_time: new Date()
        }
      });
    }

    // 映射消息类型
    let messageType = 'system';
    let title = '系统消息';
    let content = message.message_name || message.message_id || '系统通知';
    let priority = 'normal';
    let decodedData: any = null;

    try {
      if (message.decoded_data) {
        decodedData = JSON.parse(message.decoded_data);
      }
    } catch (e) {
      decodedData = message.decoded_data;
    }

    // 设备低电量消息
    if (message.message_type === 'lowBattery' || message.message_id === '0x0002') {
      messageType = 'lowBattery';
      title = '电量不足';
      content = decodedData?.deviceName ? `${decodedData.deviceName}电量不足，请及时充电` : '设备电量不足，请及时充电';
      priority = 'important';
    }
    // 设备离线消息
    else if (message.message_type === 'offline') {
      messageType = 'offline';
      title = '设备离线';
      content = decodedData?.deviceName ? `${decodedData.deviceName}已离线` : '设备已离线';
      priority = 'important';
    }
    // 设备上线消息
    else if (message.message_type === 'online') {
      messageType = 'online';
      title = '设备上线';
      content = decodedData?.deviceName ? `${decodedData.deviceName}已上线` : '设备已上线';
    }
    // 围栏消息
    else if (message.message_type === 'REQUEST' && message.message_id === '0x0200') {
      messageType = 'fence';
      title = '位置信息更新';
      priority = 'important';

      // 解析围栏相关的数据
      if (decodedData && typeof decodedData === 'object') {
        const action = decodedData.action || decodedData.type || '未知';
        const deviceName = decodedData.deviceName || decodedData.device_name || '设备';
        content = `${deviceName}${action === 0 ? '进入' : action === 1 ? '离开' : ''}了围栏区域`;
      } else {
        content = '位置信息更新';
      }
    }
    // SOS消息
    else if (message.message_type === 'SOS') {
      messageType = 'sos';
      title = '紧急求助';
      priority = 'urgent';

      // 解析SOS数据
      if (decodedData && typeof decodedData === 'object') {
        const deviceName = decodedData.deviceName || decodedData.device_name || '设备';
        const address = decodedData.address || decodedData.location || '未知位置';
        const time = decodedData.time || decodedData.location_time || '';
        content = `${deviceName}在${address}触发SOS报警${time ? ` (${time})` : ''}`;
      } else {
        content = '设备触发了SOS报警';
      }
    }
    // 设备响应消息
    else if (message.message_type === 'RESPONSE' && message.message_id === '0x0100') {
      title = '设备响应';
      content = '设备已响应指令';
    }

    res.json({
      success: true,
      data: {
        message: {
          id: message.id.toString(),
          userId: req.userId?.toString() || '100',
          deviceId: message.deviceId,
          type: messageType,
          priority: priority,
          title: title,
          content: content,
          data: {
            deviceId: message.deviceId,
            message_id: message.message_id,
            decoded_data: decodedData,
            device_code: message.device_code
          },
          isRead: message.process_status || false,
          createdAt: (message.receive_time || message.createTime)?.toISOString() || new Date().toISOString(),
          readAt: message.process_time?.toISOString()
        }
      }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * PUT /api/messages/:id/read
 * 标记消息为已读
 */
router.put('/:id/read', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;

    // 获取用户绑定的设备ID列表
    const deviceIds = await getUserDeviceIds(req.userId?.toString() || '0');

    const message = await prisma.message.findFirst({
      where: {
        id: BigInt(id),
        deviceId: {
          in: deviceIds,
        },
      }
    });

    if (!message) {
      return res.status(404).json({
        success: false,
        message: '消息不存在'
      });
    }

    const updated = await prisma.message.update({
      where: { id: BigInt(id) },
      data: {
        process_status: true,
        process_time: new Date()
      }
    });

    // 映射消息类型
    let messageType = 'system';
    let title = '系统消息';
    let content = updated.message_name || updated.message_id || '系统通知';
    let priority = 'normal';
    let decodedData: any = null;

    try {
      if (updated.decoded_data) {
        decodedData = JSON.parse(updated.decoded_data);
      }
    } catch (e) {
      decodedData = updated.decoded_data;
    }

    // 设备低电量消息
    if (updated.message_type === 'lowBattery' || updated.message_id === '0x0002') {
      messageType = 'lowBattery';
      title = '电量不足';
      content = decodedData?.deviceName ? `${decodedData.deviceName}电量不足，请及时充电` : '设备电量不足，请及时充电';
      priority = 'important';
    }
    // 设备离线消息
    else if (updated.message_type === 'offline') {
      messageType = 'offline';
      title = '设备离线';
      content = decodedData?.deviceName ? `${decodedData.deviceName}已离线` : '设备已离线';
      priority = 'important';
    }
    // 设备上线消息
    else if (updated.message_type === 'online') {
      messageType = 'online';
      title = '设备上线';
      content = decodedData?.deviceName ? `${decodedData.deviceName}已上线` : '设备已上线';
    }
    // 围栏消息
    else if (updated.message_type === 'REQUEST' && updated.message_id === '0x0200') {
      messageType = 'fence';
      title = '位置信息更新';
      priority = 'important';

      // 解析围栏相关的数据
      if (decodedData && typeof decodedData === 'object') {
        const action = decodedData.action || decodedData.type || '未知';
        const deviceName = decodedData.deviceName || decodedData.device_name || '设备';
        content = `${deviceName}${action === 0 ? '进入' : action === 1 ? '离开' : ''}了围栏区域`;
      } else {
        content = '位置信息更新';
      }
    }
    // SOS消息
    else if (updated.message_type === 'SOS') {
      messageType = 'sos';
      title = '紧急求助';
      priority = 'urgent';

      // 解析SOS数据
      if (decodedData && typeof decodedData === 'object') {
        const deviceName = decodedData.deviceName || decodedData.device_name || '设备';
        const address = decodedData.address || decodedData.location || '未知位置';
        const time = decodedData.time || decodedData.location_time || '';
        content = `${deviceName}在${address}触发SOS报警${time ? ` (${time})` : ''}`;
      } else {
        content = '设备触发了SOS报警';
      }
    }
    // 设备响应消息
    else if (updated.message_type === 'RESPONSE' && updated.message_id === '0x0100') {
      title = '设备响应';
      content = '设备已响应指令';
    }

    res.json({
      success: true,
      message: '已标记为已读',
      data: {
        message: {
          id: updated.id.toString(),
          userId: req.userId?.toString() || '100',
          deviceId: updated.deviceId,
          type: messageType,
          priority: priority,
          title: title,
          content: content,
          data: {
            deviceId: updated.deviceId,
            message_id: updated.message_id,
            decoded_data: decodedData,
            device_code: updated.device_code
          },
          isRead: updated.process_status || false,
          createdAt: updated.receive_time || updated.createTime,
          readAt: updated.process_time
        }
      }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * PUT /api/messages/read-all
 * 标记所有消息为已读
 */
router.put('/read-all', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { type } = req.body;

    // 获取用户绑定的设备ID列表
    const deviceIds = await getUserDeviceIds(req.userId?.toString() || '0');

    const where: any = {
      deviceId: {
        in: deviceIds,
      },
    };

    if (type) {
      if (type === 'fence') {
        // 围栏消息特殊处理：查询message_type=REQUEST且message_id=0x0200的消息
        where.message_type = 'REQUEST';
        where.message_id = '0x0200';
      } else {
        where.message_type = type;
      }
    }

    const result = await prisma.message.updateMany({
      where,
      data: {
        process_status: true,
        process_time: new Date()
      }
    });

    res.json({
      success: true,
      message: `已标记${result.count}条消息为已读`,
      data: { count: result.count }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * DELETE /api/messages/:id
 * 删除消息
 */
router.delete('/:id', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;

    // 获取用户绑定的设备ID列表
    const deviceIds = await getUserDeviceIds(req.userId?.toString() || '0');

    const message = await prisma.message.findFirst({
      where: {
        id: BigInt(id),
        deviceId: {
          in: deviceIds,
        },
      }
    });

    if (!message) {
      return res.status(404).json({
        success: false,
        message: '消息不存在'
      });
    }

    await prisma.message.delete({
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

/**
 * DELETE /api/messages/clear
 * 清空所有已读消息
 */
router.delete('/clear', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    // 获取用户绑定的设备ID列表
    const deviceIds = await getUserDeviceIds(req.userId?.toString() || '0');

    const result = await prisma.message.deleteMany({
      where: {
        deviceId: {
          in: deviceIds,
        },
        process_status: true
      }
    });

    res.json({
      success: true,
      message: `已清除${result.count}条已读消息`,
      data: { count: result.count }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * DELETE /api/messages/clear-all
 * 清空所有消息（包括未读）
 */
router.delete('/clear-all', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { type } = req.body;

    // 获取用户绑定的设备ID列表
    const deviceIds = await getUserDeviceIds(req.userId?.toString() || '0');

    const where: any = {
      deviceId: {
        in: deviceIds,
      },
    };

    if (type) {
      if (type === 'fence') {
        // 围栏消息特殊处理：查询message_type=REQUEST且message_id=0x0200的消息
        where.message_type = 'REQUEST';
        where.message_id = '0x0200';
      } else {
        where.message_type = type;
      }
    }

    const result = await prisma.message.deleteMany({
      where
    });

    res.json({
      success: true,
      message: `已清除${result.count}条消息`,
      data: { count: result.count }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/messages/check-battery
 * 手动触发电池检查（用于测试）
 */
router.post('/check-battery', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const count = await manualCheckBattery();
    res.json({
      success: true,
      message: `电池检查完成，共创建 ${count} 条低电量告警消息`,
      data: { count }
    });
  } catch (error) {
    next(error);
  }
});

export default router;
