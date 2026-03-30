/**
 * 位置数据实时同步服务
 * 从生产数据库同步最新的位置数据到开发数据库
 *
 * 安全特性:
 * - 只读取生产数据库，不写入
 * - 只写入开发数据库
 * - 不影响任何现有服务
 * - 不修改任何端口
 * - 完全独立运行
 */

import mysql from 'mysql2/promise';
import dotenv from 'dotenv';

dotenv.config();

// 数据库配置
const PROD_DB_CONFIG = {
  host: process.env.RY_CLOUD_DB_HOST || '116.204.117.57',
  port: parseInt(process.env.RY_CLOUD_DB_PORT || '3307'),
  user: process.env.RY_CLOUD_DB_USER || 'root',
  password: process.env.RY_CLOUD_DB_PASSWORD || 'StrongPass!',
  database: process.env.RY_CLOUD_DB_NAME || 'ry-cloud', // 生产数据库
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
};

const DEV_DB_CONFIG = {
  host: process.env.STARBY_DEV_DB_HOST || '116.204.117.57',
  port: parseInt(process.env.STARBY_DEV_DB_PORT || '3307'),
  user: process.env.STARBY_DEV_DB_USER || 'root',
  password: process.env.STARBY_DEV_DB_PASSWORD || 'StrongPass!',
  database: process.env.STARBY_DEV_DB_NAME || 'starby-dev', // 开发数据库
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
};

// 同步配置
const SYNC_INTERVAL_MS = parseInt(process.env.SYNC_INTERVAL || '2000'); // 默认2秒
const BATCH_SIZE = parseInt(process.env.BATCH_SIZE || '100'); // 默认100条

// 同步状态
let syncStats = {
  totalSynced: 0,
  lastSyncTime: null as Date | null,
  lastSyncCount: 0,
  startTime: new Date(),
  errors: 0
};

// 创建数据库连接
let prodConnection: mysql.Connection | null = null;
let devConnection: mysql.Connection | null = null;

async function initializeConnections() {
  console.log('[同步] 初始化数据库连接...\n');

  try {
    prodConnection = await mysql.createConnection(PROD_DB_CONFIG);
    console.log(`✅ 生产数据库连接成功: ${PROD_DB_CONFIG.database}@${PROD_DB_CONFIG.host}:${PROD_DB_CONFIG.port}`);

    devConnection = await mysql.createConnection(DEV_DB_CONFIG);
    console.log(`✅ 开发数据库连接成功: ${DEV_DB_CONFIG.database}@${DEV_DB_CONFIG.host}:${DEV_DB_CONFIG.port}\n`);
  } catch (error) {
    console.error('❌ 数据库连接失败:', error);
    throw error;
  }
}

/**
 * 同步位置数据
 */
