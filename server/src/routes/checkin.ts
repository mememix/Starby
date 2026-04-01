import { Router, Request, Response, NextFunction } from 'express';
import prisma from '../lib/prisma';

// 扩展 Request 类型以添加 userId 属性
declare module 'express' {
  interface Request {
    userId?: string;
  }
}

const router = Router();

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
    const jwt = require('jsonwebtoken');
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

/**
 * 计算打卡应得的积分
 * 连续1-3天：每天1分
 * 连续4-5天：每天2分
 * 连续6-9天：每天3分
 * 连续10天及以上：每天5分
 */
function calculatePoints(continuousDays: number): number {
  if (continuousDays < 4) {
    // 连续1-3天
    return 1;
  } else if (continuousDays < 6) {
    // 连续4-5天
    return 2;
  } else if (continuousDays < 10) {
    // 连续6-9天
    return 3;
  } else {
    // 连续10天及以上
    return 5;
  }
}

/**
 * POST /api/checkin
 * 用户打卡
 */
router.post('/', authenticateToken, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = BigInt(req.userId as string);
    const { latitude, longitude, address, device_code } = req.body;

    // 获取今天的日期（不考虑时分秒）
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    // 检查今天是否已经打卡
    const todayCheckin = await prisma.$queryRaw`
      SELECT checkin_id, continuous_days
      FROM lot_checkin
      WHERE user_id = ${userId}
      AND DATE(checkin_time) = CURDATE()
      LIMIT 1
    ` as any[];

    if (todayCheckin && todayCheckin.length > 0) {
      return res.status(400).json({
        success: false,
        message: '今天已经打卡了',
        data: {
          checkedIn: true,
          checkinId: todayCheckin[0].checkin_id
        }
      });
    }

    // 查找最后一次打卡记录，计算连续打卡天数
    const lastCheckin = await prisma.$queryRaw`
      SELECT checkin_time, continuous_days
      FROM lot_checkin
      WHERE user_id = ${userId}
      ORDER BY checkin_time DESC
      LIMIT 1
    ` as any[];

    let continuousDays = 1; // 默认第一天

    if (lastCheckin && lastCheckin.length > 0) {
      // 使用 SQL 的 DATEDIFF 函数计算天数差（基于数据库服务器的本地时区）
      const dayDiffResult = await prisma.$queryRaw`
        SELECT
          DATEDIFF(CURDATE(), DATE(checkin_time)) as day_diff
        FROM lot_checkin
        WHERE user_id = ${userId}
        ORDER BY checkin_time DESC
        LIMIT 1
      ` as any[];

      const dayDiff = Number(dayDiffResult[0]?.day_diff || 0);

      if (dayDiff === 1) {
        // 昨天打卡了，连续天数+1
        continuousDays = (lastCheckin[0].continuous_days || 0) + 1;
      } else if (dayDiff > 1) {
        // 中断了，从1开始计算
        continuousDays = 1;
      } else {
        // dayDiff === 0，今天已经打卡了（上面已经检查过）
        continuousDays = 1;
      }
    }

    // 计算本次打卡获得的积分
    const pointsEarned = calculatePoints(continuousDays);

    // 插入打卡记录
    const checkin = await prisma.$queryRaw`
      INSERT INTO lot_checkin
        (user_id, checkin_time, checkin_type, longitude, latitude, continuous_days, points, like_count, device_code, address, create_time, update_time)
      VALUES
        (${userId}, NOW(), 'DAILY', ${longitude || null}, ${latitude || null}, ${continuousDays}, ${pointsEarned}, 0, ${device_code || null}, ${address || null}, NOW(), NOW())
    ` as any[];

    const checkinId = (checkin as any).insertId;

    // 更新或创建用户积分记录
    let userPoints = await prisma.$queryRaw`
      SELECT points_id, total_points, available_points
      FROM lot_user_points
      WHERE user_id = ${userId}
      LIMIT 1
    ` as any[];

    let newTotalPoints = 0;
    let newAvailablePoints = 0;

    if (userPoints && userPoints.length > 0) {
      newTotalPoints = Number(userPoints[0].total_points || 0) + pointsEarned;
      newAvailablePoints = Number(userPoints[0].available_points || 0) + pointsEarned;

      // 更新用户积分
      await prisma.$queryRaw`
        UPDATE lot_user_points
        SET total_points = ${newTotalPoints},
            available_points = ${newAvailablePoints},
            update_time = NOW()
        WHERE user_id = ${userId}
      `;
    } else {
      newTotalPoints = pointsEarned;
      newAvailablePoints = pointsEarned;

      // 创建用户积分记录
      await prisma.$queryRaw`
        INSERT INTO lot_user_points
          (user_id, total_points, available_points, used_points, create_time, update_time)
        VALUES
          (${userId}, ${newTotalPoints}, ${newAvailablePoints}, 0, NOW(), NOW())
      `;
    }

    // 记录积分变动
    await prisma.$queryRaw`
      INSERT INTO lot_points_record
        (user_id, points, record_type, description, related_id, create_time)
      VALUES
        (${userId}, ${pointsEarned}, 'CHECKIN', '打卡奖励', ${checkinId}, NOW())
    `;

    // 更新或创建打卡统计（按年月）
    const now = new Date();
    const currentYear = now.getFullYear();
    const currentMonth = now.getMonth() + 1; // 月份从1开始

    let stats = await prisma.$queryRaw`
      SELECT stats_id, total_days, continuous_days, last_checkin_date
      FROM lot_checkin_stats
      WHERE user_id = ${userId}
      AND stats_year = ${currentYear}
      AND stats_month = ${currentMonth}
      LIMIT 1
    ` as any[];

    if (stats && stats.length > 0) {
      // 更新统计
      const currentTotalDays = Number(stats[0].total_days || 0) + 1;
      const currentContinuousDays = continuousDays;

      await prisma.$queryRaw`
        UPDATE lot_checkin_stats
        SET total_days = ${currentTotalDays},
            continuous_days = ${currentContinuousDays},
            last_checkin_date = CURDATE(),
            update_time = NOW()
        WHERE stats_id = ${stats[0].stats_id}
      `;
    } else {
      // 创建统计
      await prisma.$queryRaw`
        INSERT INTO lot_checkin_stats
          (user_id, stats_year, stats_month, total_days, continuous_days, last_checkin_date, create_time, update_time)
        VALUES
          (${userId}, ${currentYear}, ${currentMonth}, 1, ${continuousDays}, CURDATE(), NOW(), NOW())
      `;
    }

    res.json({
      success: true,
      message: '打卡成功',
      data: {
        checkinId,
        continuousDays,
        pointsEarned,
        totalPoints: newTotalPoints,
        availablePoints: newAvailablePoints,
        checkinTime: new Date().toISOString()
      }
    });
  } catch (error) {
    console.error('[Checkin] 打卡失败:', error);
    next(error);
  }
});

