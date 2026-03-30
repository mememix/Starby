/**
 * JT808 数据记录中间件
 * 将此中间件添加到服务器，记录所有接收到的 JT808 协议数据
 *
 * 使用方法：
 * 1. 将此文件复制到远程服务器
 * 2. 在服务器的主应用中引入并使用此中间件
 * 3. 所有 JT808 数据将被记录到文件中
 */

import * as fs from 'fs';
import * as path from 'path';

interface LogEntry {
  timestamp: string;
  method: string;
  url: string;
  headers: any;
  body: {
    hex: string;
    length: number;
    data?: any;
  };
}

class JT808Logger {
  private logFile: string;
  private logEntries: LogEntry[] = [];

  constructor(logDir: string = './logs') {
    // 创建日志目录
    if (!fs.existsSync(logDir)) {
      fs.mkdirSync(logDir, { recursive: true });
    }

    // 创建日志文件（按日期）
    const date = new Date().toISOString().split('T')[0];
    this.logFile = path.join(logDir, `jt808-${date}.log`);

    console.log('[JT808 Logger] 日志文件: ' + this.logFile);
  }

  /**
   * Express 中间件 - 记录请求体
   */
  middleware() {
    return (req: any, res: any, next: any) => {
      const chunks: Buffer[] = [];

      req.on('data', (chunk: Buffer) => {
        chunks.push(chunk);
      });

      req.on('end', () => {
        if (chunks.length > 0) {
          const bodyBuffer = Buffer.concat(chunks);

          const logEntry: LogEntry = {
            timestamp: new Date().toISOString(),
            method: req.method,
            url: req.url,
            headers: req.headers,
            body: {
              hex: bodyBuffer.toString('hex'),
              length: bodyBuffer.length,
            },
          };

          // 尝试解析 JSON
          try {
            if (req.is('json')) {
              logEntry.body.data = JSON.parse(bodyBuffer.toString());
            }
          } catch (e) {
            // 不是 JSON 数据，可能是二进制 JT808 数据
          }

          this.log(logEntry);
        }

        next();
      });
    };
  }

  /**
   * Socket.IO 中间件 - 记录 Socket 消息
   */
  socketMiddleware(socket: any) {
    socket.on('message', (data: any) => {
      this.log({
        timestamp: new Date().toISOString(),
        method: 'SOCKET',
        url: socket.id,
        headers: socket.handshake.headers,
        body: {
          hex: Buffer.isBuffer(data) ? data.toString('hex') : JSON.stringify(data),
          length: Buffer.isBuffer(data) ? data.length : JSON.stringify(data).length,
          data: Buffer.isBuffer(data) ? undefined : data,
        },
      });
    });
  }

  private log(entry: LogEntry): void {
    this.logEntries.push(entry);

    // 实时写入文件
    const logLine = JSON.stringify(entry) + '\n';
    fs.appendFileSync(this.logFile, logLine);

    // 同时输出到控制台（便于调试）
    console.log('\n========================================');
    console.log('[JT808 Logger] 新数据捕获');
    console.log('========================================');
    console.log('时间: ' + entry.timestamp);
    console.log('方式: ' + entry.method + ' ' + entry.url);
    console.log('数据长度: ' + entry.body.length + ' bytes');
    console.log('Hex (前160字符): ' + entry.body.hex.substring(0, 160));

    // 如果是 JT808 位置上报，尝试解析
    if (entry.body.hex.startsWith('0200')) {
      console.log('');
      console.log('检测到 JT808 位置上报消息 (0x0200)');
      this.parseLocationReport(entry.body.hex);
    }

    console.log('========================================\n');
  }

  private parseLocationReport(hex: string): void {
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

      console.log('  终端手机号: ' + terminalPhone.toString());
      console.log('  纬度: ' + latDegrees.toFixed(8));
      console.log('  经度: ' + lonDegrees.toFixed(8));
      console.log('  海拔: ' + altitude + ' 米');
      console.log('  速度: ' + speed + ' km/h');
      console.log('  方向: ' + direction + '°');
    } catch (error) {
      console.log('  解析失败: ' + error);
    }
  }

  getStatistics(): any {
    return {
      totalEntries: this.logEntries.length,
      logFile: this.logFile,
      timeRange: {
        start: this.logEntries[0]?.timestamp,
        end: this.logEntries[this.logEntries.length - 1]?.timestamp,
      },
    };
  }
}

// 导出单例
export const jt808Logger = new JT808Logger();

// 如果直接运行此文件，显示使用说明
if (require.main === module) {
  console.log('\n========================================');
  console.log('JT808 数据记录中间件');
  console.log('========================================');
  console.log('');
  console.log('【使用方法】');
  console.log('');
  console.log('1. 在 Express 应用中使用：');
  console.log('   import { jt808Logger } from "./jt808-logger-middleware";');
  console.log('   app.use(jt808Logger.middleware());');
  console.log('');
  console.log('2. 在 Socket.IO 中使用：');
  console.log('   import { jt808Logger } from "./jt808-logger-middleware";');
  console.log('   io.on("connection", (socket) => {');
  console.log('     jt808Logger.socketMiddleware(socket);');
  console.log('   });');
  console.log('');
  console.log('3. 查看日志文件：');
  console.log('   tail -f logs/jt808-YYYY-MM-DD.log');
  console.log('');
  console.log('========================================\n');
}
