/**
 * JT808协议工具类
 * 参考标准: JT/T 808-2019 道路运输车辆卫星定位系统终端通讯协议及数据格式
 */

/**
 * BCD编码转换
 */
export class BCD {
  /**
   * Buffer转BCD字符串
   */
  static toString(buffer: Buffer): string {
    let result = '';
    for (let i = 0; i < buffer.length; i++) {
      const high = (buffer[i] >> 4) & 0x0F;
      const low = buffer[i] & 0x0F;
      result += high.toString() + low.toString();
    }
    return result;
  }

  /**
   * 字符串转BCD Buffer
   */
  static fromString(str: string): Buffer {
    const len = Math.ceil(str.length / 2);
    const buffer = Buffer.alloc(len);
    let strIndex = 0;
    for (let i = 0; i < len; i++) {
      const high = parseInt(str[strIndex++] || '0', 10);
      const low = parseInt(str[strIndex++] || '0', 10);
      buffer[i] = (high << 4) | low;
    }
    return buffer;
  }

  /**
   * BCD时间转Date (格式: YYMMDDHHMMSS)
   */
  static toDate(bcdStr: string): Date {
    const year = 2000 + parseInt(bcdStr.substring(0, 2), 10);
    const month = parseInt(bcdStr.substring(2, 4), 10) - 1;
    const day = parseInt(bcdStr.substring(4, 6), 10);
    const hour = parseInt(bcdStr.substring(6, 8), 10);
    const minute = parseInt(bcdStr.substring(8, 10), 10);
    const second = parseInt(bcdStr.substring(10, 12), 10);
    return new Date(year, month, day, hour, minute, second);
  }

  /**
   * Date转BCD时间字符串
   */
  static fromDate(date: Date): string {
    const year = (date.getFullYear() - 2000).toString().padStart(2, '0');
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    const hour = date.getHours().toString().padStart(2, '0');
    const minute = date.getMinutes().toString().padStart(2, '0');
    const second = date.getSeconds().toString().padStart(2, '0');
    return year + month + day + hour + minute + second;
  }
}

/**
 * 校验码计算 (异或校验)
 */
export function calculateChecksum(buffer: Buffer): number {
  let checksum = 0;
  for (let i = 0; i < buffer.length; i++) {
    checksum ^= buffer[i];
  }
  return checksum;
}

/**
 * 消息转义 (0x7D -> 0x7D 0x01, 0x7E -> 0x7D 0x02)
 */
export function escape(buffer: Buffer): Buffer {
  const result: number[] = [];
  for (let i = 0; i < buffer.length; i++) {
    if (buffer[i] === 0x7D) {
      result.push(0x7D, 0x01);
    } else if (buffer[i] === 0x7E) {
      result.push(0x7D, 0x02);
    } else {
      result.push(buffer[i]);
    }
  }
  return Buffer.from(result);
}

/**
 * 消息反转义
 */
export function unescape(buffer: Buffer): Buffer {
  const result: number[] = [];
  for (let i = 0; i < buffer.length; i++) {
    if (buffer[i] === 0x7D && i + 1 < buffer.length) {
      if (buffer[i + 1] === 0x01) {
        result.push(0x7D);
      } else if (buffer[i + 1] === 0x02) {
        result.push(0x7E);
      }
      i++;
    } else {
      result.push(buffer[i]);
    }
  }
  return Buffer.from(result);
}

/**
 * 经纬度转换 (JT808格式 -> 度)
 * JT808格式: 度×10^6，精确到百万分之一度 (例如: 31234567 = 31.234567度)
 */
export function convertLatitude(value: number): number {
  return value / 1000000;
}

export function convertLongitude(value: number): number {
  return value / 1000000;
}

/**
 * 经纬度转换 (度 -> JT808格式)
 * 度×10^6，精确到百万分之一度
 */
export function toJT808Latitude(degrees: number): number {
  return Math.round(degrees * 1000000);
}

export function toJT808Longitude(degrees: number): number {
  return Math.round(degrees * 1000000);
}
