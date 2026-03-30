/**
 * JT808 远程数据捕获和分析工具
 * 连接到远程服务器并捕获 JT808 协议数据
 * 重点分析位置数据的精度
 */

import * as net from 'net';
import { JT808Parser } from './src/jt808/parser';
import { MessageId } from './src/jt808/types';

interface LocationSample {
  phoneNumber: string;
  rawLat: number;
  rawLon: number;
  latDegrees: number;
  lonDegrees: number;
  altitude?: number;
  speed: number;
  direction: number;
  timestamp: Date;
  rawDataHex: string;
}

class JT808RemoteCapture {
  private socket: net.Socket;
  private host: string;
  private port: number;
  private parser: JT808Parser;
  private capturedCount: number = 0;
  private locationSamples: LocationSample[] = [];

  constructor(host: string, port: number) {
    this.host = host;
    this.port = port;
    this.parser = new JT808Parser();
    this.socket = new net.Socket();
  }

  async connect(): Promise<void> {
    return new Promise((resolve, reject) => {
      this.socket.connect(this.port, this.host, () => {
        console.log('\n========================================');
        console.log('JT808 远程数据捕获工具启动');
        console.log('========================================');
        console.log('连接服务器: ' + this.host + ':' + this.port);
        console.log('========================================');
        console.log('');
        console.log('正在监听数据流...\n');
        resolve();
      });

      this.socket.on('data', (data: Buffer) => {
        this.handleData(data);
      });

      this.socket.on('error', (error: Error) => {
        console.error('[捕获工具] 连接错误:', error.message);
        reject(error);
      });

      this.socket.on('close', () => {
        console.log('\n[捕获工具] 连接已关闭');
        this.printSummary();
        this.analyzePrecision();
      });
    });
  }

  disconnect(): void {
    if (this.socket) {
      this.socket.end();
    }
  }

  private handleData(data: Buffer): void {
    try {
      console.log('[' + new Date().toISOString() + '] [原始数据] 长度: ' + data.length + ' bytes');
      console.log('[' + new Date().toISOString() + '] [原始数据] Hex: ' + data.toString('hex').substring(0, 80) + (data.length > 40 ? '...' : ''));
      console.log('');

      this.parser.addData(data);
      const messages = this.parser.parseMessages();

      for (const message of messages) {
        this.capturedCount++;
        this.handleMessage(message, data);
      }
    } catch (error) {
      console.error('[捕获工具] 数据处理错误:', error);
    }
  }

  private handleMessage(message: any, rawData: Buffer): void {
    const { header, body } = message;
    const { messageId, phoneNumber, messageSerialNo } = header;
    const timestamp = new Date().toISOString();

    console.log('[' + timestamp + '] 消息详情:');
    console.log('  消息ID: 0x' + messageId.toString(16).padStart(4, '0') + ' (' + this.getMessageName(messageId) + ')');
    console.log('  手机号: ' + phoneNumber);
    console.log('  流水号: ' + messageSerialNo);
    console.log('  消息体长度: ' + body.length + ' bytes');
    console.log('');

    switch (messageId) {
      case MessageId.LOCATION_REPORT:
        this.handleLocationReport(phoneNumber, body, rawData);
        break;
      default:
        console.log('  消息类型: ' + this.getMessageName(messageId));
        console.log('');
    }
  }

  private handleLocationReport(phoneNumber: string, body: Buffer, rawData: Buffer): void {
    try {
      const location: any = JT808Parser.parseLocationReport(body);

      this.locationSamples.push({
        phoneNumber,
        rawLat: location.latitude,
        rawLon: location.longitude,
        latDegrees: location.latDegrees,
        lonDegrees: location.lonDegrees,
        altitude: location.altitude,
        speed: location.speed,
        direction: location.direction,
        timestamp: new Date(),
        rawDataHex: rawData.toString('hex'),
      });

      console.log('位置报告详情:');
      console.log('  原始纬度(整数): ' + location.latitude);
      console.log('  原始经度(整数): ' + location.longitude);
      console.log('  纬度(度): ' + location.latDegrees.toFixed(8));
      console.log('  经度(度): ' + location.lonDegrees.toFixed(8));
      console.log('  纬度小数位: ' + this.countDecimalDigits(location.latDegrees));
      console.log('  经度小数位: ' + this.countDecimalDigits(location.lonDegrees));
      console.log('  海拔: ' + location.altitude + ' 米');
      console.log('  速度: ' + location.speed + ' km/h');
      console.log('  方向: ' + location.direction + '°');
      console.log('  GPS时间: ' + location.time);
      console.log('');
    } catch (error) {
      console.error('[捕获工具] 位置报告解析失败:', error);
    }
  }

