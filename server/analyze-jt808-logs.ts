/**
 * JT808 日志分析工具
 * 分析服务器上记录的 JT808 数据，分析经纬度精度
 */

import * as fs from 'fs';
import * as path from 'path';
import * as readline from 'readline';

interface LocationSample {
  phoneNumber: string;
  rawLat: number;
  rawLon: number;
  latDegrees: number;
  lonDegrees: number;
  altitude: number;
  speed: number;
  direction: number;
  timestamp: Date;
  rawDataHex: string;
}

class JT808LogAnalyzer {
  private logFile: string;
  private locationSamples: LocationSample[] = [];

  constructor(logFile: string) {
    this.logFile = logFile;
  }

  async analyze(): Promise<void> {
    if (!fs.existsSync(this.logFile)) {
      console.error('日志文件不存在: ' + this.logFile);
      return;
    }

    console.log('\n========================================');
    console.log('JT808 日志分析工具');
    console.log('========================================');
    console.log('日志文件: ' + this.logFile);
    console.log('========================================\n');

    await this.parseLogFile();
    this.printSummary();
    this.analyzePrecision();
  }

  private async parseLogFile(): Promise<void> {
    const fileStream = fs.createReadStream(this.logFile);
    const rl = readline.createInterface({
      input: fileStream,
      crlfDelay: Infinity,
    });

    let lineCount = 0;
    let locationCount = 0;

    console.log('正在解析日志文件...\n');

    for await (const line of rl) {
      try {
        const entry = JSON.parse(line);
        lineCount++;

        // 检查是否是 JT808 位置上报 (0x0200)
        if (entry.body?.hex?.startsWith('0200')) {
          locationCount++;
          const location = this.parseLocationReport(entry.body.hex);

          if (location) {
            this.locationSamples.push({
              phoneNumber: location.phoneNumber,
              rawLat: location.latitude,
              rawLon: location.longitude,
              latDegrees: location.latDegrees,
              lonDegrees: location.lonDegrees,
              altitude: location.altitude,
              speed: location.speed,
              direction: location.direction,
              timestamp: new Date(entry.timestamp),
              rawDataHex: entry.body.hex,
            });
          }
        }
      } catch (error) {
        // 忽略解析错误的行
      }
    }

    console.log('✓ 解析完成');
    console.log('  总行数: ' + lineCount);
    console.log('  位置报告数: ' + locationCount);
    console.log('');
  }

  private parseLocationReport(hex: string): any {
    try {
      const data = Buffer.from(hex, 'hex');
      let offset = 0;

      // 消息头
      const messageId = data.readUInt16BE(offset); offset += 2;
      const messageProps = data.readUInt16BE(offset); offset += 2;
      const bodyLength = messageProps & 0x03FF;
      const terminalPhone = data.readBigUInt64BE(offset); offset += 8;
      const flowId = data.readUInt16BE(offset); offset += 2;

      // 消息体
      const alarmFlag = data.readUInt32BE(offset); offset += 4;
      const statusFlag = data.readUInt32BE(offset); offset += 4;
      const latitude = data.readUInt32BE(offset); offset += 4;
      const longitude = data.readUInt32BE(offset); offset += 4;
      const altitude = data.readUInt16BE(offset); offset += 2;
      const speed = data.readUInt16BE(offset); offset += 2;
      const direction = data.readUInt16BE(offset); offset += 2;

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
      };
    } catch (error) {
      return null;
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

  private printSummary(): void {
    console.log('========================================');
    console.log('数据汇总');
    console.log('========================================');
    console.log('位置报告总数: ' + this.locationSamples.length);
    console.log('');
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

    console.log('设备数: ' + Object.keys(grouped).length);
    console.log('');

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

        // 计算位置变化
        const latValues = samples.map(s => s.latDegrees);
        const lonValues = samples.map(s => s.lonDegrees);

        const latRange = Math.max(...latValues) - Math.min(...latValues);
        const lonRange = Math.max(...lonValues) - Math.min(...lonValues);

        console.log('  位置范围:');
        console.log('    纬度跨度: ' + latRange.toFixed(6) + ' 度 (' + (latRange * 111).toFixed(2) + ' km)');
        console.log('    经度跨度: ' + lonRange.toFixed(6) + ' 度 (' + (lonRange * 111).toFixed(2) + ' km)');
      }

      console.log('');
    }

    // 显示前 20 条样本数据
    console.log('========================================');
    console.log('样本数据 (前20条)');
    console.log('========================================\n');

    for (let i = 0; i < Math.min(20, this.locationSamples.length); i++) {
      const sample = this.locationSamples[i];
      console.log((i + 1) + '. 手机号: ' + sample.phoneNumber);
      console.log('   纬度: ' + sample.latDegrees.toFixed(8) + ' (' + this.countDecimalDigits(sample.latDegrees) + '位小数)');
      console.log('   经度: ' + sample.lonDegrees.toFixed(8) + ' (' + this.countDecimalDigits(sample.lonDegrees) + '位小数)');
      console.log('   时间: ' + sample.timestamp.toISOString());
      console.log('');
    }

    // 精度统计
    this.precisionStatistics();
  }

  private precisionStatistics(): void {
    console.log('========================================');
    console.log('精度统计汇总');
    console.log('========================================\n');

    const allLatDigits = this.locationSamples.map(s => this.countDecimalDigits(s.latDegrees));
    const allLonDigits = this.locationSamples.map(s => this.countDecimalDigits(s.lonDegrees));

    console.log('所有设备纬度小数位:');
    console.log('  平均: ' + (allLatDigits.reduce((a, b) => a + b, 0) / allLatDigits.length).toFixed(2) + ' 位');
    console.log('  最大: ' + Math.max(...allLatDigits) + ' 位');
    console.log('  最小: ' + Math.min(...allLatDigits) + ' 位');
    console.log('  中位数: ' + this.median(allLatDigits).toFixed(2) + ' 位');
    console.log('');

    console.log('所有设备经度小数位:');
    console.log('  平均: ' + (allLonDigits.reduce((a, b) => a + b, 0) / allLonDigits.length).toFixed(2) + ' 位');
    console.log('  最大: ' + Math.max(...allLonDigits) + ' 位');
    console.log('  最小: ' + Math.min(...allLonDigits) + ' 位');
    console.log('  中位数: ' + this.median(allLonDigits).toFixed(2) + ' 位');
    console.log('');

    // 精度分布
    console.log('精度分布:');
    this.printDistribution(allLatDigits, '纬度');
    this.printDistribution(allLonDigits, '经度');
  }

  private median(arr: number[]): number {
    const sorted = [...arr].sort((a, b) => a - b);
    const mid = Math.floor(sorted.length / 2);
    return sorted.length % 2 !== 0 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
  }

  private printDistribution(arr: number[], label: string): void {
    const distribution: { [key: number]: number } = {};
    for (const val of arr) {
      distribution[val] = (distribution[val] || 0) + 1;
    }

    console.log('  ' + label + ':');
    for (const [digits, count] of Object.entries(distribution).sort((a, b) => parseInt(a[0]) - parseInt(b[0]))) {
      const percentage = ((count / arr.length) * 100).toFixed(1);
      console.log('    ' + digits + ' 位: ' + count + ' 条 (' + percentage + '%)');
    }
    console.log('');
  }
}

// 从命令行获取日志文件路径
const logFile = process.argv[2] || './logs/jt808-' + new Date().toISOString().split('T')[0] + '.log';

const analyzer = new JT808LogAnalyzer(logFile);
analyzer.analyze().catch(console.error);
