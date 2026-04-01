import { Router, Request, Response, NextFunction } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import prisma from '../lib/prisma';
import dotenv from 'dotenv';
import { compressImage } from '../utils/imageCompressor';
import { sendLoginCode, verifyLoginCode } from '../utils/smsService';

// 扩展 Request 类型以添加 userId 属性
declare module 'express' {
  interface Request {
    userId?: string;
  }
}

dotenv.config();

const router = Router();

const JWT_EXPIRES_IN: string = process.env.JWT_EXPIRES_IN || '7d';

/**
 * 记录登录设备信息
 * @param userId 用户ID
 * @param req 请求对象
 */
async function recordLoginDevice(userId: number, req: Request): Promise<void> {
  try {
    const deviceId = req.headers['x-device-id'] as string || req.body.deviceId || 'unknown';
    const deviceName = req.headers['x-device-name'] as string || req.body.deviceName || '未知设备';
    const deviceType = req.headers['x-device-type'] as string || req.body.deviceType || 'unknown';
    const ipAddress = req.ip || req.connection.remoteAddress || '';
    const userAgent = req.headers['user-agent'] || '';

    // 打印设备信息用于调试
    console.log('[Auth] 记录登录设备 - userId:', userId);
    console.log('[Auth]   deviceId:', deviceId);
    console.log('[Auth]   deviceName:', deviceName);
    console.log('[Auth]   deviceType:', deviceType);
    console.log('[Auth]   ipAddress:', ipAddress);
    console.log('[Auth]   req.body:', JSON.stringify(req.body));
    console.log('[Auth]   req.headers[device]:', {
      'x-device-id': req.headers['x-device-id'],
      'x-device-name': req.headers['x-device-name'],
      'x-device-type': req.headers['x-device-type']
    });

    // 检查是否已存在该设备记录
    const existingDevice = await prisma.$queryRaw`
      SELECT id, is_current
      FROM lot_user_login_device
      WHERE user_id = ${userId}
      AND device_id = ${deviceId}
      AND del_flag = 0
    ` as any[];

    if (existingDevice && existingDevice.length > 0) {
      // 更新现有设备的登录信息
      await prisma.$queryRaw`
        UPDATE lot_user_login_device
        SET ip_address = ${ipAddress},
            device_name = ${deviceName},
            device_type = ${deviceType},
            last_login_time = NOW(),
            update_time = NOW(),
            user_agent = ${userAgent}
        WHERE id = ${existingDevice[0].id}
      `;
    } else {
      // 将其他设备标记为非当前
      await prisma.$queryRaw`
        UPDATE lot_user_login_device
        SET is_current = 0, update_time = NOW()
        WHERE user_id = ${userId}
        AND del_flag = 0
      `;

      // 插入新的设备记录
      await prisma.$queryRaw`
        INSERT INTO lot_user_login_device
          (user_id, device_id, device_name, device_type, ip_address, user_agent, is_current, last_login_time)
        VALUES
          (${userId}, ${deviceId}, ${deviceName}, ${deviceType}, ${ipAddress}, ${userAgent}, 1, NOW())
      `;
    }
  } catch (error) {
    // 记录登录设备失败不影响登录流程
    console.error('[Auth] 记录登录设备失败:', error);
  }
}

/**
 * POST /api/auth/login
 * 用户登录（支持手机号/设备号）
 */
