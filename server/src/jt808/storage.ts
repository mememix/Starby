/**
 * JT808数据存储模块
 * 与现有数据库集成
 */

import { PrismaClient, Prisma } from '@prisma/client';
import { LocationReportBody } from './types';

const prisma = new PrismaClient();

/**
 * JT808设备存储
 */
export class JT808Storage {
  /**
   * 保存或更新设备信息
   */
  static async saveDevice(
    deviceCode: string,
    authCode: string,
    registerData?: any
  ): Promise<void> {
    try {
      await prisma.device.upsert({
        where: { deviceCode },
        update: {
          deviceCode: authCode,
          status: "1",
          lastLocationTime: new Date(),
          ...(registerData && {
            manufacturer: registerData.manufacturerId,
            deviceModel: registerData.terminalModel,
            simNumber: registerData.terminalId,
            plateNumber: registerData.licensePlate,
          }),
        },
        create: {
          deviceCode,
          devicePassword: authCode,
          status: "1",
          lastLocationTime: new Date(),
          deviceType: 'JT808',
          deviceName: `JT808-${deviceCode}`,
          ...(registerData && {
            manufacturer: registerData.manufacturerId,
            deviceModel: registerData.terminalModel,
            simNumber: registerData.terminalId,
            plateNumber: registerData.licensePlate,
          }),
        },
      });
      console.log(`[JT808] Device saved: ${deviceCode}`);
    } catch (error) {
      console.error('[JT808] Failed to save device:', error);
    }
  }

  /**
   * 保存位置信息
   */
  static async saveLocation(
    deviceCode: string,
    location: LocationReportBody
  ): Promise<void> {
    try {
      // 查找设备
      const device = await prisma.device.findUnique({
        where: { deviceCode },
      });

      if (!device) {
        console.warn(`[JT808] Device not found for location: ${deviceCode}`);
        return;
      }

      // 创建位置记录
      await prisma.location.create({
        data: {
          deviceId: device.deviceId,
          device_code: deviceCode,
          latitude: location.latDegrees,
          longitude: location.lonDegrees,
          altitude: location.altitude?.toString() || '0',
          speed: location.speed ? new Prisma.Decimal(location.speed / 10) : new Prisma.Decimal(0),
          direction: location.direction || 0,
          location_time: location.time,
          record_time: new Date().toISOString(),
          // 报警标志转换为状态位
          status_bit: location.alarmFlag ? this.encodeAlarmFlag(location.alarmFlag) : 0,
          // 状态标志
          acc_status: location.statusFlag?.accOn || false,
          locate_status: location.statusFlag?.positioned || false,
          // 基站信息
          base_station_info: JSON.stringify({
            satellites: 0,
          }),
          // 原始数据
          original_report: JSON.stringify(location),
        },
      });

      // 更新设备最后位置
      await prisma.device.update({
        where: { deviceCode },
        data: {
          latitude: location.latDegrees,
          longitude: location.lonDegrees,
          lastLocationTime: location.time,
          locationInfo: JSON.stringify({
            lat: location.latDegrees,
            lon: location.lonDegrees,
            time: location.time,
          }),
          status: "1",
        },
      });

      console.log(`[JT808] Location saved: ${deviceCode} at ${location.latDegrees.toFixed(6)}, ${location.lonDegrees.toFixed(6)}`);
    } catch (error) {
      console.error('[JT808] Failed to save location:', error);
    }
  }

  /**
   * 更新设备在线状态
   */
  static async updateOnlineStatus(
    deviceCode: string,
    isOnline: boolean
  ): Promise<void> {
    try {
      // 先获取设备当前状态和设备信息
      const device = await prisma.device.findUnique({
        where: { deviceCode },
        select: {
          deviceId: true,
          deviceName: true,
          userId: true,
          status: true,
        },
      });

      if (!device) {
        console.error('[JT808] Device not found:', deviceCode);
        return;
      }

      const previousStatus = device.status === "1";
      const statusChanged = previousStatus !== isOnline;

      // 更新设备状态
      await prisma.device.update({
        where: { deviceCode },
        data: {
          status: isOnline ? "1" : "0",
          lastLocationTime: new Date(),
        },
      });

      // 如果状态发生变化，创建上线/离线消息
      if (statusChanged) {
        const messageType = isOnline ? 'online' : 'offline';
        const title = isOnline ? '设备上线' : '设备离线';
        const content = device.deviceName 
          ? `${device.deviceName}已${isOnline ? '上线' : '离线'}`
          : `设备已${isOnline ? '上线' : '离线'}`;

        // 创建消息记录
        await prisma.message.create({
          data: {
            deviceId: deviceCode,
            device_code: deviceCode,
            message_type: messageType,
            protocol_type: 'JT808',
            message_name: title,
            decoded_data: JSON.stringify({
              deviceName: device.deviceName,
              deviceCode: deviceCode,
              timestamp: new Date().toISOString(),
            }),
            receive_time: new Date(),
            process_status: false,
          },
        });

        console.log(`[JT808] Created ${messageType} message for device ${deviceCode}`);
      }
    } catch (error) {
      console.error('[JT808] Failed to update online status:', error);
    }
  }

  /**
   * 获取设备最新位置
   */
  static async getLatestLocation(deviceCode: string) {
    try {
      const device = await prisma.device.findUnique({
        where: { deviceCode },
      });

      if (!device) {
        return null;
      }

      const location = await prisma.location.findFirst({
        where: { deviceId: device.deviceId },
        orderBy: { location_time: 'desc' },
      });

      return location;
    } catch (error) {
      console.error('[JT808] Failed to get latest location:', error);
      return null;
    }
  }

  /**
   * 获取设备历史轨迹
   */
  static async getLocationHistory(
    deviceCode: string,
    startTime: Date,
    endTime: Date
  ) {
    try {
      const device = await prisma.device.findUnique({
        where: { deviceCode },
      });

      if (!device) {
        return [];
      }

      const locations = await prisma.location.findMany({
        where: {
          deviceId: device.deviceId,
          location_time: {
            gte: startTime,
            lte: endTime,
          },
        },
        orderBy: { location_time: 'asc' },
      });

      return locations;
    } catch (error) {
      console.error('[JT808] Failed to get location history:', error);
      return [];
    }
  }

  /**
   * 编码报警标志
   */
  private static encodeAlarmFlag(alarmFlag: any): number {
    let status = 0;
    if (alarmFlag.emergency) status |= 0x01;
    if (alarmFlag.overspeed) status |= 0x02;
    if (alarmFlag.fatigue) status |= 0x04;
    if (alarmFlag.powerLow) status |= 0x08;
    if (alarmFlag.powerLost) status |= 0x10;
    return status;
  }

  /**
   * 解码报警标志
   */
  private static decodeAlarmFlag(status: number): any {
    return {
      emergency: (status & 0x01) !== 0,
      overspeed: (status & 0x02) !== 0,
      fatigue: (status & 0x04) !== 0,
      powerLow: (status & 0x08) !== 0,
      powerLost: (status & 0x10) !== 0,
    };
  }
}
