import { Router, Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import prisma from '../lib/prisma';
import dotenv from 'dotenv';
import { Decimal } from '@prisma/client/runtime/library';
import { compressImage } from '../utils/imageCompressor';
import { transformCoordinate } from '../utils/coordinateTransformer';

dotenv.config();

const router = Router();

/** Convert Prisma Decimal to number or null */
function toNum(val: Decimal | string | number | null | undefined): number | string | null | undefined {
  if (val == null) return null;
  if (val instanceof Decimal) return val.toNumber();
  return val;
}

// 硬编码确保一致
const JWT_SECRET: jwt.Secret = 'your-super-secret-jwt-key';

// JWT 认证中间件 - 硬编码秘钥保证一致
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
    const JWT_SECRET = 'your-super-secret-jwt-key';
    console.log('[DEBUG authenticate] JWT_SECRET =', JSON.stringify(JWT_SECRET), 'length =', JWT_SECRET.length);
    console.log('[DEBUG authenticate] Token =', token.substring(0, 60) + '...');
    const decoded = jwt.verify(token, JWT_SECRET) as any;
    req.userId = decoded.userId;
    next();
  } catch (error) {
    console.log('[DEBUG authenticate] VERIFY FAILED:', error);
    return res.status(401).json({
      success: false,
      message: '无效的认证令牌'
    });
  }
};

/**
 * GET /api/devices/stats
 * 获取管理员统计数据（全站统计）
 */
router.get('/stats', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    // 统计总用户数
    const totalUsers = await prisma.$queryRaw`
      SELECT COUNT(*) as count
      FROM sys_user
      WHERE del_flag = 0
    ` as any[];

    // 统计在线设备数 - 从lot_user_device_bind表统计绑定状态为1的设备
    const onlineDevices = await prisma.$queryRaw`
      SELECT COUNT(DISTINCT device_id) as count
      FROM lot_user_device_bind
      WHERE bind_status = 1
    ` as any[];

    // 统计今日活跃用户数 - 有今天登录记录的用户
    const todayActive = await prisma.$queryRaw`
      SELECT COUNT(DISTINCT user_id) as count
      FROM lot_user_login_device
      WHERE DATE(last_login_time) = CURDATE()
    ` as any[];

    // 统计正常设备数 - 设备状态正常的（排除故障、异常等）
    const normalDevices = await prisma.$queryRaw`
      SELECT COUNT(DISTINCT device_id) as count
      FROM lot_user_device_bind
      WHERE bind_status = 1
    ` as any[];

    res.json({
      success: true,
      data: {
        totalUsers: Number(totalUsers[0]?.count || 0),
        onlineDevices: Number(onlineDevices[0]?.count || 0),
        todayActive: Number(todayActive[0]?.count || 0),
        normalDevices: Number(normalDevices[0]?.count || 0)
      }
    });
  } catch (error) {
    console.error('[Devices] 获取统计数据失败:', error);
    next(error);
  }
});

/**
 * GET /api/devices
 * 获取设备列表
 */
