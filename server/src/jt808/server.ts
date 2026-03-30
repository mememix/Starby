/**
 * JT808协议服务器
 */

import * as net from 'net';
import { JT808Parser } from './parser';
import { JT808Encoder } from './encoder';
import { SessionManager } from './session-manager';
import {
  MessageId,
  GeneralResponseResult,
  RegisterResponseResult,
  LocationReportBody,
} from './types';

export interface JT808ServerOptions {
  port: number;
  host?: string;
  onLocationUpdate?: (phoneNumber: string, location: LocationReportBody) => void;
  onDeviceRegister?: (phoneNumber: string, authCode: string) => void;
}

export class JT808Server {
  private server: net.Server;
  private sessionManager: SessionManager;
  private options: JT808ServerOptions;
  private cleanupTimer?: NodeJS.Timeout;

  constructor(options: JT808ServerOptions) {
    this.options = {
      host: '0.0.0.0',
      ...options,
    };
    this.sessionManager = new SessionManager();
    this.server = net.createServer(this.handleConnection.bind(this));
  }

  /**
   * 启动服务器
   */
  start(): Promise<void> {
    return new Promise((resolve, reject) => {
      this.server.listen(this.options.port, this.options.host, () => {
        console.log(`[JT808] Server started on ${this.options.host}:${this.options.port}`);
        this.cleanupTimer = this.sessionManager.startCleanupTimer();
        resolve();
      });

      this.server.on('error', (error) => {
        console.error('[JT808] Server error:', error);
        reject(error);
      });
    });
  }

  /**
   * 停止服务器
   */
  stop(): Promise<void> {
    return new Promise((resolve) => {
      if (this.cleanupTimer) {
        clearInterval(this.cleanupTimer);
      }
      this.server.close(() => {
        console.log('[JT808] Server stopped');
        resolve();
      });
    });
  }

  /**
   * 处理新连接
   */
  private handleConnection(socket: net.Socket): void {
    const remoteAddress = `${socket.remoteAddress}:${socket.remotePort}`;
    console.log(`[JT808] New connection from ${remoteAddress}`);

    const parser = new JT808Parser();
    let phoneNumber: string | undefined;

    socket.on('data', (data) => {
      try {
        parser.addData(data);
        const messages = parser.parseMessages();

        for (const message of messages) {
          phoneNumber = message.header.phoneNumber;
          this.sessionManager.createOrUpdateSession(phoneNumber, socket);
          this.handleMessage(message, socket);
        }
      } catch (error) {
        console.error('[JT808] Error processing data:', error);
      }
    });

    socket.on('close', () => {
      console.log(`[JT808] Connection closed: ${remoteAddress}`);
      if (phoneNumber) {
        this.sessionManager.removeSession(phoneNumber);
      }
    });

    socket.on('error', (error) => {
      console.error(`[JT808] Connection error: ${remoteAddress}`, error);
    });
  }

  /**
   * 处理消息
   */
  private handleMessage(message: any, socket: net.Socket): void {
    const { header, body } = message;
    const { messageId, phoneNumber, messageSerialNo } = header;

    console.log(`[JT808] Received message: ID=0x${messageId.toString(16).padStart(4, '0')}, Phone=${phoneNumber}, Serial=${messageSerialNo}`);

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
        console.log(`[JT808] Unsupported message ID: 0x${messageId.toString(16)}`);
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
    this.sessionManager.updateHeartbeat(phoneNumber);
    this.sendGeneralResponse(phoneNumber, serialNo, MessageId.HEARTBEAT, GeneralResponseResult.SUCCESS, socket);
  }

  /**
   * 处理终端注册
   */
  private handleTerminalRegister(
    phoneNumber: string,
    serialNo: number,
    body: Buffer,
    socket: net.Socket
  ): void {
    const registerData = JT808Parser.parseTerminalRegister(body);
    console.log(`[JT808] Terminal register:`, registerData);

    // 生成鉴权码
    const authCode = this.generateAuthCode();

    // 设置会话状态
    this.sessionManager.setRegistered(phoneNumber, authCode);

    // 回调通知
    if (this.options.onDeviceRegister) {
      this.options.onDeviceRegister(phoneNumber, authCode);
    }

    // 发送注册应答
    const response = JT808Encoder.encodeTerminalRegisterResponse(
      phoneNumber,
      serialNo,
      RegisterResponseResult.SUCCESS,
      authCode
    );
    socket.write(response);
    console.log(`[JT808] Sent register response: authCode=${authCode}`);
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
    const authData = JT808Parser.parseTerminalAuth(body);
    console.log(`[JT808] Terminal auth: authCode=${authData.authCode}`);

    const session = this.sessionManager.getSession(phoneNumber);
    const result = session?.authCode === authData.authCode
      ? GeneralResponseResult.SUCCESS
      : GeneralResponseResult.FAILURE;

    this.sendGeneralResponse(phoneNumber, serialNo, MessageId.TERMINAL_AUTH, result, socket);
  }

  /**
   * 处理位置信息汇报
   */
  private handleLocationReport(
    phoneNumber: string,
    serialNo: number,
    body: Buffer,
    socket: net.Socket
  ): void {
    const location = JT808Parser.parseLocationReport(body);
    this.sessionManager.updateLocation(phoneNumber, location);

    // 回调通知
    if (this.options.onLocationUpdate) {
      this.options.onLocationUpdate(phoneNumber, location);
    }

    this.sendGeneralResponse(phoneNumber, serialNo, MessageId.LOCATION_REPORT, GeneralResponseResult.SUCCESS, socket);
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
    const response = JT808Encoder.encodeGeneralResponse(
      phoneNumber,
      responseSerialNo,
      responseMessageId,
      result
    );
    socket.write(response);
    console.log(`[JT808] Sent general response: result=${result}`);
  }

  /**
   * 生成鉴权码
   */
  private generateAuthCode(): string {
    return Math.random().toString(36).substring(2, 10).toUpperCase();
  }

  /**
   * 获取会话管理器
   */
  getSessionManager(): SessionManager {
    return this.sessionManager;
  }

  /**
   * 获取在线设备数
   */
  getOnlineCount(): number {
    return this.sessionManager.getOnlineCount();
  }
}