async function syncLocationData() {
  if (!prodConnection || !devConnection) {
    throw new Error('数据库连接未初始化');
  }

  const checkTime = new Date();
  const lastSyncTime = syncStats.lastSyncTime || new Date(Date.now() - 5 * 60 * 1000); // 首次同步最近5分钟的数据

  try {
    // 从生产数据库查询新数据
    console.log(`\n[${checkTime.toLocaleTimeString()}] 开始同步...`);
    console.log(`查询时间范围: ${lastSyncTime.toISOString()} → 现在`);

    const [rows] = await prodConnection.query<any[]>(
      `SELECT
        track_id,
        device_id,
        device_code,
        latitude,
        longitude,
        altitude,
        speed,
        direction,
        location_time,
        record_time,
        status_bit,
        acc_status,
        locate_status,
        base_station_info,
        original_report
      FROM lot_track
      WHERE record_time > ?
      ORDER BY record_time ASC
      LIMIT ?`,
      [lastSyncTime, BATCH_SIZE]
    );

    if (rows.length === 0) {
      console.log('✓ 没有新数据');
      return;
    }

    console.log(`📥 查询到 ${rows.length} 条新位置数据`);

    // 同步到开发数据库
    let syncedCount = 0;
    for (const row of rows) {
      try {
        // 检查设备是否存在
        const [devices] = await devConnection.query<any[]>(
          'SELECT device_id FROM lot_device WHERE device_code = ? LIMIT 1',
          [row.device_code]
        );

        if (devices.length === 0) {
          // 设备不存在，尝试创建
          console.log(`⚠️  设备 ${row.device_code} 不存在，跳过位置数据`);
          continue;
        }

        // 检查位置是否已存在
        const [existing] = await devConnection.query<any[]>(
          'SELECT track_id FROM lot_track WHERE track_id = ? LIMIT 1',
          [row.track_id]
        );

        if (existing.length > 0) {
          // 更新
          await devConnection.query(
            `UPDATE lot_track SET
              latitude = ?, longitude = ?, altitude = ?, speed = ?, direction = ?,
              location_time = ?, record_time = ?, status_bit = ?, acc_status = ?,
              locate_status = ?, base_station_info = ?, original_report = ?
            WHERE track_id = ?`,
            [
              row.latitude,
              row.longitude,
              row.altitude,
              row.speed,
              row.direction,
              row.location_time,
              row.record_time,
              row.status_bit,
              row.acc_status,
              row.locate_status,
              row.base_station_info,
              row.original_report,
              row.track_id
            ]
          );
        } else {
          // 插入
          await devConnection.query(
            `INSERT INTO lot_track SET ?`,
            [row]
          );
        }

        syncedCount++;

        // 更新设备的最新位置
        await devConnection.query(
          `UPDATE lot_device SET
            latitude = ?, longitude = ?, last_location_time = ?, location_info = ?, status = '1'
          WHERE device_code = ?`,
            [
              row.latitude,
              row.longitude,
              row.location_time,
              JSON.stringify({
                lat: row.latitude,
                lon: row.longitude,
                time: row.location_time
              }),
              row.device_code
            ]
          );

      } catch (error) {
        console.error(`❌ 同步失败 (locationId=${row.locationId}):`, error);
        syncStats.errors++;
      }
    }

    // 更新统计
    syncStats.totalSynced += syncedCount;
    syncStats.lastSyncCount = syncedCount;
    syncStats.lastSyncTime = checkTime;

    console.log(`✅ 成功同步 ${syncedCount}/${rows.length} 条数据`);
    console.log(`📊 总计已同步: ${syncStats.totalSynced} 条\n`);

  } catch (error) {
    console.error('❌ 同步失败:', error);
    syncStats.errors++;
  }
}

/**
 * 打印统计信息
 */
function printStatistics() {
  const uptime = Date.now() - syncStats.startTime.getTime();
  const uptimeMinutes = Math.floor(uptime / 60000);

  console.log('\n========================================');
  console.log('📊 数据同步服务统计');
  console.log('========================================');
  console.log(`运行时长: ${uptimeMinutes} 分钟`);
  console.log(`总同步数量: ${syncStats.totalSynced} 条`);
  console.log(`最近同步: ${syncStats.lastSyncCount} 条`);
  console.log(`最后同步时间: ${syncStats.lastSyncTime?.toISOString() || '从未同步'}`);
  console.log(`错误数量: ${syncStats.errors}`);
  console.log('========================================\n');
}

/**
 * 清理资源
 */
async function cleanup() {
  console.log('\n[同步] 正在清理资源...');

  if (prodConnection) {
    await prodConnection.end();
    console.log('✅ 生产数据库连接已关闭');
  }

  if (devConnection) {
    await devConnection.end();
    console.log('✅ 开发数据库连接已关闭');
  }

  printStatistics();
}

/**
 * 主函数
 */
async function main() {
  console.log('\n========================================');
  console.log('🚀 启动位置数据实时同步服务');
  console.log('========================================\n');

  try {
    // 初始化连接
    await initializeConnections();

    // 启动同步
    console.log(`[同步] 开始定时同步，间隔: ${SYNC_INTERVAL_MS}ms\n`);

    const syncInterval = setInterval(() => {
      syncLocationData().catch(err => {
        console.error('[同步] 同步任务失败:', err);
        syncStats.errors++;
      });
    }, SYNC_INTERVAL_MS);

    // 定期打印统计（每5分钟）
    const statsInterval = setInterval(() => {
      printStatistics();
    }, 5 * 60 * 1000);

    // 优雅关闭
    process.on('SIGINT', async () => {
      console.log('\n\n收到停止信号，正在关闭服务...');
      clearInterval(syncInterval);
      clearInterval(statsInterval);
      await cleanup();
      process.exit(0);
    });

    process.on('SIGTERM', async () => {
      console.log('\n\n收到终止信号，正在关闭服务...');
      clearInterval(syncInterval);
      clearInterval(statsInterval);
      await cleanup();
      process.exit(0);
    });

    // 立即执行一次同步
    await syncLocationData();

    console.log('✅ 同步服务运行中，按 Ctrl+C 停止\n');

  } catch (error) {
    console.error('❌ 启动失败:', error);
    await cleanup();
    process.exit(1);
  }
}

// 启动服务
main();
