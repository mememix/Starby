/**
 * JT808服务器测试
 */

import { JT808Server } from './server';
import { JT808Storage } from './storage';

// 创建测试服务器
const server = new JT808Server({
  port: 8080,
  host: '0.0.0.0',
  onLocationUpdate: async (phoneNumber, location) => {
    console.log('📍 位置更新:', phoneNumber, location);
    await JT808Storage.saveLocation(phoneNumber, location);
  },
  onDeviceRegister: async (phoneNumber, authCode) => {
    console.log('🔐 设备注册:', phoneNumber, authCode);
    await JT808Storage.saveDevice(phoneNumber, authCode);
  },
});

// 启动服务器
server.start().then(() => {
  console.log('✅ JT808测试服务器启动成功！');
  console.log('📡 监听端口: 8080');
  console.log('');
  console.log('测试方法:');
  console.log('1. 使用JT808设备模拟器连接');
  console.log('2. 或使用telnet测试: telnet localhost 8080');
  console.log('');
}).catch((error) => {
  console.error('❌ 服务器启动失败:', error);
});

// 优雅关闭
process.on('SIGINT', async () => {
  console.log('\n正在关闭服务器...');
  await server.stop();
  process.exit(0);
});

process.on('SIGTERM', async () => {
  console.log('\n正在关闭服务器...');
  await server.stop();
  process.exit(0);
});
