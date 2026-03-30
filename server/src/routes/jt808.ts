/**
 * JT808 API 路由
 */

import express from 'express';
import { JT808Storage } from '../jt808';

const router = express.Router();

/**
 * 获取JT808服务器状态
 */
router.get('/status', (req, res) => {
  res.json({
    status: 'ok',
    service: 'JT808',
    timestamp: new Date().toISOString(),
  });
});

/**
 * 获取设备最新位置
 */
router.get('/location/:phoneNumber', async (req, res) => {
  try {
    const { phoneNumber } = req.params;
    const location = await JT808Storage.getLatestLocation(phoneNumber);

    if (!location) {
      return res.status(404).json({ message: '位置信息不存在' });
    }

    res.json({
      success: true,
      data: location,
    });
  } catch (error) {
    console.error('[JT808 API] Get location error:', error);
    res.status(500).json({ message: '获取位置信息失败' });
  }
});

/**
 * 获取设备历史轨迹
 */
router.get('/history/:phoneNumber', async (req, res) => {
  try {
    const { phoneNumber } = req.params;
    const { startTime, endTime } = req.query;

    const start = startTime ? new Date(startTime as string) : new Date(Date.now() - 24 * 60 * 60 * 1000);
    const end = endTime ? new Date(endTime as string) : new Date();

    const locations = await JT808Storage.getLocationHistory(phoneNumber, start, end);

    res.json({
      success: true,
      data: locations,
    });
  } catch (error) {
    console.error('[JT808 API] Get history error:', error);
    res.status(500).json({ message: '获取历史轨迹失败' });
  }
});

export default router;