router.post('/login', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { phone, password, deviceSn, deviceNo } = req.body;

    // 验证必要参数
    if (!password) {
      return res.status(400).json({
        success: false,
        message: '密码不能为空'
      });
    }

    let user;

    if (phone) {
      // 判断是管理后台登录还是移动端登录
      // 先尝试查询 lot_user 表（移动端）
      let isSysUser = false;

      // 优先查询 lot_user 表（移动端用户）
      user = await prisma.$queryRaw`
        SELECT user_id, phone_number, nickname, password, avatar_url
        FROM lot_user
        WHERE phone_number = ${phone}
        AND del_flag = '0'
      ` as any[];

      if (!user || user.length === 0) {
        // lot_user 表不存在，查询 sys_user 表（管理后台）
        isSysUser = true;
        user = await prisma.$queryRaw`
          SELECT user_id, user_name, nick_name, phonenumber, password, avatar
          FROM sys_user
          WHERE (user_name = ${phone} OR phonenumber = ${phone})
          AND del_flag = '0'
        ` as any[];
      }

      if (!user || user.length === 0) {
        return res.status(401).json({
          success: false,
          message: '用户不存在'
        });
      }

      user = user[0];

      // 密码验证
      let passwordValid = false;

      if (isSysUser) {
        // sys_user 表密码验证（支持明文、bcrypt）
        if (!user.password) {
          return res.status(401).json({
            success: false,
            message: '密码未设置'
          });
        }

        // 先尝试明文密码比对
        if (user.password === password) {
          passwordValid = true;
        } else if (user.password.length > 20) {
          // bcrypt 比对
          try {
            passwordValid = await bcrypt.compare(password, user.password);
          } catch (error) {
            // bcrypt 比对失败，保持 false
          }
        }
      } else {
        // lot_user 表密码验证（支持 MD5、明文、bcrypt）
        // 先尝试 MD5 比对
        const md5Hash = require('crypto').createHash('md5').update(password).digest('hex');
        if (user.password === md5Hash) {
          passwordValid = true;
        } else if (user.password === password) {
          // 明文密码比对
          passwordValid = true;
        } else if (user.password && user.password.length > 20) {
          // bcrypt 比对
          try {
            passwordValid = await bcrypt.compare(password, user.password);
          } catch (error) {
            // bcrypt 比对失败，保持 false
          }
        }
      }

      if (!passwordValid) {
        return res.status(401).json({
          success: false,
          message: '密码错误'
        });
      }
    } else if (deviceNo) {
      // 设备号登录
      const device = await prisma.device.findUnique({
        where: { deviceCode: deviceNo }
      });

      if (!device) {
        return res.status(401).json({
          success: false,
          message: '设备不存在'
        });
      }

      if (!device.userName) {
        return res.status(401).json({
          success: false,
          message: '设备未绑定到用户'
        });
      }

      // 验证设备密码
      if (!device.devicePassword) {
        return res.status(401).json({
          success: false,
          message: '设备未设置密码'
        });
      }

      const passwordValid = await bcrypt.compare(password, device.devicePassword);
      if (!passwordValid) {
        return res.status(401).json({
          success: false,
          message: '设备密码错误'
        });
      }

      // 查找用户（从 lot_user 表）
      const users = await prisma.$queryRaw`
        SELECT user_id, phone_number, nickname, avatar_url
        FROM lot_user
        WHERE user_name = ${device.userName}
        AND del_flag = '0'
      ` as any[];

      if (!users || users.length === 0) {
        return res.status(401).json({
          success: false,
          message: '设备绑定的用户不存在'
        });
      }

      user = users[0];
    } else if (deviceSn) {
      // 设备序列号登录（兼容旧版本）
      const device = await prisma.device.findFirst({
        where: { snCode: deviceSn }
      });

      if (!device) {
        return res.status(401).json({
          success: false,
          message: '设备不存在'
        });
      }

      // 查找用户
      if (!device.userName) {
        return res.status(401).json({
          success: false,
          message: '设备未绑定到用户'
        });
      }

      const users = await prisma.$queryRaw`
        SELECT user_id, phone_number, nickname, avatar_url
        FROM lot_user
        WHERE user_name = ${device.userName}
        AND del_flag = '0'
      ` as any[];

      if (!users || users.length === 0) {
        return res.status(401).json({
          success: false,
          message: '设备绑定的用户不存在'
        });
      }

      user = users[0];
    } else {
      return res.status(400).json({
        success: false,
        message: '请提供手机号或设备号'
      });
    }

    // 生成 JWT token - 硬编码秘钥保证一致
    const JWT_SECRET = 'your-super-secret-jwt-key';
    // 兼容 sys_user 和 lot_user 表的字段差异
    const phonenumber = user.phonenumber || user.phone_number || '';
    const nickname = user.nick_name || user.nickname || '';
    const avatar = user.avatar || user.avatar_url || null;
    
    const token = jwt.sign(
      { userId: Number(user.user_id).toString(), phonenumber },
      JWT_SECRET,
      { expiresIn: JWT_EXPIRES_IN } as jwt.SignOptions
    );

    // 记录登录设备信息
    await recordLoginDevice(Number(user.user_id), req);

    res.json({
      success: true,
      message: '登录成功',
      data: {
        token,
        user: {
          id: Number(user.user_id).toString(),
          phonenumber,
          nickname,
          avatar
        }
      }
    });
  } catch (error) {
    console.error('[Auth] 登录失败:', error);
    next(error);
  }
});

