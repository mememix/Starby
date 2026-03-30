/**
 * HTTP JT808 数据监控工具
 * 监听 HTTP 接口接收到的 JT808 协议数据
 * 通过抓取 HTTP 请求体中的原始二进制数据进行分析
 */

import axios, { Axios } from 'axios';

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

class HTTPJT808Monitor {
  private httpUrl: string;
  private capturedCount: number = 0;
  private locationSamples: LocationSample[] = [];

  constructor(httpUrl: string) {
    this.httpUrl = httpUrl;
  }

  async startMonitoring(): Promise<void> {
    console.log('\n========================================');
    console.log('HTTP JT808 数据监控工具');
    console.log('========================================');
    console.log('监控地址: ' + this.httpUrl);
    console.log('========================================');
    console.log('');
    console.log('⚠️  注意：此工具需要配合 HTTP 服务器的日志或中间件使用');
    console.log('⚠️  如果服务器支持 SSE (Server-Sent Events)，建议使用 SSE 监听');
    console.log('⚠️  如果服务器支持 WebSocket，建议使用 WebSocket 监听');
    console.log('');
    console.log('可选方案：');
    console.log('1. 使用 tcpdump 在服务器端抓包（推荐）');
    console.log('2. 配置服务器中间件记录 HTTP 请求体');
    console.log('3. 使用 WebSocket/SSE 实时推送数据');
    console.log('');
  }

  private parseJT808Location(data: Buffer): any {
    try {
      // JT808 位置上报消息 (0x0200) 解析
      let offset = 0;

      // 消息头
      const messageId = data.readUInt16BE(offset); offset += 2; // 消息ID
      const messageProps = data.readUInt16BE(offset); offset += 2; // 消息体属性
      const bodyLength = messageProps & 0x03FF;
      const terminalPhone = data.readBigUInt64BE(offset); offset += 8; // 终端手机号
      const flowId = data.readUInt16BE(offset); offset += 2; // 消息流水号

      // 消息体 - 位置信息
      const alarmFlag = data.readUInt32BE(offset); offset += 4; // 报警标志
      const statusFlag = data.readUInt32BE(offset); offset += 4; // 状态标志
      const latitude = data.readUInt32BE(offset); offset += 4; // 纬度 (整数)
      const longitude = data.readUInt32BE(offset); offset += 4; // 经度 (整数)
      const altitude = data.readUInt16BE(offset); offset += 2; // 海拔
      const speed = data.readUInt16BE(offset); offset += 2; // 速度
      const direction = data.readUInt16BE(offset); offset += 2; // 方向
      const time = data.slice(offset, offset + 6).toString('hex'); // GPS时间 BCD码

      // 转换为度
      const latDegrees = latitude / 1000000;
      const lonDegrees = longitude / 1000000;

      return {
        messageId,
        bodyLength,
        phoneNumber: terminalPhone.toString(),
        messageSerialNo: flowId,
        latitude,
        longitude,
        latDegrees,
        lonDegrees,
        altitude,
        speed,
        direction,
        time
      };
    } catch (error) {
      throw new Error('解析失败: ' + error);
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

  private analyzeData(dataHex: string): void {
    try {
      const data = Buffer.from(dataHex, 'hex');

      // 尝试解析为 JT808 消息
      const location = this.parseJT808Location(data);

      this.capturedCount++;
      this.locationSamples.push({
        phoneNumber: location.phoneNumber,
        rawLat: location.latitude,
        rawLon: location.longitude,
        latDegrees: location.latDegrees,
        lonDegrees: location.lonDegrees,
        altitude: location.altitude,
        speed: location.speed,
        direction: location.direction,
        timestamp: new Date(),
        rawDataHex: dataHex,
      });

      console.log('[' + new Date().toISOString() + '] 捕获到位置数据:');
      console.log('  原始纬度(整数): ' + location.latitude);
      console.log('  原始经度(整数): ' + location.longitude);
      console.log('  纬度(度): ' + location.latDegrees.toFixed(8));
      console.log('  经度(度): ' + location.lonDegrees.toFixed(8));
      console.log('  纬度小数位: ' + this.countDecimalDigits(location.latDegrees));
      console.log('  经度小数位: ' + this.countDecimalDigits(location.lonDegrees));
      console.log('  海拔: ' + location.altitude + ' 米');
      console.log('  速度: ' + location.speed + ' km/h');
      console.log('  方向: ' + location.direction + '°');
      console.log('');

    } catch (error) {
      console.error('数据解析失败:', error);
    }
  }

  printSummary(): void {
    console.log('\n========================================');
    console.log('监控汇总');
    console.log('========================================');
    console.log('总捕获数: ' + this.capturedCount);
    console.log('位置报告数: ' + this.locationSamples.length);
    console.log('========================================\n');
  }

  analyzePrecision(): void {
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

const HTTP_URL = process.env.HTTP_URL || 'http://116.204.117.57:7100';
const monitor = new HTTPJT808Monitor(HTTP_URL);

async function startMonitoring() {
  try {
    await monitor.startMonitoring();

    process.on('SIGINT', () => {
      console.log('\n\n收到停止信号...');
      monitor.printSummary();
      monitor.analyzePrecision();
      process.exit(0);
    });

    process.on('SIGTERM', () => {
      console.log('\n\n收到终止信号...');
      monitor.printSummary();
      monitor.analyzePrecision();
      process.exit(0);
    });

    console.log('监控工具已启动');
    console.log('   ⚠️  HTTP 接口监控需要服务器端配合');
    console.log('   ⚠️  建议使用以下方案之一：');
    console.log('');
    console.log('【方案1 - 推荐】在服务器端运行捕获工具');
    console.log('  ssh root@116.204.117.57');
    console.log('  cd /path/to/server');
    console.log('  npm run capture');
    console.log('');
    console.log('【方案2】使用 tcpdump 抓包分析');
    console.log('  ssh root@116.204.117.57');
    console.log('  tcpdump -i any -A port 7100 -w capture.pcap');
    console.log('');
    console.log('【方案3】查看服务器日志');
    console.log('  ssh root@116.204.117.57');
    console.log('  tail -f /path/to/server/logs/app.log');
    console.log('');

  } catch (error) {
    console.error('启动失败:', error);
    process.exit(1);
  }
}

startMonitoring();
