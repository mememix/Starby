import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import http from 'http';
import dotenv from 'dotenv';
import { PrismaClient } from '@prisma/client';

dotenv.config();

const router = express.Router();
const app = express();
const prisma = new PrismaClient();
const server = http.createServer(app);

// ==================== 环境配置 ====================
const PORT = process.env.PORT || '3000';
const NODE_ENV = process.env.NODE_ENV || 'development';
const DATABASE_URL = process.env.DATABASE_URL || 'not configured';

console.log('\n========================================');
console.log('   星伙伴后端服务启动配置');
console.log('========================================\n');

console.log('【环境配置】');
console.log(`  环境模式: ${NODE_ENV}`);
console.log(`  端口: ${PORT}`);
console.log(`  当前目录: ${__dirname}`);
console.log(`  运行用户: ${process.env.USER || process.env.USERNAME || 'unknown'}`);

console.log('\n【数据库配置】');
console.log(`  数据库URL: ${DATABASE_URL.substring(0, 20)}...`);

// 隐藏敏感信息
const maskedDbUrl = DATABASE_URL.replace(/\/\/([^:]+):([^@]+)@/, '//***:**@');
console.log(`  隐藏后: ${maskedDbUrl}`);

console.log('\n【其他服务配置】');
console.log(`  JWT密钥: ${process.env.JWT_SECRET ? '已配置 (长度: ' + process.env.JWT_SECRET.length + ')' : '未配置'}`);
console.log(`  JWT过期时间: ${process.env.JWT_EXPIRES_IN || '未配置'}`);
console.log(`  Redis: ${process.env.REDIS_URL || '未配置'}`);
console.log(`  高德地图API Key: ${process.env.AMAP_API_KEY ? '已配置' : '未配置'}`);

// ==================== 中间件配置 ====================
console.log('\n【中间件配置】');

app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
    },
  },
}));

app.use(cors({
  origin: true,
  credentials: true,
}));

app.use(express.json({ limit: '10mb' })); // 增加请求体大小限制到10MB以支持大图片上传
app.use(express.urlencoded({ extended: true, limit: '10mb' })); // 同样增加URL编码数据的限制

if (NODE_ENV === 'development') {
  app.use(morgan('dev'));
  console.log('  ✅ Morgan日志: 已启用 (开发模式)');
}

console.log('  ✅ CORS: 已启用');
console.log('  ✅ Helmet: 已启用');
console.log('  ✅ Body Parser: 已启用');

// ==================== 数据库连接测试 ====================
console.log('\n【测试数据库连接】');

const initDatabase = async () => {
  try {
    await prisma.$connect();
    console.log('  ✅ 数据库连接成功');
  } catch (error: any) {
    console.error('  ❌ 数据库连接失败:', error.message);
    process.exit(1);
  }
};

initDatabase();

// ==================== 路由配置 ====================
console.log('\n【API路由配置】');

// 导入路由模块
import authRoutes from './routes/auth';
import deviceRoutes from './routes/devices';
import deviceSharesRoutes from './routes/deviceShares';
import fenceRoutes from './routes/fences';
import messageRoutes from './routes/messages';
import locationRoutes from './routes/location';
import checkinRoutes from './routes/checkin';
import uploadRoutes from './routes/upload';
import remoteUploadRoutes from './routes/remoteUpload';

// 注册路由
app.use('/api/auth', authRoutes);
console.log('  ✅ /api/auth             - 认证接口');

app.use('/api/devices', deviceRoutes);
console.log('  ✅ /api/devices          - 设备管理');

app.use('/api/devices', deviceSharesRoutes);
console.log('  ✅ /api/devices/shares   - 设备共享');

app.use('/api/fences', fenceRoutes);
console.log('  ✅ /api/fences           - 电子围栏');

app.use('/api/messages', messageRoutes);
console.log('  ✅ /api/messages         - 消息管理');