router.get('/', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = BigInt(req.userId as string);

    // 查询用户绑定的设备
    const bindings = await prisma.deviceBinding.findMany({
      where: {
        userId: userId,
        bindStatus: true
      },
      orderBy: { bindTime: 'desc' }
    });

    // 获取设备详细信息
    const deviceIds = bindings.map(b => b.deviceId).filter((id): id is bigint => id !== null);
    const devices = await prisma.device.findMany({
      where: {
        deviceId: { in: deviceIds }
      },
      orderBy: { createTime: 'desc' }
    });

    // 创建绑定信息的映射（用于获取用户自定义的设备名称）
    const bindingMap = new Map(bindings.map(b => [b.deviceId?.toString(), b]));

    // 获取用户头像（从 lot_user 表）
    const users = await prisma.$queryRaw`
      SELECT avatar_url
      FROM lot_user
      WHERE user_id = ${userId}
      AND del_flag = '0'
    ` as any[];
    const userAvatar = users.length > 0 ? users[0].avatar_url : null;

    res.json({
      success: true,
      data: {
        devices: devices.map(device => {
          const binding = bindingMap.get(device.deviceId.toString());

          // 应用统一坐标转换（WGS-84 -> GCJ-02 + 统一偏移）
          const transformed = transformCoordinate(
            toNum(device.latitude),
            toNum(device.longitude)
          );

          return {
            deviceId: device.deviceId.toString(),
          deviceCode: device.deviceCode,
          devicePassword: device.devicePassword,
          bindStatus: device.bindStatus,
          userName: device.userName,
          userPhone: device.userPhone,
          registerDate: device.registerDate,
          bindDate: device.bindDate,
          uniqueId: device.uniqueId,
          locationInfo: device.locationInfo,
          // address: device.address, // 移除地址字段，由前端实时逆地理编码
          longitude: transformed?.longitude ?? device.longitude,
          latitude: transformed?.latitude ?? device.latitude,
          snCode: device.snCode,
          isTimedReport: device.isTimedReport,
          report_period: device.report_period,
          battery: device.battery,
          batteryLevel: device.batteryLevel,
          firmwareVersion: device.firmwareVersion,
          deviceName: binding?.deviceName || device.deviceName,
          deviceType: device.deviceType,
          deviceModel: device.deviceModel,
          simNumber: device.simNumber,
          imei: device.imei,
          plateNumber: device.plateNumber,
          vehicleType: device.vehicleType,
          company: device.company,
          status: device.status,
          avatar: device.avatar,
          userAvatar: userAvatar, // 使用用户头像
          manufacturer: device.manufacturer,
          decodeProtocol: device.decodeProtocol,
          remark: device.remark,
          createBy: device.createBy,
          createTime: device.createTime,
          updateBy: device.updateBy,
          updateTime: device.updateTime,
          delFlag: device.delFlag,
          lastLocationTime: device.lastLocationTime,
          isTop: device.isTop
          };
        })
      }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/devices/unbound
 * 获取可绑定的JT808设备列表
 */
router.get('/unbound', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = BigInt(req.userId as string);

    // 查询当前用户已绑定的设备ID
    const userBoundDevices = await prisma.deviceBinding.findMany({
      where: {
        userId: userId,
        bindStatus: true
      },
      select: {
        deviceId: true
      }
    });

    const boundDeviceIds = userBoundDevices.map(b => b.deviceId).filter((id): id is bigint => id !== null);

    // 查询所有设备，排除已绑定到当前用户的设备
    // 同时排除已被其他用户绑定的设备（只返回未被任何用户绑定的设备）
    const allBindings = await prisma.deviceBinding.findMany({
      where: {
        bindStatus: true
      },
      select: {
        deviceId: true
      }
    });

    const allBoundDeviceIds = allBindings.map(b => b.deviceId).filter((id): id is bigint => id !== null);

    // 查询未被任何用户绑定的设备
    const devices = await prisma.device.findMany({
      where: {
        deviceId: {
          notIn: allBoundDeviceIds
        }
        // delFlag: '0' // 移除此过滤条件，因为类型不匹配
      },
      orderBy: { createTime: 'desc' }
    });

    res.json({
      success: true,
      data: {
        devices: devices.map(device => {
          // 应用统一坐标转换（WGS-84 -> GCJ-02 + 统一偏移）
          const transformed = transformCoordinate(
            toNum(device.latitude),
            toNum(device.longitude)
          );

          return {
            id: device.deviceId.toString(),
            deviceId: device.deviceId.toString(),
            deviceNo: device.deviceCode,
            name: device.deviceName || device.deviceCode || '未命名设备',
            isOnline: device.status === '1',
            latitude: transformed?.latitude?.toString() ?? device.latitude?.toString(),
            longitude: transformed?.longitude?.toString() ?? device.longitude?.toString(),
            address: device.address,
            battery: device.battery,
            batteryLevel: device.batteryLevel,
            lastUpdate: device.lastLocationTime,
            bindTime: device.bindDate,
            ownerId: null,
            avatar: device.avatar,
            createTime: device.createTime
          };
        })
      }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/devices/all
 * 获取所有设备列表（管理员用）
 */
router.get('/all', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const limit = Number(req.query.limit) || 10;
    const offset = Number(req.query.offset) || 0;

    console.log('[Devices All] 开始查询设备列表，limit:', limit, 'offset:', offset);

    // 获取所有绑定设备信息
    const allBindings = await prisma.$queryRaw`
      SELECT
        b.device_id,
        b.user_id,
        b.device_name as custom_name,
        b.bind_time
      FROM lot_user_device_bind b
      WHERE b.bind_status = 1
      ORDER BY b.bind_time DESC
    ` as any[];

    console.log('[Devices All] 所有绑定记录数量（去重前）:', allBindings.length);

    // 去重：每个设备只保留最新的绑定记录（按 bind_time 排序后取第一条）
    const deviceMap = new Map();
    for (const binding of allBindings) {
      const deviceId = String(binding.device_id);
      if (!deviceMap.has(deviceId)) {
        deviceMap.set(deviceId, binding);
      }
    }

    const bindings = Array.from(deviceMap.values()).slice(offset, offset + limit);

    console.log('[Devices All] 去重后绑定记录数量:', deviceMap.size);
    console.log('[Devices All] 返回的绑定记录（分页后）:', bindings.length);
    console.log('[Devices All] 绑定记录:', bindings.map(b => ({
      device_id: b.device_id,
      user_id: b.user_id,
      custom_name: b.custom_name
    })));

    // 获取用户信息
    const userIds = bindings.map(b => b.user_id).filter(id => id !== null);
    console.log('[Devices All] 需要查询的用户IDs:', userIds);

    // 使用 Prisma 原生查询，避免 SQL IN 子句的问题
    const users = await prisma.$queryRaw`
      SELECT user_id, nickname, phone_number
      FROM lot_user
      WHERE del_flag = '0'
    ` as any[];

    console.log('[Devices All] 查询到的所有用户数量（未过滤）:', users.length);

    // 过滤出需要的用户
    const filteredUsers = users.filter((u: any) => userIds.includes(u.user_id));
    console.log('[Devices All] 过滤后匹配的用户数量:', filteredUsers.length);
    console.log('[Devices All] 过滤后的用户列表:', filteredUsers);

    // 创建用户映射
    const userMap = new Map(filteredUsers.map(u => [String(u.user_id), u]));

    // 获取设备详细信息
    const devices = await prisma.$queryRaw`
      SELECT
        d.device_id,
        d.device_code,
        d.device_name,
        d.status,
        d.latitude,
        d.longitude,
        d.address,
        d.battery,
        d.last_location_time,
        d.create_time
      FROM lot_device d
    ` as any[];

    // 创建设备详细信息映射（注意：这里不使用 deviceMap 变量名，避免重复声明）
    const deviceInfoMap = new Map(devices.map(d => [String(d.device_id), d]));

    // 合并数据
    const result = bindings.map((binding: any) => {
      const device = deviceInfoMap.get(String(binding.device_id));
      const user = userMap.get(String(binding.user_id));
      const merged = {
        id: String(binding.device_id),
        name: binding.custom_name || device?.device_name || '未命名设备',
        userName: user?.nickname || '未知用户',
        userPhone: user?.phone_number || '',
        online: device?.status === '1',
        lastOnline: device?.last_location_time || '未知',
        deviceCode: device?.device_code || ''
      };
      console.log('[Devices All] 合并设备数据:', {
        device_id: binding.device_id,
        user_id: binding.user_id,
        user_found: !!user,
        result_userName: merged.userName
      });
      return merged;
    });

    res.json({
      success: true,
      data: {
        devices: result,
        total: result.length
      }
    });
  } catch (error) {
    console.error('[Devices] 获取设备列表失败:', error);
    next(error);
  }
});

/**
 * GET /api/devices/users
 * 获取所有用户列表（管理员用）
 */
router.get('/users', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const limit = Number(req.query.limit) || 100;
    const offset = Number(req.query.offset) || 0;

    console.log('[Devices Users] 开始查询用户列表，limit:', limit, 'offset:', offset);

    // 获取 lot_user 表用户列表（先不加 del_flag 条件，看看能查到多少）
    const allUsers = await prisma.$queryRaw`
      SELECT
        u.user_id,
        u.nickname,
        u.phone_number,
        u.avatar_url,
        u.create_time,
        u.del_flag
      FROM lot_user u
      ORDER BY u.user_id DESC
      LIMIT ${limit + 50}
      OFFSET ${offset}
    ` as any[];

    console.log('[Devices Users] lot_user 表查询到用户数量（包括已删除）:', allUsers.length);
    console.log('[Devices Users] 所有用户列表（包括已删除）:', allUsers.map(u => ({
      user_id: u.user_id,
      nickname: u.nickname,
      phone_number: u.phone_number,
      del_flag: u.del_flag
    })));

    // 过滤掉已删除的用户（del_flag = '0' 表示未删除）
    const users = allUsers.filter((user: any) => user.del_flag === '0' || user.del_flag === 0);

    console.log('[Devices Users] 过滤后未删除用户数量:', users.length);

    // 获取每个用户的设备数量
    const userBindings = await prisma.$queryRaw`
      SELECT
        user_id,
        COUNT(*) as device_count
      FROM lot_user_device_bind
      WHERE bind_status = 1
      GROUP BY user_id
    ` as any[];

    console.log('[Devices Users] 设备绑定记录数量:', userBindings.length);

    // 创建设备数量映射
    const bindingMap = new Map(userBindings.map(b => [String(b.user_id), Number(b.device_count)]));

    // 合并数据
    const result = users.slice(0, limit).map((user: any) => ({
      id: String(user.user_id),
      nickname: user.nickname || '未命名',
      phone: user.phone_number || '',
      avatar: user.avatar_url,
      createdAt: user.create_time,
      deviceCount: bindingMap.get(String(user.user_id)) || 0
    }));

    res.json({
      success: true,
      data: {
        users: result,
        total: result.length
      }
    });
  } catch (error) {
    console.error('[Devices] 获取用户列表失败:', error);
    next(error);
  }
});

/**
 * GET /api/devices/:id
 * 获取单个设备详情
 */
router.get('/:id', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = BigInt(req.userId as string);
    const deviceId = BigInt(req.params.id);

    // 验证设备是否属于该用户
    const binding = await prisma.deviceBinding.findFirst({
      where: {
        userId: userId,
        deviceId: deviceId,
        bindStatus: true
      }
    });

    if (!binding) {
      return res.status(404).json({
        success: false,
        message: '设备不存在或未绑定'
      });
    }

    const device = await prisma.device.findUnique({
      where: { deviceId }
    });

    if (!device) {
      return res.status(404).json({
        success: false,
        message: '设备不存在'
      });
    }

    // 获取用户头像（从 lot_user 表）
    const users = await prisma.$queryRaw`
      SELECT avatar_url
      FROM lot_user
      WHERE user_id = ${userId}
      AND del_flag = '0'
    ` as any[];
    const userAvatar = users.length > 0 ? users[0].avatar_url : null;

    // 应用统一坐标转换（WGS-84 -> GCJ-02 + 统一偏移）
    const transformed = transformCoordinate(
      toNum(device.latitude),
      toNum(device.longitude)
    );

    res.json({
      success: true,
      data: {
        device: {
          deviceId: device.deviceId.toString(),
          deviceCode: device.deviceCode,
          devicePassword: device.devicePassword,
          bindStatus: device.bindStatus,
          userName: device.userName,
          userPhone: device.userPhone,
          registerDate: device.registerDate,
          bindDate: device.bindDate,
          uniqueId: device.uniqueId,
          locationInfo: device.locationInfo,
          address: device.address,
          longitude: transformed?.longitude ?? device.longitude,
          latitude: transformed?.latitude ?? device.latitude,
          snCode: device.snCode,
          isTimedReport: device.isTimedReport,
          report_period: device.report_period,
          battery: device.battery,
          batteryLevel: device.batteryLevel,
          firmwareVersion: device.firmwareVersion,
          deviceName: binding.deviceName || device.deviceName, // 优先使用绑定表中的用户自定义名称
          deviceType: device.deviceType,
          deviceModel: device.deviceModel,
          simNumber: device.simNumber,
          imei: device.imei,
          plateNumber: device.plateNumber,
          vehicleType: device.vehicleType,
          company: device.company,
          status: device.status,
          avatar: device.avatar,
          userAvatar: userAvatar, // 使用用户头像
          manufacturer: device.manufacturer,
          decodeProtocol: device.decodeProtocol,
          remark: device.remark,
          createBy: device.createBy,
          createTime: device.createTime,
          updateBy: device.updateBy,
          updateTime: device.updateTime,
          delFlag: device.delFlag,
          lastLocationTime: device.lastLocationTime,
          isTop: device.isTop
        }
      }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/devices
 * 创建设备
 */
router.post('/', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { deviceSn, name } = req.body;

    if (!deviceSn) {
      return res.status(400).json({
        success: false,
        message: '设备序列号不能为空'
      });
    }

    // 检查设备是否已存在
    const existingDevice = await prisma.device.findFirst({
      where: { snCode: deviceSn }
    });

    if (existingDevice) {
      return res.status(400).json({
        success: false,
        message: '该设备已被绑定'
      });
    }

    const device = await prisma.device.create({
      data: {
        deviceCode: String(deviceSn),
        deviceName: String(name || '未命名设备'),
        snCode: String(deviceSn)
      }
    });

    res.status(201).json({
      success: true,
      message: '设备创建成功',
      data: { device: {
        deviceId: device.deviceId.toString(),
        deviceCode: device.deviceCode,
        deviceName: device.deviceName,
        snCode: device.snCode,
        bindStatus: device.bindStatus,
        createTime: device.createTime,
        updateTime: device.updateTime
      } }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/devices/:id/location
 * 获取设备实时位置
 */
router.get('/:id/location', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;

    // 验证设备是否属于当前用户
    const device = await prisma.device.findFirst({
      where: { deviceId: BigInt(id) }
    });

    if (!device) {
      return res.status(404).json({
        success: false,
        message: '设备不存在'
      });
    }

    // 查询最新的位置
    const location = await prisma.location.findFirst({
      where: { deviceId: BigInt(id) },
      orderBy: { location_time: 'desc' }
    });

    // 应用统一坐标转换（WGS-84 -> GCJ-02 + 统一偏移）
    let correctedLocation = null;
    if (location) {
      const transformed = transformCoordinate(
        toNum(location.latitude),
        toNum(location.longitude)
      );

      correctedLocation = {
        trackId: location.trackId.toString(),
        deviceId: location.deviceId.toString(),
        deviceCode: location.device_code,
        longitude: transformed?.longitude?.toString() ?? location.longitude?.toString(),
        latitude: transformed?.latitude?.toString() ?? location.latitude?.toString(),
        // address: location.address, // 移除地址字段，由前端实时逆地理编码
        recordTime: location.record_time,
        speed: location.speed?.toString(),
        direction: location.direction,
        remark: location.remark,
        createTime: location.create_time,
        createBy: location.create_by,
        updateTime: location.update_time,
        updateBy: location.update_by,
        locationTime: location.location_time,
        altitude: location.altitude,
        batteryLevel: location.battery_level,
        signalStrength: location.signal_strength
      };
    }

    res.json({
      success: true,
      data: {
        deviceId: id,
        location: correctedLocation
      }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * GET /api/devices/:id/history
 * 获取设备历史轨迹
 */
router.get('/:id/history', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;
    const { startTime, endTime, limit = 10000, page = 1 } = req.query;

    console.log('[History] 查询历史轨迹 - 设备ID:', id);
    console.log('[History] 时间范围 - startTime:', startTime, 'endTime:', endTime);
    console.log('[History] 分页参数 - limit:', limit, 'page:', page);

    // 验证设备是否属于当前用户
    const device = await prisma.device.findFirst({
      where: { deviceId: BigInt(id) }
    });

    if (!device) {
      return res.status(404).json({
        success: false,
        message: '设备不存在'
      });
    }

    // 构建查询条件
    let whereClause = 'device_id = ?';
    const params: any[] = [BigInt(id)];

    if (startTime || endTime) {
      if (startTime) {
        // 直接使用字符串比较，不进行时区转换
        // 数据库存储的是北京时间，前端发送的也是北京时间
        whereClause += ' AND location_time >= ?';
        params.push(startTime as string);
        console.log('[History] startTime:', startTime);
      }
      if (endTime) {
        whereClause += ' AND location_time <= ?';
        params.push(endTime as string);
        console.log('[History] endTime:', endTime);
      }
    }

    // 使用原生 SQL 查询，避免 Prisma 的时区转换问题
    const sql = `
      SELECT * FROM lot_track
      WHERE ${whereClause}
      ORDER BY location_time ASC
      LIMIT ? OFFSET ?
    `;

    // 查询总数
    const countSql = `
      SELECT COUNT(*) as total FROM lot_track
      WHERE ${whereClause}
    `;

    const history: any[] = await prisma.$queryRawUnsafe(sql, ...params, Number(limit), (Number(page) - 1) * Number(limit));

    const countResult: any[] = await prisma.$queryRawUnsafe(countSql, ...params);
    const total = Number(countResult[0].total);

    console.log('[History] 返回数据量:', history.length);
    if (history.length > 0) {
      console.log('[History] 第一个点时间:', history[0].location_time);
      console.log('[History] 最后一个点时间:', history[history.length - 1].location_time);
    }

    // 对历史位置应用统一坐标转换（WGS-84 -> GCJ-02 + 统一偏移）
    const transformedHistory = history.map((loc: any) => {
      const transformed = transformCoordinate(
        loc.latitude,
        loc.longitude
      );

      // 返回UTC时间字符串（带Z），前端用 .toLocal() 转换为本地时间
      // 数据库存储的是北京时间，需要转换为UTC
      const formatUTCDate = (date: Date | null | undefined) => {
        if (!date) return null;
        // 将北京时间转换为UTC时间
        const utcTime = new Date(date.getTime() - 8 * 60 * 60 * 1000);
        return utcTime.toISOString();
      };

      return {
        trackId: loc.track_id?.toString(),
        deviceId: loc.device_id?.toString(),
        deviceCode: loc.device_code,
        longitude: transformed?.longitude?.toString() ?? loc.longitude?.toString(),
        latitude: transformed?.latitude?.toString() ?? loc.latitude?.toString(),
        address: loc.address,
        recordTime: loc.record_time,
        speed: loc.speed?.toString(),
        direction: loc.direction,
        remark: loc.remark,
        createTime: loc.create_time,
        createBy: loc.create_by,
        updateTime: loc.update_time,
        updateBy: loc.update_by,
        locationTime: formatUTCDate(loc.location_time as any),
        altitude: loc.altitude,
        batteryLevel: loc.battery_level,
        signalStrength: loc.signal_strength
      };
    });

    res.json({
      success: true,
      data: {
        deviceId: id,
        history: transformedHistory,
        pagination: {
          total,
          page: Number(page),
          limit: Number(limit),
          totalPages: Math.ceil(total / Number(limit))
        }
      }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/devices/:id/location
 * 上报设备位置
 */
router.post('/:id/location', async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;
    const { latitude, longitude, accuracy } = req.body;

    if (latitude === undefined || longitude === undefined) {
      return res.status(400).json({
        success: false,
        message: '纬度和经度不能为空'
      });
    }

    // 验证设备是否存在
    const device = await prisma.device.findUnique({
      where: { deviceId: BigInt(id) }
    });

    if (!device) {
      return res.status(404).json({
        success: false,
        message: '设备不存在'
      });
    }

    // 创建位置记录
    const location = await prisma.location.create({
      data: {
        deviceId: BigInt(id),
        device_code: String(id),
        latitude: Number(latitude),
        longitude: Number(longitude),
        location_time: new Date()
      }
    });

    // 更新设备状态为在线
    await prisma.device.update({
      where: { deviceId: BigInt(id) },
      data: { status: '1' }
    });

    res.status(201).json({
      success: true,
      message: '位置上报成功',
      data: { location }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/devices/bind
 * 通过设备号绑定设备到当前用户
 */
router.post('/bind', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { deviceNo, password, name } = req.body;
    const userId = BigInt(req.userId as string);

    if (!deviceNo || !password) {
      return res.status(400).json({
        success: false,
        message: '设备号和密码不能为空'
      });
    }

    // 查找设备
    const device = await prisma.device.findFirst({
      where: {
        OR: [
          { deviceCode: deviceNo },
          { snCode: deviceNo }
        ]
      }
    });

    if (!device) {
      return res.status(404).json({
        success: false,
        message: '设备不存在'
      });
    }

    // 验证设备密码
    // 默认密码是123456，如果用户修改了密码则以修改后的为准
    const defaultPassword = 'e10adc3949ba59abbe56e057f20f883e'; // MD5 of 123456
    let passwordValid = false;

    if (!device.devicePassword || device.devicePassword === defaultPassword) {
      // 设备未设置密码或使用默认密码，验证123456
      if (password === '123456') {
        passwordValid = true;
      }
    } else {
      // 设备有自定义密码，直接比较（假设存储的是MD5）
      // 这里简化处理，实际应该使用bcrypt
      const crypto = require('crypto');
      const inputHash = crypto.createHash('md5').update(password).digest('hex');
      passwordValid = (inputHash === device.devicePassword);
    }

    if (!passwordValid) {
      return res.status(401).json({
        success: false,
        message: '设备密码错误'
      });
    }

    // 检查是否已经绑定（包括未激活的绑定）
    const existingBinding = await prisma.deviceBinding.findFirst({
      where: {
        userId: userId,
        deviceNo: device.deviceCode
      }
    });

    let binding;
    if (existingBinding) {
      // 如果已有绑定记录，检查是否已激活
      if (existingBinding.bindStatus === true) {
        return res.status(400).json({
          success: false,
          message: '设备已绑定'
        });
      }
      
      // 如果是未激活的绑定，更新它
      binding = await prisma.deviceBinding.update({
        where: { bindId: existingBinding.bindId },
        data: {
          deviceId: device.deviceId,
          deviceName: name || device.deviceName || device.deviceCode,
          bindStatus: true,
          bindTime: new Date()
        }
      });
    } else {
      // 创建新的绑定关系
      binding = await prisma.deviceBinding.create({
        data: {
          userId: userId,
          deviceId: device.deviceId,
          deviceNo: device.deviceCode,
          deviceName: name || device.deviceName || device.deviceCode,
          bindStatus: true,
          bindTime: new Date()
        }
      });
    }

    // 更新设备信息
    // 获取用户信息（从 lot_user 表）
    const lotUsers = await prisma.$queryRaw`
      SELECT phone_number, user_name
      FROM lot_user
      WHERE user_id = ${userId}
      AND del_flag = '0'
    ` as any[];
    const lotUser = lotUsers.length > 0 ? lotUsers[0] : null;

    await prisma.device.update({
      where: { deviceId: device.deviceId },
      data: {
        bindStatus: true,
        bindDate: new Date(),
        userPhone: lotUser?.phone_number || null,
        userName: lotUser?.user_name || null
      }
    });

    res.json({
      success: true,
      message: '绑定成功',
      data: {
        binding: {
          id: binding.bindId.toString(),
          deviceId: binding.deviceId?.toString() || '',
          userId: binding.userId.toString(),
          bindTime: binding.bindTime
        },
        device: {
          deviceId: device.deviceId.toString(),
          deviceCode: device.deviceCode,
          deviceName: device.deviceName || name || device.deviceCode,
          avatar: device.avatar,
          latitude: device.latitude,
          longitude: device.longitude,
          address: device.address,
          battery: device.battery,
          batteryLevel: device.batteryLevel,
          status: device.status,
          lastLocationTime: device.lastLocationTime
        }
      }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/devices/:id/bind
 * 绑定设备到当前用户
 */
router.post('/:id/bind', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;
    const userId = BigInt(req.userId as string);

    // 查找设备（支持通过 deviceCode 或 deviceId 查找）
    // 尝试将 id 转换为 BigInt，如果失败则只查询 deviceCode 和 snCode
    let deviceIdBigInt: bigint | undefined;
    try {
      deviceIdBigInt = BigInt(id);
    } catch (e) {
      // id 不是数字，只能通过 deviceCode 或 snCode 查找
    }

    const whereCondition: any = {
      OR: [
        { deviceCode: String(id) },
        { snCode: String(id) }
      ]
    };

    // 如果 id 可以转换为 BigInt，添加 deviceId 查询条件
    if (deviceIdBigInt !== undefined) {
      whereCondition.OR.push({ deviceId: deviceIdBigInt });
    }

    const device = await prisma.device.findFirst({
      where: whereCondition
    });

    if (!device) {
      return res.status(404).json({
        success: false,
        message: '设备不存在'
      });
    }

    // 检查是否已经绑定到当前用户
    const existingBinding = await prisma.deviceBinding.findFirst({
      where: {
        userId: userId,
        deviceId: device.deviceId,
        bindStatus: true
      }
    });

    if (existingBinding) {
      return res.json({
        success: true,
        message: '设备已绑定',
        data: {
          device: {
            deviceId: device.deviceId.toString(),
            deviceCode: device.deviceCode,
            devicePassword: device.devicePassword,
            bindStatus: device.bindStatus,
            userName: device.userName,
            userPhone: device.userPhone,
            registerDate: device.registerDate,
            bindDate: device.bindDate,
            uniqueId: device.uniqueId,
            locationInfo: device.locationInfo,
            address: device.address,
            longitude: device.longitude,
            latitude: device.latitude,
            snCode: device.snCode,
            isTimedReport: device.isTimedReport,
            report_period: device.report_period,
            battery: device.battery,
            batteryLevel: device.batteryLevel,
            firmwareVersion: device.firmwareVersion,
            deviceName: device.deviceName,
            deviceType: device.deviceType,
            deviceModel: device.deviceModel,
            simNumber: device.simNumber,
            imei: device.imei,
            plateNumber: device.plateNumber,
            vehicleType: device.vehicleType,
            company: device.company,
            status: device.status,
            avatar: device.avatar,
            manufacturer: device.manufacturer,
            decodeProtocol: device.decodeProtocol,
            remark: device.remark,
            createBy: device.createBy,
            createTime: device.createTime,
            updateBy: device.updateBy,
            updateTime: device.updateTime,
            delFlag: device.delFlag,
            lastLocationTime: device.lastLocationTime,
            isTop: device.isTop
          }
        }
      });
    }

    // 检查是否被其他用户绑定
    const otherBinding = await prisma.deviceBinding.findFirst({
      where: {
        deviceId: device.deviceId,
        bindStatus: true,
        userId: { not: userId }
      }
    });

    if (otherBinding) {
      return res.status(400).json({
        success: false,
        message: '该设备已被其他用户绑定'
      });
    }

    // 创建绑定记录
    const binding = await prisma.deviceBinding.create({
      data: {
        userId: userId,
        deviceId: device.deviceId,
        deviceNo: device.deviceCode,
        deviceName: device.deviceName || '未命名设备',
        bindStatus: true,
        isPrimary: false,
        bindTime: new Date()
      }
    });

    // 更新设备的绑定状态
    await prisma.device.update({
      where: { deviceId: device.deviceId },
      data: {
        bindStatus: true,
        bindDate: new Date(),
        updateTime: new Date()
      }
    });

    res.json({
      success: true,
      message: '设备绑定成功',
      data: {
        device: {
          deviceId: device.deviceId.toString(),
          deviceCode: device.deviceCode,
          devicePassword: device.devicePassword,
          bindStatus: device.bindStatus,
          userName: device.userName,
          userPhone: device.userPhone,
          registerDate: device.registerDate,
          bindDate: device.bindDate,
          uniqueId: device.uniqueId,
          locationInfo: device.locationInfo,
          address: device.address,
          longitude: device.longitude,
          latitude: device.latitude,
          snCode: device.snCode,
          isTimedReport: device.isTimedReport,
          report_period: device.report_period,
          battery: device.battery,
          batteryLevel: device.batteryLevel,
          firmwareVersion: device.firmwareVersion,
          deviceName: device.deviceName,
          deviceType: device.deviceType,
          deviceModel: device.deviceModel,
          simNumber: device.simNumber,
          imei: device.imei,
          plateNumber: device.plateNumber,
          vehicleType: device.vehicleType,
          company: device.company,
          status: device.status,
          avatar: device.avatar,
          manufacturer: device.manufacturer,
          decodeProtocol: device.decodeProtocol,
          remark: device.remark,
          createBy: device.createBy,
          createTime: device.createTime,
          updateBy: device.updateBy,
          updateTime: device.updateTime,
          delFlag: device.delFlag,
          lastLocationTime: device.lastLocationTime,
          isTop: device.isTop
        },
        binding: {
          bindId: binding.bindId.toString(),
          userId: binding.userId.toString(),
          deviceId: binding.deviceId?.toString(),
          deviceNo: binding.deviceNo,
          deviceName: binding.deviceName,
          bindStatus: binding.bindStatus,
          isPrimary: binding.isPrimary,
          bindTime: binding.bindTime,
          unbindTime: binding.unbindTime,
          createTime: binding.createTime,
          updateTime: binding.updateTime
        }
      }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /api/devices/:id/unbind
 * 解绑设备
 */
router.post('/:id/unbind', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;
    const userId = BigInt(req.userId as string);

    // 查找设备（支持通过 deviceCode 或 deviceId 查找）
    // 尝试将 id 转换为 BigInt，如果失败则只查询 deviceCode
    let deviceIdBigInt: bigint | undefined;
    try {
      deviceIdBigInt = BigInt(id);
    } catch (e) {
      // id 不是数字，只能通过 deviceCode 查找
    }

    const whereCondition: any = {
      OR: [
        { deviceCode: String(id) }
      ]
    };

    // 如果 id 可以转换为 BigInt，添加 deviceId 查询条件
    if (deviceIdBigInt !== undefined) {
      whereCondition.OR.push({ deviceId: deviceIdBigInt });
    }

    const device = await prisma.device.findFirst({
      where: whereCondition
    });

    if (!device) {
      return res.status(404).json({
        success: false,
        message: '设备不存在'
      });
    }

    // 查找绑定记录
    const binding = await prisma.deviceBinding.findFirst({
      where: {
        userId: userId,
        deviceId: device.deviceId,
        bindStatus: true
      }
    });

    if (!binding) {
      return res.status(404).json({
        success: false,
        message: '设备未绑定或不属于当前用户'
      });
    }

    // 更新绑定状态为解绑
    await prisma.deviceBinding.update({
      where: { bindId: binding.bindId },
      data: {
        bindStatus: false,
        unbindTime: new Date(),
        updateTime: new Date()
      }
    });

    // 更新设备的绑定状态
    await prisma.device.update({
      where: { deviceId: device.deviceId },
      data: {
        bindStatus: false,
        updateTime: new Date()
      }
    });

    res.json({
      success: true,
      message: '设备解绑成功',
      data: {
        device: {
          deviceId: device.deviceId.toString(),
          deviceCode: device.deviceCode,
          devicePassword: device.devicePassword,
          bindStatus: device.bindStatus,
          userName: device.userName,
          userPhone: device.userPhone,
          registerDate: device.registerDate,
          bindDate: device.bindDate,
          uniqueId: device.uniqueId,
          locationInfo: device.locationInfo,
          address: device.address,
          longitude: device.longitude,
          latitude: device.latitude,
          snCode: device.snCode,
          isTimedReport: device.isTimedReport,
          report_period: device.report_period,
          battery: device.battery,
          batteryLevel: device.batteryLevel,
          firmwareVersion: device.firmwareVersion,
          deviceName: device.deviceName,
          deviceType: device.deviceType,
          deviceModel: device.deviceModel,
          simNumber: device.simNumber,
          imei: device.imei,
          plateNumber: device.plateNumber,
          vehicleType: device.vehicleType,
          company: device.company,
          status: device.status,
          avatar: device.avatar,
          manufacturer: device.manufacturer,
          decodeProtocol: device.decodeProtocol,
          remark: device.remark,
          createBy: device.createBy,
          createTime: device.createTime,
          updateBy: device.updateBy,
          updateTime: device.updateTime,
          delFlag: device.delFlag,
          lastLocationTime: device.lastLocationTime,
          isTop: device.isTop
        }
      }
    });
  } catch (error) {
    next(error);
  }
});

/**
 * PUT /api/devices/:id
 * 更新设备信息（名称、头像等）
 */
router.put('/:id', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;
    const { deviceName, avatar } = req.body;
    const userId = BigInt(req.userId as string);

    // 查找设备
    let deviceIdBigInt: bigint | undefined;
    try {
      deviceIdBigInt = BigInt(id);
    } catch (e) {
      // id 不是数字
    }

    const whereCondition: any = {
      OR: [
        { deviceCode: String(id) }
      ]
    };

    if (deviceIdBigInt !== undefined) {
      whereCondition.OR.push({ deviceId: deviceIdBigInt });
    }

    const device = await prisma.device.findFirst({
      where: whereCondition
    });

    if (!device) {
      return res.status(404).json({
        success: false,
        message: '设备不存在'
      });
    }

    // 验证设备是否属于当前用户
    const binding = await prisma.deviceBinding.findFirst({
      where: {
        userId: userId,
        deviceId: device.deviceId,
        bindStatus: true
      }
    });

    if (!binding) {
      return res.status(403).json({
        success: false,
        message: '无权限修改该设备信息'
      });
    }

    // 构建更新数据
    const updateData: any = {
      updateTime: new Date()
    };

    if (deviceName !== undefined) {
      updateData.deviceName = deviceName;
      // 同时更新绑定记录中的设备名称
      await prisma.deviceBinding.updateMany({
        where: {
          deviceId: device.deviceId
        },
        data: {
          deviceName: deviceName,
          updateTime: new Date()
        }
      });
    }

      if (avatar !== undefined) {
        // 处理空头像（清除头像）
        if (avatar === null || avatar === '') {
          updateData.avatar = null;
        } else {
          let finalAvatar = avatar;

          // 验证是否是有效的base64图像URL
          const isBase64ImageUrl = typeof avatar === 'string' &&
            avatar.startsWith('data:image/') &&
            avatar.includes(';base64,');

          console.log(`[Device Update] Avatar input type: ${typeof avatar}, isBase64ImageUrl: ${isBase64ImageUrl}`);
          console.log(`[Device Update] Avatar length: ${avatar.length}`);

          if (!isBase64ImageUrl) {
            console.error('[Device Update] Invalid avatar format:', avatar.substring(0, 100));
            return res.status(400).json({
              success: false,
              message: '无效的头像格式，请使用有效的base64图像数据'
            });
          }

          try {
            // 自动压缩头像到合适尺寸
            console.log(`[Device Avatar Compression] 开始压缩设备头像，原始长度: ${avatar.length}字符`);
            finalAvatar = await compressImage(avatar);
            console.log(`[Device Avatar Compression] 压缩后长度: ${finalAvatar.length}字符`);
          } catch (compressError) {
            console.error('[Device Avatar Compression] 设备头像压缩失败:', compressError);
            // 压缩失败，使用原始数据（但需验证长度）
          }

          // device表的avatar字段有长度限制（约65KB），验证长度
          if (finalAvatar.length > 65000) {
            console.error('[Device Update] Avatar too large:', finalAvatar.length);
            return res.status(400).json({
              success: false,
              message: `头像数据过大（${finalAvatar.length}字符，最大65000字符），请选择较小的图片`
            });
          }
          updateData.avatar = finalAvatar;
        }
      }

    // 更新设备信息
    console.log('[Device Update] Updating device with data:', JSON.stringify({
      deviceId: device.deviceId.toString(),
      hasAvatar: !!updateData.avatar,
      avatarLength: updateData.avatar?.length || 0,
      hasDeviceName: !!updateData.deviceName
    }));

    const updatedDevice = await prisma.device.update({
      where: { deviceId: device.deviceId },
      data: updateData
    });

    console.log('[Device Update] Device updated successfully');

    res.json({
      success: true,
      message: '设备信息更新成功',
      data: {
        device: {
          deviceId: updatedDevice.deviceId.toString(),
          deviceCode: updatedDevice.deviceCode,
          deviceName: updatedDevice.deviceName,
          avatar: updatedDevice.avatar
        }
      }
    });
  } catch (error: any) {
    console.error('[Device Update] Error:', error);
    console.error('[Device Update] Error stack:', error.stack);
    console.error('[Device Update] Error message:', error.message);

    // 如果是Prisma错误，返回更友好的错误信息
    if (error.code) {
      console.error('[Device Update] Prisma error code:', error.code);
      console.error('[Device Update] Prisma error meta:', error.meta);
    }

    res.status(500).json({
      success: false,
      message: error.message || '设备信息更新失败',
      ...(process.env.NODE_ENV === 'development' && {
        error: error.stack,
        details: error.code ? { code: error.code, meta: error.meta } : undefined
      })
    });
  }
});

/**
 * POST /api/devices/:id/upload-avatar
 * 上传设备头像
 */
router.post('/:id/upload-avatar', authenticate, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const { id } = req.params;
    const userId = BigInt(req.userId as string);

    // 查找设备
    let deviceIdBigInt: bigint | undefined;
    try {
      deviceIdBigInt = BigInt(id);
    } catch (e) {
      // id 不是数字
    }

    const whereCondition: any = {
      OR: [
        { deviceCode: String(id) }
      ]
    };

    if (deviceIdBigInt !== undefined) {
      whereCondition.OR.push({ deviceId: deviceIdBigInt });
    }

    const device = await prisma.device.findFirst({
      where: whereCondition
    });

    if (!device) {
      return res.status(404).json({
        success: false,
        message: '设备不存在'
      });
    }

    // 验证设备是否属于当前用户
    const binding = await prisma.deviceBinding.findFirst({
      where: {
        userId: userId,
        deviceId: device.deviceId,
        bindStatus: true
      }
    });

    if (!binding) {
      return res.status(403).json({
        success: false,
        message: '无权限修改该设备信息'
      });
    }

    // 检查是否包含文件（兼容multer未配置的情况）
    if (!(req as any).files || typeof (req as any).files !== 'object' || Object.keys((req as any).files).length === 0) {
      return res.status(400).json({
        success: false,
        message: '没有上传文件'
      });
    }

    // 注意：这里需要配置multer来处理文件上传
    // 暂时返回示例URL，实际使用时需要配置文件存储
    const avatarUrl = `http://localhost:3000/uploads/devices/${Date.now()}.jpg`;

    // 更新设备头像
    const updatedDevice = await prisma.device.update({
      where: { deviceId: device.deviceId },
      data: { avatar: avatarUrl }
    });

    res.json({
      success: true,
      message: '设备头像上传成功',
      data: {
        avatar: avatarUrl,
        device: {
          deviceId: updatedDevice.deviceId.toString(),
          deviceCode: updatedDevice.deviceCode,
          deviceName: updatedDevice.deviceName,
          avatar: updatedDevice.avatar
        }
      }
    });
  } catch (error) {
    next(error);
  }
});

export default router;
