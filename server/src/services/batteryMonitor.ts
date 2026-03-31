import prisma from '../lib/prisma';

const LOW_BATTERY_THRESHOLD = 20; // 电量低于20%时告警
const CHECK_INTERVAL = 5 * 60 * 1000; // 每5分钟检查一次

// 记录已发送告警的设备（避免重复发送）
const alertHistory = new Map<string, number>(); // deviceId -> lastAlertTime

/**
 * 检查所有设备的电量，为低电量设备创建消息
 */
export async function checkLowBatteryDevices() {
  try {
    console.log('[BatteryMonitor] 开始检查低电量设备...');

    // 使用原生SQL查询所有绑定的设备及其电量信息
    // 注意：Device和DeviceBinding之间没有定义Prisma关系，使用原生查询
    const devices = await prisma.$queryRaw<Array<any>>`
      SELECT 
        d.device_id,
        d.device_code,
        d.device_name,
        d.battery
      FROM lot_device d
      INNER JOIN lot_user_device_bind b ON d.device_id = b.device_id
      WHERE b.bind_status = 1
        AND d.battery IS NOT NULL
        AND d.del_flag = 0
    `;

    console.log(`[BatteryMonitor] 找到 ${devices.length} 个有电量的设备`);

    const now = Date.now();
    let alertCount = 0;

    for (const device of devices) {
      const deviceId = device.device_id.toString();

      // 检查是否为低电量
      if (device.battery !== null && device.battery < LOW_BATTERY_THRESHOLD) {
        // 检查是否最近已发送过告警（避免重复发送，1小时内只发一次）
        const lastAlertTime = alertHistory.get(deviceId) || 0;
        const oneHour = 60 * 60 * 1000;

        if (now - lastAlertTime > oneHour) {
          // 查询绑定该设备的所有用户
          const bindings = await prisma.$queryRaw<Array<any>>`
            SELECT user_id
            FROM lot_user_device_bind
            WHERE device_id = ${device.device_id}
              AND bind_status = 1
          `;

          // 为每个绑定的用户创建低电量消息
          const messages = await Promise.all(
            bindings.map(async (binding: any) => {
              const alertLevel = device.battery! < 10 ? 'critical' : 'warning';

              const message = await prisma.message.create({
                data: {
                  deviceId: deviceId,
                  device_code: device.device_code,
                  message_type: 'lowBattery',
                  protocol_type: 'SYSTEM',
                  message_id: '0x0002',
                  message_name: '电量不足告警',
                  decoded_data: JSON.stringify({
                    deviceName: device.device_name || device.device_code,
                    battery: device.battery,
                    deviceCode: device.device_code,
                    timestamp: new Date().toISOString(),
                  }),
                  business_data: JSON.stringify({
                    userId: binding.user_id.toString(),
                    battery: device.battery,
                    alertLevel: alertLevel,
                  }),
                  receive_time: new Date(),
                  process_status: false,
                },
              });

              console.log(`[BatteryMonitor] 为用户 ${binding.user_id} 创建低电量消息: 设备 ${device.device_code}, 电量 ${device.battery}%`);

              return message;
            })
          );

          alertCount += messages.length;
          alertHistory.set(deviceId, now); // 记录告警时间
        } else {
          console.log(`[BatteryMonitor] 设备 ${device.device_code} 电量 ${device.battery}%，但已发送告警，跳过`);
        }
      }
    }

    console.log(`[BatteryMonitor] 检查完成，共创建 ${alertCount} 条低电量告警消息`);
    return alertCount;
  } catch (error) {
    console.error('[BatteryMonitor] 检查失败:', error);
    throw error;
  }
}

/**
 * 启动电池监控定时任务
 */
export function startBatteryMonitor() {
  console.log('[BatteryMonitor] 启动电池监控定时任务，检查间隔:', CHECK_INTERVAL / 1000, '秒');

  // 立即执行一次检查
  checkLowBatteryDevices();

  // 启动定时检查
  setInterval(() => {
    checkLowBatteryDevices();
  }, CHECK_INTERVAL);
}

/**
 * 手动触发电池检查（用于测试）
 */
export async function manualCheckBattery() {
  console.log('[BatteryMonitor] 手动触发电池检查');
  return await checkLowBatteryDevices();
}