  private countDecimalDigits(value: number): number {
    const str = value.toFixed(10);
    const decimalPart = str.split('.')[1];
    let count = 0;

    for (const char of decimalPart) {
      if (char !== '0') {
        count++;
      } else if (count > 0) {
        break;
      }
    }

    return count;
  }

  private getMessageName(messageId: number): string {
    const names: { [key: number]: string } = {
      [MessageId.HEARTBEAT]: '心跳',
      [MessageId.TERMINAL_REGISTER]: '终端注册',
      [MessageId.TERMINAL_AUTH]: '终端鉴权',
      [MessageId.LOCATION_REPORT]: '位置上报',
    };
    return names[messageId] || ('未知(0x' + messageId.toString(16) + ')');
  }

  private printSummary(): void {
    console.log('\n========================================');
    console.log('捕获汇总');
    console.log('========================================');
    console.log('总捕获数: ' + this.capturedCount);
    console.log('位置报告数: ' + this.locationSamples.length);
    console.log('========================================\n');
  }

  private analyzePrecision(): void {
    if (this.locationSamples.length === 0) {
      console.log('没有位置数据可供分析\n');
      return;
    }

    console.log('========================================');
    console.log('经纬度精度分析');
    console.log('========================================\n');

    const grouped: { [key: string]: LocationSample[] } = {};
    for (const sample of this.locationSamples) {
      if (!grouped[sample.phoneNumber]) {
        grouped[sample.phoneNumber] = [];
      }
      grouped[sample.phoneNumber].push(sample);
    }

    for (const [phoneNumber, samples] of Object.entries(grouped)) {
      console.log('设备: ' + phoneNumber);
      console.log('  样本数: ' + samples.length);

      if (samples.length > 1) {
        const latDigits = samples.map(s => this.countDecimalDigits(s.latDegrees));
        const lonDigits = samples.map(s => this.countDecimalDigits(s.lonDegrees));

        const avgLatDigits = latDigits.reduce((a, b) => a + b, 0) / latDigits.length;
        const avgLonDigits = lonDigits.reduce((a, b) => a + b, 0) / lonDigits.length;

        const maxLatDigits = Math.max(...latDigits);
        const maxLonDigits = Math.max(...lonDigits);

        const minLatDigits = Math.min(...latDigits);
        const minLonDigits = Math.min(...lonDigits);

        console.log('  纬度小数位:');
        console.log('    平均: ' + avgLatDigits.toFixed(1) + ' 位');
        console.log('    最大: ' + maxLatDigits + ' 位');
        console.log('    最小: ' + minLatDigits + ' 位');
        console.log('  经度小数位:');
        console.log('    平均: ' + avgLonDigits.toFixed(1) + ' 位');
        console.log('    最大: ' + maxLonDigits + ' 位');
        console.log('    最小: ' + minLonDigits + ' 位');
      }

      console.log('');
    }

    console.log('========================================');
    console.log('样本数据 (前10条)');
    console.log('========================================\n');

    for (let i = 0; i < Math.min(10, this.locationSamples.length); i++) {
      const sample = this.locationSamples[i];
      console.log((i + 1) + '. 手机号: ' + sample.phoneNumber);
      console.log('   纬度: ' + sample.latDegrees.toFixed(8) + ' (' + this.countDecimalDigits(sample.latDegrees) + '位小数)');
      console.log('   经度: ' + sample.lonDegrees.toFixed(8) + ' (' + this.countDecimalDigits(sample.lonDegrees) + '位小数)');
      console.log('   时间: ' + sample.timestamp.toISOString());
      console.log('');
    }
  }
}

const HOST = process.env.JT808_HOST || '116.204.117.57';
const PORT = parseInt(process.env.JT808_PORT || '7100', 10);
const capture = new JT808RemoteCapture(HOST, PORT);

async function startCapture() {
  try {
    await capture.connect();

    console.log('捕获工具运行中...');
    console.log('   正在监听 ' + HOST + ':' + PORT + ' 的数据流');
    console.log('   按 Ctrl+C 停止并分析\n');

    process.on('SIGINT', () => {
      console.log('\n\n收到停止信号,正在停止捕获...');
      capture.disconnect();
      setTimeout(() => process.exit(0), 1000);
    });

    process.on('SIGTERM', () => {
      console.log('\n\n收到终止信号,正在停止捕获...');
      capture.disconnect();
      setTimeout(() => process.exit(0), 1000);
    });
  } catch (error) {
    console.error('启动失败:', error);
    process.exit(1);
  }
}

startCapture();