/**
 * POST /api/auth/send-code
 * 发送验证码
 */
router.post('/send-code', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { phone } = req.body;

    // 验证手机号格式
    if (!phone || !/^1[3-9]\d{9}$/.test(phone)) {
      return res.status(400).json({
        success: false,
        message: '手机号格式不正确'
      });
    }

    // 检查手机号是否已注册（用于区分登录和注册场景）
    const existingUser = await prisma.$queryRaw`
      SELECT user_id
      FROM lot_user
      WHERE phone_number = ${phone}
    ` as any[];

    const isRegistered = existingUser && existingUser.length > 0;

    // 发送验证码
    const codeResult = await sendLoginCode(phone);

    if (!codeResult.success) {
      return res.status(400).json({
        success: false,
        message: codeResult.message || '发送验证码失败'
      });
    }

    // 开发环境返回验证码方便调试
    const responseData: any = {
      success: true,
      message: '验证码发送成功',
      isRegistered: isRegistered
    };

    if (process.env.NODE_ENV === 'development' && codeResult.code) {
      responseData.code = codeResult.code;
    }

    res.json(responseData);
  } catch (error) {
    console.error('[Auth] 发送验证码失败:', error);
    next(error);
  }
});

/**
 * POST /api/auth/verify-login
 * 验证码登录
 */
router.post('/verify-login', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { phone, code } = req.body;

    // 验证参数
    if (!phone || !code) {
      return res.status(400).json({
        success: false,
        message: '手机号和验证码不能为空'
      });
    }

    // 验证手机号格式
    if (!/^1[3-9]\d{9}$/.test(phone)) {
      return res.status(400).json({
        success: false,
        message: '手机号格式不正确'
      });
    }

    // 验证码长度
    if (code.length !== 6 || !/^\d{6}$/.test(code)) {
      return res.status(400).json({
        success: false,
        message: '验证码格式不正确'
      });
    }

    // 检查用户是否存在
    const users = await prisma.$queryRaw`
      SELECT user_id, phone_number, nickname, avatar_url
      FROM lot_user
      WHERE phone_number = ${phone}
      AND del_flag = '0'
    ` as any[];

    if (!users || users.length === 0) {
      return res.status(404).json({
        success: false,
        message: '用户不存在，请先注册'
      });
    }

    const user = users[0];

    // 验证验证码
    const isCodeValid = verifyLoginCode(phone, code);

    if (!isCodeValid) {
      return res.status(400).json({
        success: false,
        message: '验证码错误或已过期'
      });
    }

    // 生成JWT token
    const JWT_SECRET = 'your-super-secret-jwt-key';
    const token = jwt.sign(
      { userId: Number(user.user_id).toString(), phonenumber: user.phone_number || '' },
      JWT_SECRET,
      { expiresIn: JWT_EXPIRES_IN } as jwt.SignOptions
    );

    // 记录登录设备信息
    await recordLoginDevice(Number(user.user_id), req);

    res.json({
      success: true,
      message: '登录成功',
      data: {
        token,
        user: {
          id: Number(user.user_id).toString(),
          phonenumber: user.phone_number,
          nickname: user.nickname || '',
          avatar: user.avatar_url
        }
      }
    });
  } catch (error) {
    console.error('[Auth] 验证码登录失败:', error);
    next(error);
  }
});

/**
 * POST /api/auth/verify-register
 * 验证码注册
 */