/**
 * GET /api/checkin/status
 * 获取今日打卡状态
 */
router.get('/status', authenticateToken, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = BigInt(req.userId as string);

    // 查询今日打卡记录
    const todayCheckin = await prisma.$queryRaw`
      SELECT checkin_id, checkin_time, continuous_days, points
      FROM lot_checkin
      WHERE user_id = ${userId}
      AND DATE(checkin_time) = CURDATE()
      ORDER BY checkin_time DESC
      LIMIT 1
    ` as any[];

    const hasCheckedIn = todayCheckin && todayCheckin.length > 0;

    // 获取连续打卡天数
    let continuousDays = 0;
    let lastCheckinTime = null;
    let pointsEarned = 0;

    if (hasCheckedIn) {
      continuousDays = Number(todayCheckin[0].continuous_days || 0);
      lastCheckinTime = todayCheckin[0].checkin_time;
      pointsEarned = Number(todayCheckin[0].points || calculatePoints(continuousDays));
    } else {
      // 查找最后一次打卡记录
      const lastCheckin = await prisma.$queryRaw`
        SELECT checkin_time, continuous_days
        FROM lot_checkin
        WHERE user_id = ${userId}
        ORDER BY checkin_time DESC
        LIMIT 1
      ` as any[];

      if (lastCheckin && lastCheckin.length > 0) {
        // 使用 SQL 的 DATEDIFF 函数计算天数差（基于数据库服务器的本地时区）
        const dayDiffResult = await prisma.$queryRaw`
          SELECT
            DATEDIFF(CURDATE(), DATE(checkin_time)) as day_diff
          FROM lot_checkin
          WHERE user_id = ${userId}
          ORDER BY checkin_time DESC
          LIMIT 1
        ` as any[];

        const dayDiff = Number(dayDiffResult[0]?.day_diff || 0);

        if (dayDiff === 1) {
          continuousDays = Number(lastCheckin[0].continuous_days || 0);
        } else {
          continuousDays = 0;
        }
      }
    }

    // 获取用户总积分
    const userPoints = await prisma.$queryRaw`
      SELECT total_points, available_points
      FROM lot_user_points
      WHERE user_id = ${userId}
      LIMIT 1
    ` as any[];

    const totalPoints = userPoints && userPoints.length > 0
      ? Number(userPoints[0].total_points || 0)
      : 0;
    const availablePoints = userPoints && userPoints.length > 0
      ? Number(userPoints[0].available_points || 0)
      : 0;

    // 获取本月打卡天数
    const now = new Date();
    const currentYear = now.getFullYear();
    const currentMonth = now.getMonth() + 1;

    const monthlyStats = await prisma.$queryRaw`
      SELECT total_days
      FROM lot_checkin_stats
      WHERE user_id = ${userId}
      AND stats_year = ${currentYear}
      AND stats_month = ${currentMonth}
      LIMIT 1
    ` as any[];

    const monthlyDays = monthlyStats && monthlyStats.length > 0
      ? Number(monthlyStats[0].total_days || 0)
      : 0;

    // 计算如果打卡能获得的积分
    // 如果今天已打卡,显示下次打卡(明天)的积分;如果未打卡,显示本次打卡的积分
    const potentialPoints = calculatePoints(hasCheckedIn ? continuousDays + 1 : continuousDays + 1);

    res.json({
      success: true,
      data: {
        hasCheckedIn,
        continuousDays,
        lastCheckinTime,
        pointsEarned,
        potentialPoints,
        totalPoints,
        availablePoints,
        monthlyDays
      }
    });
  } catch (error) {
    console.error('[Checkin] 获取打卡状态失败:', error);
    next(error);
  }
});

