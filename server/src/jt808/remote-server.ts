/**
 * 远程 JT808 数据监听服务
 * 监听 116.204.117.57:7100 端口,接收 JT808 协议数据并存储到开发数据库
 */

import * as net from 'net';
import { JT808Parser } from './parser';
import { JT808Encoder } from './encoder';
import { JT808Storage } from './storage';
import { MessageId, GeneralResponseResult, LocationReportBody } from './types';

interface RemoteJT808ServerOptions {
  port: number;
  host: string;
  onLocationUpdate?: (phoneNumber: string, location: LocationReportBody) => void;
  onDeviceRegister?: (phoneNumber: string, authCode: string) => void;
  onError?: (error: Error) => void;
}

export class RemoteJT808Server {
  private server: net.Server;
  private options: RemoteJT808ServerOptions;
  private connections: Map<string, net.Socket>;
  private statistics: {
    totalConnections: number;
    currentConnections: number;
    messagesReceived: number;
    locationsSaved: number;
    errors: number;
  };

  constructor(options: RemoteJT808ServerOptions) {
    this.options = options;
    this.server = net.createServer(this.handleConnection.bind(this));
    this.connections = new Map();
    this.statistics = {
      totalConnections: 0,
      currentConnections: 0,
      messagesReceived: 0,
      locationsSaved: 0,
      errors: 0,
    };
  }

  /**
   * 启动服务器
   */
  start(): Promise<void> {
    return new Promise((resolve, reject) => {
      this.server.listen(this.options.port, this.options.host, () => {
        console.log('\n========================================');
        console.log('📡 远程 JT808 监听服务启动成功');
        console.log('========================================');
        console.log(`监听地址: ${this.options.host}:${this.options.port}`);
        console.log(`监听接口: 0.0.0.0 (所有网络接口)`);
        console.log('数据库: starby-dev (开发数据库)');
        console.log('========================================\n');
        resolve();
      });

      this.server.on('error', (error) => {
        console.error('[远程 JT808] 服务器错误:', error);
        this.statistics.errors++;
        if (this.options.onError) {
          this.options.onError(error);
        }
        reject(error);
      });

      // 定期打印统计信息
      setInterval(() => this.printStatistics(), 60000); // 每分钟打印一次
    });
  }

  /**
   * 停止服务器
   */
  stop(): Promise<void> {
    return new Promise((resolve) => {
      console.log('\n[远程 JT808] 正在停止服务器...');
      this.server.close(() => {
        console.log('[远程 JT808] 服务器已停止');
        this.printStatistics();
        resolve();
      });
    });
  }

  /**
   * 处理新连接
   */
  private handleConnection(socket: net.Socket): void {
    const connectionId = `${socket.remoteAddress}:${socket.remotePort}`;
    this.connections.set(connectionId, socket);
    this.statistics.totalConnections++;
    this.statistics.currentConnections++;

    console.log(`\n[远程 JT808] 🔌 新连接: ${connectionId}`);
    console.log(`[远程 JT808] 当前连接数: ${this.statistics.currentConnections}\n`);

    const parser = new JT808Parser();
    let phoneNumber: string | undefined;

    socket.on('data', (data) => {
      try {
        parser.addData(data);
        const messages = parser.parseMessages();

        for (const message of messages) {
          phoneNumber = message.header.phoneNumber;
          this.statistics.messagesReceived++;
          this.handleMessage(message, socket);
        }
      } catch (error) {
        console.error('[远程 JT808] 数据处理错误:', error);
        this.statistics.errors++;
      }
    });

    socket.on('close', () => {
      console.log(`[远程 JT808] 🔌 连接关闭: ${connectionId}`);
      this.connections.delete(connectionId);
      this.statistics.currentConnections--;
    });

    socket.on('error', (error) => {
      console.error(`[远程 JT808] 连接错误: ${connectionId}`, error);
      this.statistics.errors++;
      this.connections.delete(connectionId);
      this.statistics.currentConnections--;
    });

    socket.on('timeout', () => {
      console.warn(`[远程 JT808] 连接超时: ${connectionId}`);
      socket.destroy();
    });

    // 设置超时时间为 5 分钟
    socket.setTimeout(5 * 60 * 1000);
  }

  /**
   * 处理消息
   */
  private handleMessage(message: any, socket: net.Socket): void {
    const { header, body } = message;
    const { messageId, phoneNumber, messageSerialNo } = header;

    const timestamp = new Date().toISOString();
    console.log(`[${timestamp}] [远程 JT808] 📨 消息: ID=0x${messageId.toString(16).padStart(4, '0')}, Phone=${phoneNumber}, Serial=${messageSerialNo}`);

    switch (messageId) {
      case MessageId.HEARTBEAT:
        this.handleHeartbeat(phoneNumber, messageSerialNo, socket);
        break;
      case MessageId.TERMINAL_REGISTER:
        this.handleTerminalRegister(phoneNumber, messageSerialNo, body, socket);
        break;
      case MessageId.TERMINAL_AUTH:
        this.handleTerminalAuth(phoneNumber, messageSerialNo, body, socket);
        break;
      case MessageId.LOCATION_REPORT:
        this.handleLocationReport(phoneNumber, messageSerialNo, body, socket);
        break;
      default:
        console.log(`[远程 JT808] ⚠️  未支持的消息 ID: 0x${messageId.toString(16).padStart(4, '0')}`);
        this.sendGeneralResponse(phoneNumber, messageSerialNo, messageId, GeneralResponseResult.UNSUPPORTED, socket);
    }
  }

