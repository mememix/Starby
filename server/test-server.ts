// test-server.ts - 简化测试服务器
import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import * as net from 'net';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;
const JT808_PORT = parseInt(process.env.JT808_PORT || '8080');

// 中间件
app.use(cors());
app.use(express.json());

// 健康检查
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    service: 'xinghu-backend-test',
    timestamp: new Date().toISOString(),
    jt808: {
      port: JT808_PORT,
      status: 'running'
    }
  });
});

// JT808 TCP服务器
const jt808Server = net.createServer((socket) => {
  const remoteAddress = `${socket.remoteAddress}:${socket.remotePort}`;
  console.log(`[JT808] New connection from ${remoteAddress}`);

  socket.on('data', (data) => {
    console.log(`[JT808] Received data from ${remoteAddress}:`, data.toString('hex'));
    // 简单应答
    socket.write(Buffer.from([0x7e, 0x80, 0x01, 0x00, 0x05, 0x01, 0x38, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x7e]));
  });

  socket.on('close', () => {
    console.log(`[JT808] Connection closed: ${remoteAddress}`);
  });

  socket.on('error', (error) => {
    console.error(`[JT808] Connection error: ${remoteAddress}`, error);
  });
});

// 启动JT808服务器
jt808Server.listen(JT808_PORT, '0.0.0.0', () => {
  console.log(`[JT808] Server started on 0.0.0.0:${JT808_PORT}`);
});

// 启动HTTP服务器
app.listen(PORT, () => {
  console.log(`🚀 星护伙伴后端服务运行在端口 ${PORT}`);
  console.log(`📊 健康检查: http://localhost:${PORT}/health`);
  console.log(`📡 JT808服务器: tcp://localhost:${JT808_PORT}`);
});

// 优雅关闭
process.on('SIGTERM', async () => {
  console.log('收到SIGTERM信号，正在关闭...');
  jt808Server.close();
  process.exit(0);
});