/**
 * GET /api/checkin/history
 * 获取打卡历史记录
 */
router.get('/history', authenticateToken, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = BigInt(req.userId as string);
    const page = parseInt(req.query.page as string) || 1;
    const limit = parseInt(req.query.limit as string) || 20;
    const offset = (page - 1) * limit;

    const checkins = await prisma.$queryRaw`
      SELECT
        checkin_id,
        checkin_time,
        checkin_type,
        longitude,
        latitude,
        continuous_days,
        like_count,
        address,
        device_code
      FROM lot_checkin
      WHERE user_id = ${userId}
      ORDER BY checkin_time DESC
      LIMIT ${limit}
      OFFSET ${offset}
    ` as any[];

    // 获取总数
    const countResult = await prisma.$queryRaw`
      SELECT COUNT(*) as total
      FROM lot_checkin
      WHERE user_id = ${userId}
    ` as any[];

    const total = Number(countResult[0]?.total || 0);

    res.json({
      success: true,
      data: {
        checkins: checkins.map((c: any) => ({
          id: c.checkin_id.toString(),
          checkinTime: c.checkin_time,
          checkinType: c.checkin_type,
          longitude: c.longitude ? c.longitude.toString() : null,
          latitude: c.latitude ? c.latitude.toString() : null,
          continuousDays: Number(c.continuous_days || 0),
          likeCount: Number(c.like_count || 0),
          address: c.address,
          deviceCode: c.device_code
        })),
        pagination: {
          page,
          limit,
          total,
          totalPages: Math.ceil(total / limit)
        }
      }
    });
  } catch (error) {
    console.error('[Checkin] 获取打卡历史失败:', error);
    next(error);
  }
});

/**
 * GET /api/checkin/points
 * 获取积分记录
 */
router.get('/points', authenticateToken, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = BigInt(req.userId as string);
    const page = parseInt(req.query.page as string) || 1;
    const limit = parseInt(req.query.limit as string) || 20;
    const offset = (page - 1) * limit;

    const records = await prisma.$queryRaw`
      SELECT
        record_id,
        user_id,
        points,
        record_type,
        description,
        related_id,
        create_time
      FROM lot_points_record
      WHERE user_id = ${userId}
      ORDER BY create_time DESC
      LIMIT ${limit}
      OFFSET ${offset}
    ` as any[];

    // 获取总数
    const countResult = await prisma.$queryRaw`
      SELECT COUNT(*) as total
      FROM lot_points_record
      WHERE user_id = ${userId}
    ` as any[];

    const total = Number(countResult[0]?.total || 0);

    res.json({
      success: true,
      data: {
        records: records.map((r: any) => ({
          id: r.record_id.toString(),
          points: Number(r.points || 0),
          recordType: r.record_type,
          description: r.description,
          relatedId: r.related_id ? r.related_id.toString() : null,
          createTime: r.create_time
        })),
        pagination: {
          page,
          limit,
          total,
          totalPages: Math.ceil(total / limit)
        }
      }
    });
  } catch (error) {
    console.error('[Checkin] 获取积分记录失败:', error);
    next(error);
  }
});

/**
 * GET /api/checkin/stats
 * 获取打卡统计
 */