app.use('/api/location', locationRoutes);
console.log('  ✅ /api/location         - 位置服务');

app.use('/api/checkin', checkinRoutes);
console.log('  ✅ /api/checkin          - 打卡功能');

app.use('/api/upload', uploadRoutes);
console.log('  ✅ /api/upload           - 文件上传');

app.use('/api/remote-upload', remoteUploadRoutes);
console.log('  ✅ /api/remote-upload    - 远程文件上传API');

// ==================== 静态文件服务 ====================
const uploadsPath = '/Users/mememix/CodeBuddy/Starby/server/uploads';
app.use('/uploads', express.static(uploadsPath));
console.log('  ✅ /uploads              - 本地文件存储');

// ==================== 健康检查 ====================
app.get('/health', (req: any, res: any) => {
  res.json({
    status: 'ok',
    service: '星伙伴后端服务',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: NODE_ENV,
    version: '1.0.0'
  });
});

// 404处理
app.use((req: any, res: any) => {
  console.log(`\n[404] 未找到路由: ${req.method} ${req.path}`);
  res.status(404).json({
    success: false,
    message: `路由 ${req.path} 不存在`,
    path: req.path,
    method: req.method,
  });
});

// ==================== 错误处理 ====================
app.use((error: any, req: any, res: any, next: any) => {
  console.error('【错误】', error);
  res.status(500).json({
    success: false,
    message: error.message || '服务器内部错误',
    error: NODE_ENV === 'development' ? error.stack : undefined
  });
});

// ==================== WebSocket服务配置 ====================
console.log('\n【WebSocket服务配置】');
const WS_ENABLED = false; // 禁用本地WebSocket服务（使用远程的JT808服务）
console.log(`  WebSocket: ${WS_ENABLED ? '启用' : '禁用'} (使用远程JT808服务)`);
console.log(`  远程JT808服务: 116.204.117.57:7100`);

// ==================== 启动电池监控 ====================
console.log('\n【电池监控】');
const BATTERY_MONITOR_ENABLED = true;
console.log(`  电池监控: ${BATTERY_MONITOR_ENABLED ? '启用' : '禁用'}`);

if (BATTERY_MONITOR_ENABLED) {
  // 启动电池监控定时任务
  const { startBatteryMonitor } = require('./services/batteryMonitor');
  startBatteryMonitor();
  console.log('  低电量阈值: 20%');
  console.log('  检查间隔: 5分钟');
}

// ==================== 启动HTTP服务器 ====================
console.log('\n========================================');
console.log('   准备启动HTTP服务器...');
console.log('========================================\n');

server.listen(Number(PORT), '0.0.0.0', () => {
  console.log('\n========================================');
  console.log('✅ HTTP服务器启动成功!');
  console.log(`   端口: ${PORT}`);
  console.log(`   监听地址: 0.0.0.0 (所有网络接口)`);
  console.log(`   环境: ${NODE_ENV}`);
  console.log(`   本地访问: http://localhost:${PORT}/health`);
  console.log(`   模拟器访问: http://10.0.2.2:${PORT}/health\n`);
  console.log('========================================');
  console.log('   服务已就绪，开始接受请求...');
  console.log('========================================\n');
});

// ==================== 优雅关闭 ====================
const gracefulShutdown = async (signal: string) => {
  console.log('\n========================================');
  console.log(`   收到 ${signal} 信号，正在关闭服务...`);
  console.log('========================================');

  console.log('  停止HTTP服务器...');
  server.close(() => {
    console.log('  ✅ HTTP服务器已停止');
  });

  console.log('  关闭数据库连接...');
  await prisma.$disconnect();
  console.log('  ✅ 数据库连接已关闭');

  console.log('\n========================================');
  console.log('   所有服务已关闭');
  console.log('========================================\n');
  
  process.exit(0);
};

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

// 导出prisma实例供其他模块使用
export { prisma };

export default app;
