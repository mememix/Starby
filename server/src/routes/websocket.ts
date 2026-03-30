import { Server as SocketIOServer, Socket } from 'socket.io';
import { Server as HTTPServer } from 'http';
import jwt from 'jsonwebtoken';

const JWT_SECRET = 'your-super-secret-jwt-key';

interface AuthenticatedSocket extends Socket {
  userId?: string;
}

/**
 * 设置WebSocket服务
 */
export function setupWebSocket(server: HTTPServer) {
  const io = new SocketIOServer(server, {
    cors: {
      origin: '*',
      credentials: true
    },
    path: '/ws'
  });

  // 认证中间件
  io.use(async (socket: any, next) => {
    try {
      const token = socket.handshake.auth.token || socket.handshake.query.token;

      if (!token) {
        return next(new Error('未提供认证令牌'));
      }

      const decoded = jwt.verify(token, JWT_SECRET) as any;
      socket.userId = decoded.userId;
      next();
    } catch (error) {
      next(new Error('无效的认证令牌'));
    }
  });

  io.on('connection', (socket: AuthenticatedSocket) => {
    console.log(`[WebSocket] 用户 ${socket.userId} 已连接`);

    // 加入用户专属房间
    socket.join(`user:${socket.userId}`);

    socket.on('disconnect', () => {
      console.log(`[WebSocket] 用户 ${socket.userId} 已断开`);
    });
  });

  return io;
}

// 全局WebSocket实例
let io: SocketIOServer | null = null;

export function getIO(): SocketIOServer | null {
  return io;
}

export function setIO(websocketServer: SocketIOServer) {
  io = websocketServer;
}

/**
 * 向用户发送位置更新通知
 */
export async function emitLocationUpdate(userId: string, data: any) {
  if (io) {
    io.to(`user:${userId}`).emit('location', {
      type: 'location',
      data,
      timestamp: new Date().toISOString()
    });
  }
}

/**
 * 向用户发送消息通知
 */
export async function emitMessage(userId: string, data: any) {
  if (io) {
    io.to(`user:${userId}`).emit('message', {
      type: 'message',
      data,
      timestamp: new Date().toISOString()
    });
  }
}

/**
 * 向用户发送SOS报警通知
 */
export async function emitSOSAlert(userId: string, data: any) {
  if (io) {
    io.to(`user:${userId}`).emit('sos', {
      type: 'sos',
      data,
      timestamp: new Date().toISOString()
    });
  }
}

/**
 * 向用户发送围栏进出通知
 */
export async function emitFenceAlert(userId: string, data: any) {
  if (io) {
    io.to(`user:${userId}`).emit('fence', {
      type: 'fence',
      data,
      timestamp: new Date().toISOString()
    });
  }
}

/**
 * 广播系统通知
 */
export async function emitSystemNotification(data: any) {
  if (io) {
    io.emit('system', {
      type: 'system',
      data,
      timestamp: new Date().toISOString()
    });
  }
}

export { SocketIOServer };