router.get('/stats', authenticateToken, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = BigInt(req.userId as string);

    // 获取总打卡天数
    const totalCheckins = await prisma.$queryRaw`
      SELECT COUNT(*) as total
      FROM lot_checkin
      WHERE user_id = ${userId}
    ` as any[];

    const totalDays = Number(totalCheckins[0]?.total || 0);

    // 获取本月打卡天数
    const now = new Date();
    const currentYear = now.getFullYear();
    const currentMonth = now.getMonth() + 1;

    const monthlyStats = await prisma.$queryRaw`
      SELECT total_days, continuous_days, last_checkin_date
      FROM lot_checkin_stats
      WHERE user_id = ${userId}
      AND stats_year = ${currentYear}
      AND stats_month = ${currentMonth}
      LIMIT 1
    ` as any[];

    const monthlyDays = monthlyStats && monthlyStats.length > 0
      ? Number(monthlyStats[0].total_days || 0)
      : 0;
    const currentContinuousDays = monthlyStats && monthlyStats.length > 0
      ? Number(monthlyStats[0].continuous_days || 0)
      : 0;

    // 获取用户积分
    const userPoints = await prisma.$queryRaw`
      SELECT total_points, available_points, used_points
      FROM lot_user_points
      WHERE user_id = ${userId}
      LIMIT 1
    ` as any[];

    const totalPoints = userPoints && userPoints.length > 0
      ? Number(userPoints[0].total_points || 0)
      : 0;
    const availablePoints = userPoints && userPoints.length > 0
      ? Number(userPoints[0].available_points || 0)
      : 0;
    const usedPoints = userPoints && userPoints.length > 0
      ? Number(userPoints[0].used_points || 0)
      : 0;

    // 获取最近7天的打卡情况，同时标记是否打卡
    const weekDataQuery = await prisma.$queryRaw`
      SELECT
        DATE_SUB(CURDATE(), INTERVAL ${0} DAY) as date,
        COUNT(*) as checkedIn_count,
        MAX(continuous_days) as continuous_days
      FROM lot_checkin
      WHERE user_id = ${userId}
      AND DATE(checkin_time) = DATE_SUB(CURDATE(), INTERVAL ${0} DAY)
      UNION ALL
      SELECT
        DATE_SUB(CURDATE(), INTERVAL ${1} DAY) as date,
        COUNT(*) as checkedIn_count,
        MAX(continuous_days) as continuous_days
      FROM lot_checkin
      WHERE user_id = ${userId}
      AND DATE(checkin_time) = DATE_SUB(CURDATE(), INTERVAL ${1} DAY)
      UNION ALL
      SELECT
        DATE_SUB(CURDATE(), INTERVAL ${2} DAY) as date,
        COUNT(*) as checkedIn_count,
        MAX(continuous_days) as continuous_days
      FROM lot_checkin
      WHERE user_id = ${userId}
      AND DATE(checkin_time) = DATE_SUB(CURDATE(), INTERVAL ${2} DAY)
      UNION ALL
      SELECT
        DATE_SUB(CURDATE(), INTERVAL ${3} DAY) as date,
        COUNT(*) as checkedIn_count,
        MAX(continuous_days) as continuous_days
      FROM lot_checkin
      WHERE user_id = ${userId}
      AND DATE(checkin_time) = DATE_SUB(CURDATE(), INTERVAL ${3} DAY)
      UNION ALL
      SELECT
        DATE_SUB(CURDATE(), INTERVAL ${4} DAY) as date,
        COUNT(*) as checkedIn_count,
        MAX(continuous_days) as continuous_days
      FROM lot_checkin
      WHERE user_id = ${userId}
      AND DATE(checkin_time) = DATE_SUB(CURDATE(), INTERVAL ${4} DAY)
      UNION ALL
      SELECT
        DATE_SUB(CURDATE(), INTERVAL ${5} DAY) as date,
        COUNT(*) as checkedIn_count,
        MAX(continuous_days) as continuous_days
      FROM lot_checkin
      WHERE user_id = ${userId}
      AND DATE(checkin_time) = DATE_SUB(CURDATE(), INTERVAL ${5} DAY)
      UNION ALL
      SELECT
        DATE_SUB(CURDATE(), INTERVAL ${6} DAY) as date,
        COUNT(*) as checkedIn_count,
        MAX(continuous_days) as continuous_days
      FROM lot_checkin
      WHERE user_id = ${userId}
      AND DATE(checkin_time) = DATE_SUB(CURDATE(), INTERVAL ${6} DAY)
    ` as any[];

    const weekData = weekDataQuery.map((item: any) => {
      // 格式化日期为 yyyy-MM-dd 字符串
      const dateObj = new Date(item.date);
      const year = dateObj.getFullYear();
      const month = String(dateObj.getMonth() + 1).padStart(2, '0');
      const day = String(dateObj.getDate()).padStart(2, '0');
      const dateStr = `${year}-${month}-${day}`;

      return {
        date: dateStr,
        checkedIn: (item.checkedIn_count || 0) > 0,
        continuousDays: Number(item.continuous_days || 0)
      };
    });

    res.json({
      success: true,
      data: {
        totalDays,
        monthlyDays,
        continuousDays: currentContinuousDays,
        totalPoints,
        availablePoints,
        usedPoints,
        weekData // 已按日期倒序（今天在前）
      }
    });
  } catch (error) {
    console.error('[Checkin] 获取打卡统计失败:', error);
    next(error);
  }
});

export default router;