router.post('/verify-register', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { phone, code, password } = req.body;

    // 验证必要参数
    if (!phone || !code || !password) {
      return res.status(400).json({
        success: false,
        message: '手机号、验证码和密码不能为空'
      });
    }

    // 验证手机号格式
    if (!/^1[3-9]\d{9}$/.test(phone)) {
      return res.status(400).json({
        success: false,
        message: '手机号格式不正确'
      });
    }

    // 验证码格式
    if (code.length !== 6 || !/^\d{6}$/.test(code)) {
      return res.status(400).json({
        success: false,
        message: '验证码格式不正确'
      });
    }

    // 验证密码强度（至少6位）
    if (password.length < 6) {
      return res.status(400).json({
        success: false,
        message: '密码长度至少6位'
      });
    }

    // 检查手机号是否已注册
    const existingUser = await prisma.$queryRaw`
      SELECT user_id
      FROM lot_user
      WHERE phone_number = ${phone}
    ` as any[];

    if (existingUser && existingUser.length > 0) {
      return res.status(400).json({
        success: false,
        message: '该手机号已注册'
      });
    }

    // 验证验证码
    const isCodeValid = verifyLoginCode(phone, code);

    if (!isCodeValid) {
      return res.status(400).json({
        success: false,
        message: '验证码错误或已过期'
      });
    }

    // 使用MD5加密密码（与现有系统保持一致）
    const passwordHash = require('crypto').createHash('md5').update(password).digest('hex');

    // 创建用户到 lot_user 表
    await prisma.$queryRaw`
      INSERT INTO lot_user (phone_number, nickname, password, user_name, status, user_type, create_time, update_time)
      VALUES (${phone}, ${phone.substring(0, 10)}, ${passwordHash}, ${phone.substring(0, 10)}, 1, 1, NOW(), NOW())
    `;

    // 查询新创建的用户
    const newUser = await prisma.$queryRaw`
      SELECT user_id, phone_number, nickname, avatar_url
      FROM lot_user
      WHERE phone_number = ${phone}
    ` as any[];

    const userData = newUser[0];

    // 生成JWT token
    const JWT_SECRET = 'your-super-secret-jwt-key';
    const token = jwt.sign(
      { userId: Number(userData.user_id).toString(), phonenumber: userData.phone_number },
      JWT_SECRET,
      { expiresIn: JWT_EXPIRES_IN } as jwt.SignOptions
    );

    // 记录登录设备信息
    await recordLoginDevice(Number(userData.user_id), req);

    res.status(201).json({
      success: true,
      message: '注册成功',
      data: {
        token,
        user: {
          id: userData.user_id.toString(),
          phonenumber: userData.phone_number,
          nickname: userData.nickname || '',
          avatar: userData.avatar_url || null
        }
      }
    });
  } catch (error) {
    console.error('[Auth] 验证码注册失败:', error);
    next(error);
  }
});

/**
 * POST /api/auth/register
 * 用户注册
 */
