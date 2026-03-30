/**
 * JT808客户端模拟器
 * 用于测试JT808服务器
 */

import * as net from 'net';
import { BCD, calculateChecksum, escape } from './protocol';
import { MessageId } from './types';

class JT808ClientSimulator {
  private socket: net.Socket;
  private phoneNumber: string;
  private messageSerialNo = 0;

  constructor(phoneNumber: string) {
    this.phoneNumber = phoneNumber;
    this.socket = new net.Socket();
  }

  private getNextSerialNo(): number {
    this.messageSerialNo = (this.messageSerialNo + 1) % 0xFFFF;
    return this.messageSerialNo;
  }

  private encodeMessage(messageId: number, body: Buffer): Buffer {
    const serialNo = this.getNextSerialNo();
    const phoneBcd = BCD.fromString(this.phoneNumber.padStart(12, '0'));
    const messageBodyProps = body.length & 0x03FF;

    const header = Buffer.alloc(12);
    let offset = 0;

    header.writeUInt16BE(messageId, offset);
    offset += 2;
    header.writeUInt16BE(messageBodyProps, offset);
    offset += 2;
    phoneBcd.copy(header, offset);
    offset += 6;
    header.writeUInt16BE(serialNo, offset);
    offset += 2;

    const message = Buffer.concat([header, body]);
    const checksum = calculateChecksum(message);
    const escaped = escape(Buffer.concat([message, Buffer.from([checksum])]));

    return Buffer.concat([Buffer.from([0x7E]), escaped, Buffer.from([0x7E])]);
  }

  connect(host: string, port: number): Promise<void> {
    return new Promise((resolve, reject) => {
      this.socket.connect(port, host, () => {
        console.log(`[JT808 Client] Connected to ${host}:${port}`);
        resolve();
      });

      this.socket.on('error', reject);
      this.socket.on('data', (data) => {
        console.log('[JT808 Client] Received:', data.toString('hex'));
      });
    });
  }

  sendRegister(): void {
    const body = Buffer.alloc(44);
    let offset = 0;

    // Province ID
    body.writeUInt16BE(31, offset);
    offset += 2;

    // City ID
    body.writeUInt16BE(100, offset);
    offset += 2;

    // Manufacturer ID
    body.write('TEST1', offset);
    offset += 5;

    // Terminal Model
    body.write('MODEL123'.padEnd(20, '\0'), offset);
    offset += 20;

    // Terminal ID
    body.write('TERM001', offset);
    offset += 7;

    // License Plate Color
    body.writeUInt8(1, offset);
    offset += 1;

    // License Plate
    body.write('京A12345', offset);

    const message = this.encodeMessage(MessageId.TERMINAL_REGISTER, body);
    this.socket.write(message);
    console.log('[JT808 Client] Sent register message');
  }

  sendAuth(authCode: string): void {
    const body = Buffer.from(authCode, 'ascii');
    const message = this.encodeMessage(MessageId.TERMINAL_AUTH, body);
    this.socket.write(message);
    console.log('[JT808 Client] Sent auth message');
  }

  sendHeartbeat(): void {
    const body = Buffer.alloc(0);
    const message = this.encodeMessage(MessageId.HEARTBEAT, body);
    this.socket.write(message);
    console.log('[JT808 Client] Sent heartbeat');
  }

  sendLocation(lat: number, lon: number): void {
    const body = Buffer.alloc(28);
    let offset = 0;

    // Alarm flag
    body.writeUInt32BE(0x00000000, offset);
    offset += 4;

    // Status flag (ACC on, positioned)
    body.writeUInt32BE(0x00000003, offset);
    offset += 4;

    // Latitude (convert degrees to JT808 format: 度×10^6)
    const jt808Lat = Math.round(lat * 1000000);
    body.writeUInt32BE(jt808Lat, offset);
    offset += 4;

    // Longitude (度×10^6)
    const jt808Lon = Math.round(lon * 1000000);
    body.writeUInt32BE(jt808Lon, offset);
    offset += 4;

    // Altitude
    body.writeUInt16BE(100, offset);
    offset += 2;

    // Speed (km/h * 10)
    body.writeUInt16BE(600, offset);
    offset += 2;

    // Direction
    body.writeUInt16BE(90, offset);
    offset += 2;

    // Time (BCD)
    const now = new Date();
    const year = (now.getFullYear() - 2000).toString().padStart(2, '0');
    const month = (now.getMonth() + 1).toString().padStart(2, '0');
    const day = now.getDate().toString().padStart(2, '0');
    const hour = now.getHours().toString().padStart(2, '0');
    const minute = now.getMinutes().toString().padStart(2, '0');
    const second = now.getSeconds().toString().padStart(2, '0');
    
    const timeBuffer = Buffer.from([
      parseInt(year, 16),
      parseInt(month, 16),
      parseInt(day, 16),
      parseInt(hour, 16),
      parseInt(minute, 16),
      parseInt(second, 16)
    ]);
    timeBuffer.copy(body, offset);

    const message = this.encodeMessage(MessageId.LOCATION_REPORT, body);
    this.socket.write(message);
    console.log(`[JT808 Client] Sent location: ${lat}, ${lon}`);
  }

  disconnect(): void {
    this.socket.end();
    console.log('[JT808 Client] Disconnected');
  }
}

// 测试脚本
async function main() {
  const client = new JT808ClientSimulator('013800000001');
  
  try {
    await client.connect('localhost', 8080);
    
    // 发送注册
    client.sendRegister();
    
    // 等待注册应答后发送鉴权
    setTimeout(() => {
      client.sendAuth('AUTH1234');
    }, 1000);
    
    // 发送位置
    setTimeout(() => {
      client.sendLocation(30.205761, 121.390946);
    }, 2000);
    
    // 定时发送心跳
    const heartbeatInterval = setInterval(() => {
      client.sendHeartbeat();
    }, 30000);
    
    // 10秒后断开
    setTimeout(() => {
      clearInterval(heartbeatInterval);
      client.disconnect();
      process.exit(0);
    }, 10000);
    
  } catch (error) {
    console.error('[JT808 Client] Error:', error);
    process.exit(1);
  }
}

// 如果直接运行此文件
if (require.main === module) {
  main();
}

export { JT808ClientSimulator };