  /**
   * 处理心跳
   */
  private handleHeartbeat(
    phoneNumber: string,
    serialNo: number,
    socket: net.Socket
  ): void {
    this.sendGeneralResponse(phoneNumber, serialNo, MessageId.HEARTBEAT, GeneralResponseResult.SUCCESS, socket);
    // 不存储心跳,仅记录日志
  }

  /**
   * 处理终端注册
   */
  private async handleTerminalRegister(
    phoneNumber: string,
    serialNo: number,
    body: Buffer,
    socket: net.Socket
  ): Promise<void> {
    try {
      const registerData = JT808Parser.parseTerminalRegister(body);
      console.log(`[远程 JT808] 📱 终端注册:`, {
        phoneNumber,
        manufacturerId: registerData.manufacturerId,
        terminalModel: registerData.terminalModel,
        terminalId: registerData.terminalId,
        licensePlate: registerData.licensePlate,
      });

      // 生成鉴权码
      const authCode = this.generateAuthCode();

      // 存储设备信息
      await JT808Storage.saveDevice(phoneNumber, authCode, registerData);

      // 回调通知
      if (this.options.onDeviceRegister) {
        this.options.onDeviceRegister(phoneNumber, authCode);
      }

      // 发送注册应答
      const response = JT808Encoder.encodeTerminalRegisterResponse(
        phoneNumber,
        serialNo,
        0, // 成功
        authCode
      );
      socket.write(response);
      console.log(`[远程 JT808] ✅ 发送注册应答: authCode=${authCode}\n`);
    } catch (error) {
      console.error('[远程 JT808] ❌ 注册处理失败:', error);
      this.statistics.errors++;
    }
  }

  /**
   * 处理终端鉴权
   */
  private handleTerminalAuth(
    phoneNumber: string,
    serialNo: number,
    body: Buffer,
    socket: net.Socket
  ): void {
    try {
      const authData = JT808Parser.parseTerminalAuth(body);
      console.log(`[远程 JT808] 🔐 终端鉴权: ${phoneNumber}, authCode=${authData.authCode}`);

      // 鉴权成功
      const response = JT808Encoder.encodeGeneralResponse(
        phoneNumber,
        serialNo,
        MessageId.TERMINAL_AUTH,
        GeneralResponseResult.SUCCESS
      );
      socket.write(response);
      console.log(`[远程 JT808] ✅ 鉴权成功\n`);

      // 更新设备在线状态
      JT808Storage.updateOnlineStatus(phoneNumber, true).catch(err => {
        console.error('[远程 JT808] 更新在线状态失败:', err);
      });
    } catch (error) {
      console.error('[远程 JT808] ❌ 鉴权处理失败:', error);
      this.statistics.errors++;
    }
  }

  /**
   * 处理位置信息汇报
   */
  private async handleLocationReport(
    phoneNumber: string,
    serialNo: number,
    body: Buffer,
    socket: net.Socket
  ): Promise<void> {
    try {
      const location = JT808Parser.parseLocationReport(body);
      console.log(`[远程 JT808] 📍 位置报告:`, {
        phoneNumber,
        lat: location.latDegrees.toFixed(6),
        lon: location.lonDegrees.toFixed(6),
        speed: location.speed,
        direction: location.direction,
        time: location.time,
      });

      // 存储位置信息
      await JT808Storage.saveLocation(phoneNumber, location);
      this.statistics.locationsSaved++;

      // 回调通知
      if (this.options.onLocationUpdate) {
        this.options.onLocationUpdate(phoneNumber, location);
      }

      // 发送应答
      const response = JT808Encoder.encodeGeneralResponse(
        phoneNumber,
        serialNo,
        MessageId.LOCATION_REPORT,
        GeneralResponseResult.SUCCESS
      );
      socket.write(response);
      console.log(`[远程 JT808] ✅ 位置已保存 (${this.statistics.locationsSaved})\n`);
    } catch (error) {
      console.error('[远程 JT808] ❌ 位置处理失败:', error);
      this.statistics.errors++;
    }
  }

  /**
   * 发送通用应答
   */
  private sendGeneralResponse(
    phoneNumber: string,
    responseSerialNo: number,
    responseMessageId: number,
    result: GeneralResponseResult,
    socket: net.Socket
  ): void {
    try {
      const response = JT808Encoder.encodeGeneralResponse(
        phoneNumber,
        responseSerialNo,
        responseMessageId,
        result
      );
      socket.write(response);
    } catch (error) {
      console.error('[远程 JT808] 发送应答失败:', error);
    }
  }

  /**
   * 生成鉴权码
   */
  private generateAuthCode(): string {
    return Math.random().toString(36).substring(2, 10).toUpperCase();
  }

  /**
   * 打印统计信息
   */
  private printStatistics(): void {
    console.log('\n========================================');
    console.log('📊 远程 JT808 服务统计');
    console.log('========================================');
    console.log(`总连接数: ${this.statistics.totalConnections}`);
    console.log(`当前连接数: ${this.statistics.currentConnections}`);
    console.log(`消息接收数: ${this.statistics.messagesReceived}`);
    console.log(`位置保存数: ${this.statistics.locationsSaved}`);
    console.log(`错误数量: ${this.statistics.errors}`);
    console.log('========================================\n');
  }

  /**
   * 获取统计信息
   */
  getStatistics() {
    return { ...this.statistics };
  }

  /**
   * 获取当前连接数
   */
  getCurrentConnections(): number {
    return this.statistics.currentConnections;
  }
}
