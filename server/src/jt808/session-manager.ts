/**
 * JT808终端会话管理器
 */

import { TerminalSession, LocationReportBody } from './types';

export class SessionManager {
  private sessions: Map<string, TerminalSession> = new Map();
  private readonly HEARTBEAT_TIMEOUT = 5 * 60 * 1000; // 5分钟

  /**
   * 创建或更新会话
   */
  createOrUpdateSession(
    phoneNumber: string,
    socket: any
  ): TerminalSession {
    let session = this.sessions.get(phoneNumber);

    if (!session) {
      session = {
        phoneNumber,
        socket,
        registered: false,
        lastHeartbeat: new Date(),
      };
      this.sessions.set(phoneNumber, session);
      console.log(`[JT808] Session created: ${phoneNumber}`);
    } else {
      session.socket = socket;
      session.lastHeartbeat = new Date();
    }

    return session;
  }

  /**
   * 获取会话
   */
  getSession(phoneNumber: string): TerminalSession | undefined {
    return this.sessions.get(phoneNumber);
  }

  /**
   * 更新心跳
   */
  updateHeartbeat(phoneNumber: string): void {
    const session = this.sessions.get(phoneNumber);
    if (session) {
      session.lastHeartbeat = new Date();
      console.log(`[JT808] Heartbeat updated: ${phoneNumber}`);
    }
  }

  /**
   * 更新位置
   */
  updateLocation(phoneNumber: string, location: LocationReportBody): void {
    const session = this.sessions.get(phoneNumber);
    if (session) {
      session.lastLocation = location;
      console.log(`[JT808] Location updated: ${phoneNumber} at ${location.latDegrees.toFixed(6)}, ${location.lonDegrees.toFixed(6)}`);
    }
  }

  /**
   * 设置注册状态
   */
  setRegistered(phoneNumber: string, authCode: string): void {
    const session = this.sessions.get(phoneNumber);
    if (session) {
      session.registered = true;
      session.authCode = authCode;
      console.log(`[JT808] Terminal registered: ${phoneNumber}`);
    }
  }

  /**
   * 移除会话
   */
  removeSession(phoneNumber: string): void {
    this.sessions.delete(phoneNumber);
    console.log(`[JT808] Session removed: ${phoneNumber}`);
  }

  /**
   * 获取所有在线会话
   */
  getAllSessions(): TerminalSession[] {
    return Array.from(this.sessions.values());
  }

  /**
   * 获取在线设备数量
   */
  getOnlineCount(): number {
    return this.sessions.size;
  }

  /**
   * 清理超时会话
   */
  cleanupTimeoutSessions(): void {
    const now = Date.now();
    const toRemove: string[] = [];

    for (const [phoneNumber, session] of this.sessions) {
      if (now - session.lastHeartbeat.getTime() > this.HEARTBEAT_TIMEOUT) {
        toRemove.push(phoneNumber);
        console.log(`[JT808] Session timeout: ${phoneNumber}`);
      }
    }

    for (const phoneNumber of toRemove) {
      this.sessions.delete(phoneNumber);
    }
  }

  /**
   * 启动定时清理
   */
  startCleanupTimer(): NodeJS.Timeout {
    return setInterval(() => {
      this.cleanupTimeoutSessions();
    }, 60 * 1000); // 每分钟检查一次
  }
}