router.post('/register', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { phone, password } = req.body;

    if (!phone || !password) {
      return res.status(400).json({
        success: false,
        message: '手机号和密码不能为空'
      });
    }

    // 检查手机号是否已注册
    const existingUser = await prisma.$queryRaw`
      SELECT user_id
      FROM lot_user
      WHERE phone_number = ${phone}
    ` as any[];

    if (existingUser && existingUser.length > 0) {
      return res.status(400).json({
        success: false,
        message: '该手机号已注册'
      });
    }

    // 使用 MD5 加密密码
    const passwordHash = require('crypto').createHash('md5').update(password).digest('hex');

    // 创建用户到 lot_user 表
    const user = await prisma.$queryRaw`
      INSERT INTO lot_user (phone_number, nickname, password, user_name, status, user_type, create_time, update_time)
      VALUES (${phone}, ${phone.substring(0, 10)}, ${passwordHash}, ${phone.substring(0, 10)}, 1, 1, NOW(), NOW())
    `;

    // 查询新创建的用户
    const newUser = await prisma.$queryRaw`
      SELECT user_id, phone_number, nickname, avatar_url
      FROM lot_user
      WHERE phone_number = ${phone}
    ` as any[];

    const userData = newUser[0];

    // 生成 JWT token
    const JWT_SECRET = 'your-super-secret-jwt-key';
    const token = jwt.sign(
      { userId: Number(userData.user_id).toString(), phonenumber: userData.phone_number },
      JWT_SECRET,
      { expiresIn: JWT_EXPIRES_IN } as jwt.SignOptions
    );

    res.status(201).json({
      success: true,
      message: '注册成功',
      data: {
        token,
        user: {
          id: userData.user_id.toString(),
          phonenumber: userData.phone_number,
          nickname: userData.nickname || '',
          avatar: userData.avatar_url || null,
          createdAt: userData.create_time
        }
      }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/auth/me
 * 获取当前用户信息
 */
router.get('/me', authenticateToken, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.userId;

    const users = await prisma.$queryRaw`
      SELECT user_id, phone_number, nickname, avatar_url, gender, remark, create_time
      FROM lot_user
      WHERE user_id = ${Number(userId)}
      AND del_flag = '0'
    ` as any[];

    if (!users || users.length === 0) {
      return res.status(404).json({
        success: false,
        message: '用户不存在'
      });
    }

    const user = users[0];

    res.json({
      success: true,
      data: {
        user: {
          id: user.user_id.toString(),
          phonenumber: user.phone_number,
          phone: user.phone_number, // 兼容前端读取 phone 字段
          nickname: user.nickname || '',
          avatar: user.avatar_url,
          gender: user.gender,
          bio: user.remark,
          createdAt: user.create_time
        }
      }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * PUT /api/auth/me
 * 更新当前用户信息
 */
/**
 * GET /api/auth/stats
 * 获取用户统计数据（我的伙伴、共享成员、打卡天数）
 */
router.get('/stats', authenticateToken, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = BigInt(req.userId as string);

    // 统计我的设备数量（我的伙伴）- 从lot_user_device_bind获取
    const myDevices = await prisma.$queryRaw`
      SELECT COUNT(*) as count
      FROM lot_user_device_bind
      WHERE user_id = ${userId}
      AND bind_status = 1
    ` as any[];

    // 将BigInt的count转换为Number
    const myPartnersCount = Number(myDevices[0]?.count || 0);

    // 统计共享成员总数
    // 这里简化处理：暂时返回0，因为没有share_user_ids字段
    const sharedMembers = 0;

    // 打卡天数 - 从lot_checkin表统计
    const checkinStats = await prisma.$queryRaw`
      SELECT COUNT(DISTINCT DATE(checkin_time)) as check_in_days
      FROM lot_checkin
      WHERE user_id = ${userId}
    ` as any[];

    const checkInDays = Number(checkinStats[0]?.check_in_days || 0);

    res.json({
      success: true,
      data: {
        myPartners: myPartnersCount,
        sharedMembers: sharedMembers,
        checkInDays: checkInDays
      }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/auth/devices
 * 获取登录设备列表
 */
router.get('/devices', authenticateToken, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = BigInt(req.userId as string);

    // 获取用户登录的设备列表
    const loginDevices = await prisma.$queryRaw`
      SELECT
        id,
        device_id,
        device_name,
        device_type,
        ip_address,
        location,
        is_current,
        last_login_time
      FROM lot_user_login_device
      WHERE user_id = ${userId}
      AND del_flag = 0
      ORDER BY last_login_time DESC
    ` as any[];

    // 将设备信息转换为前端格式
    const devices = loginDevices.map((device: any) => ({
      id: String(device.id),
      deviceName: device.device_name || '未知设备',
      deviceType: device.device_type || 'unknown',
      deviceId: device.device_id,
      ipAddress: device.ip_address,
      location: device.location,
      isCurrent: device.is_current === 1,
      lastLoginTime: device.last_login_time
    }));

    res.json({
      success: true,
      data: {
        devices,
        count: devices.length
      }
    });
  } catch (error) {
    console.error('[Auth] 获取登录设备失败:', error);
    next(error);
  }
});

/**
 * DELETE /api/auth/devices/:id
 * 删除登录设备（强制下线）
 */
router.delete('/devices/:id', authenticateToken, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = BigInt(req.userId as string);
    const deviceId = req.params.id;

    // 检查设备是否属于当前用户
    const device = await prisma.$queryRaw`
      SELECT id, is_current
      FROM lot_user_login_device
      WHERE id = ${Number(deviceId)}
      AND user_id = ${userId}
      AND del_flag = 0
    ` as any[];

    if (!device || device.length === 0) {
      return res.status(404).json({
        success: false,
        message: '设备不存在'
      });
    }

    // 不允许删除当前正在使用的设备
    if (device[0].is_current === 1) {
      return res.status(400).json({
        success: false,
        message: '不能删除当前正在使用的设备'
      });
    }

    // 软删除设备记录
    await prisma.$queryRaw`
      UPDATE lot_user_login_device
      SET del_flag = 1, update_time = NOW()
      WHERE id = ${Number(deviceId)}
      AND user_id = ${userId}
    `;

    res.json({
      success: true,
      message: '设备已下线'
    });
  } catch (error) {
    console.error('[Auth] 删除登录设备失败:', error);
    next(error);
  }
});

/**
 * DELETE /api/auth/account
 * 注销账户（删除用户及其所有相关数据）
 */
router.delete('/account', authenticateToken, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = BigInt(req.userId as string);
    console.log('[Auth] 注销账户，用户ID:', userId);

    // 1. 软删除用户（设置 del_flag = 1）
    await prisma.$queryRaw`
      UPDATE lot_user
      SET del_flag = 1, status = 0, update_time = NOW()
      WHERE user_id = ${userId}
    `;

    // 2. 删除用户的设备绑定（软删除）
    await prisma.$queryRaw`
      UPDATE lot_user_device_bind
      SET del_flag = 1, update_time = NOW()
      WHERE user_id = ${userId}
    `;

    // 3. 删除用户的登录设备记录（软删除）
    await prisma.$queryRaw`
      UPDATE lot_user_login_device
      SET del_flag = 1, update_time = NOW()
      WHERE user_id = ${userId}
    `;

    // 4. 删除用户的积分记录（软删除）
    await prisma.$queryRaw`
      UPDATE lot_user_points
      SET del_flag = 1, update_time = NOW()
      WHERE user_id = ${userId}
    `;

    // 5. 删除用户的签到记录（软删除）
    await prisma.$queryRaw`
      UPDATE lot_user_checkin
      SET del_flag = 1, update_time = NOW()
      WHERE user_id = ${userId}
    `;

    console.log('[Auth] 账户注销成功，用户ID:', userId);

    res.json({
      success: true,
      message: '账户已注销'
    });
  } catch (error) {
    console.error('[Auth] 账户注销失败:', error);
    next(error);
  }
});

router.put('/me', authenticateToken, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.userId!;
    const { nickname, avatar, gender, region, bio } = req.body;

    // 构建更新数据对象（只更新存在的字段）
    const updateFields: string[] = [];
    const values: any[] = [];
    
    if (nickname !== undefined) {
      // 验证昵称长度（数据库字段为VARCHAR(64)）
      if (nickname.length > 64) {
        return res.status(400).json({
          success: false,
          message: `昵称过长（${nickname.length}字符，最大64字符）`
        });
      }
      updateFields.push('nickname = ?');
      values.push(nickname);
    }
    if (avatar !== undefined) {
      // 处理空头像（清除头像）
      if (avatar === null || avatar === '') {
        updateFields.push('avatar_url = NULL');
      } else {
        let finalAvatar = avatar;
        
        // 验证是否是有效的base64图像URL
        const isBase64ImageUrl = typeof avatar === 'string' && 
          avatar.startsWith('data:image/') && 
          avatar.includes(';base64,');
        
        if (!isBase64ImageUrl) {
          return res.status(400).json({
            success: false,
            message: '无效的头像格式，请使用有效的base64图像数据'
          });
        }
        
        try {
          // 自动压缩头像到合适尺寸
          console.log(`[Avatar Compression] 开始压缩头像，原始长度: ${avatar.length}字符`);
          finalAvatar = await compressImage(avatar);
          console.log(`[Avatar Compression] 压缩后长度: ${finalAvatar.length}字符`);
        } catch (compressError) {
          console.error('[Avatar Compression] 头像压缩失败:', compressError);
          // 压缩失败，使用原始数据（但需验证长度）
        }
        
        // 验证avatar长度（数据库字段为VARCHAR(5000)）
        if (finalAvatar.length > 5000) {
          return res.status(400).json({
            success: false,
            message: `头像数据过长（${finalAvatar.length}字符，最大5000字符），请选择较小的图片或降低图片质量`
          });
        }
        updateFields.push('avatar_url = ?');
        values.push(finalAvatar);
      }
    }
    if (gender !== undefined) {
      // 验证性别长度（数据库字段为VARCHAR(255)）
      if (gender.length > 255) {
        return res.status(400).json({
          success: false,
          message: `性别字段过长（${gender.length}字符，最大255字符）`
        });
      }
      updateFields.push('gender = ?');
      values.push(gender);
    }
    if (bio !== undefined) {
      // 验证简介长度（数据库字段为VARCHAR(500)）
      if (bio.length > 500) {
        return res.status(400).json({
          success: false,
          message: `个人简介过长（${bio.length}字符，最大500字符）`
        });
      }
      updateFields.push('remark = ?');
      values.push(bio);
    }
    
    updateFields.push('update_time = NOW()');
    values.push(Number(userId));

    // 更新用户信息
    await prisma.$queryRawUnsafe(
      `UPDATE lot_user SET ${updateFields.join(', ')} WHERE user_id = ?`,
      ...values
    );

    // 查询更新后的用户信息
    const users = await prisma.$queryRaw`
      SELECT user_id, phone_number, nickname, avatar_url, gender, remark, create_time
      FROM lot_user
      WHERE user_id = ${Number(userId)}
      AND del_flag = '0'
    ` as any[];

    const user = users[0];

    res.json({
      success: true,
      message: '更新成功',
      data: {
        user: {
          id: user.user_id.toString(),
          phonenumber: user.phone_number,
          nickname: user.nickname || '',
          avatar: user.avatar_url,
          gender: user.gender,
          bio: user.remark,
          createdAt: user.create_time
        }
      }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/auth/upload-avatar
 * 上传用户头像
 */
router.post('/upload-avatar', authenticateToken, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.userId;

    // 检查是否包含文件（兼容multer未配置的情况）
    if (!(req as any).files || typeof (req as any).files !== 'object' || Object.keys((req as any).files).length === 0) {
      // 如果没有文件，检查是否有base64数据
      if (req.body.avatar) {
        // 使用base64数据更新头像
        let avatarUrl = req.body.avatar;
        
        // 验证是否是有效的base64图像URL
        const isBase64ImageUrl = typeof avatarUrl === 'string' && 
          avatarUrl.startsWith('data:image/') && 
          avatarUrl.includes(';base64,');
        
        if (!isBase64ImageUrl) {
          return res.status(400).json({
            success: false,
            message: '无效的头像格式，请使用有效的base64图像数据'
          });
        }
        
        try {
          // 自动压缩头像到合适尺寸
          console.log(`[Avatar Upload] 开始压缩头像，原始长度: ${avatarUrl.length}字符`);
          avatarUrl = await compressImage(avatarUrl);
          console.log(`[Avatar Upload] 压缩后长度: ${avatarUrl.length}字符`);
        } catch (compressError) {
          console.error('[Avatar Upload] 头像压缩失败:', compressError);
          // 压缩失败，使用原始数据（但需验证长度）
        }
        
        // 验证avatar长度（数据库字段为VARCHAR(5000)）
        if (avatarUrl.length > 5000) {
          return res.status(400).json({
            success: false,
            message: `头像数据过长（${avatarUrl.length}字符，最大5000字符），请选择较小的图片或降低图片质量`
          });
        }
        
        // 更新用户头像
        await prisma.$queryRaw`
          UPDATE lot_user
          SET avatar_url = ${avatarUrl}, update_time = NOW()
          WHERE user_id = ${Number(userId)}
        `;

        const users = await prisma.$queryRaw`
          SELECT user_id, phone_number, nickname, avatar_url
          FROM lot_user
          WHERE user_id = ${Number(userId)}
          AND del_flag = '0'
        ` as any[];

        const user = users[0];

        return res.json({
          success: true,
          message: '头像上传成功',
          data: {
            avatar: avatarUrl,
            user: {
              id: user.user_id.toString(),
              phonenumber: user.phone_number,
              nickname: user.nickname || '',
              avatar: user.avatar_url
            }
          }
        });
      }
      
      return res.status(400).json({
        success: false,
        message: '没有上传文件或头像数据'
      });
    }

    // 注意：这里需要配置multer来处理文件上传
    // 暂时返回示例URL，实际使用时需要配置文件存储
    const avatarUrl = `http://localhost:3000/uploads/avatars/${Date.now()}.jpg`;

    // 更新用户头像
    await prisma.$queryRaw`
      UPDATE lot_user
      SET avatar_url = ${avatarUrl}, update_time = NOW()
      WHERE user_id = ${Number(userId)}
    `;

    const users = await prisma.$queryRaw`
      SELECT user_id, phone_number, nickname, avatar_url
      FROM lot_user
      WHERE user_id = ${Number(userId)}
      AND del_flag = '0'
    ` as any[];

    const user = users[0];

    res.json({
      success: true,
      message: '头像上传成功',
      data: {
        avatar: avatarUrl,
        user: {
          id: user.user_id.toString(),
          phonenumber: user.phone_number,
          nickname: user.nickname || '',
          avatar: user.avatar_url
        }
      }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * JWT 认证中间件
 */
async function authenticateToken(req: Request, res: Response, next: NextFunction) {
  try {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
      return res.status(401).json({
        success: false,
        message: '未提供认证令牌'
      });
    }

    const JWT_SECRET = 'your-super-secret-jwt-key';
    const decoded = jwt.verify(token, JWT_SECRET) as { userId: string; phonenumber: string };
    req.userId = decoded.userId;
    next();
  } catch (error) {
    return res.status(401).json({
      success: false,
      message: '认证令牌无效'
    });
  }
}

export default router;
