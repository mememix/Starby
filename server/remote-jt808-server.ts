/**
 * JT808 数据监听服务器启动脚本
 * 部署在远程服务器 116.204.117.57 上
 * 监听本服务器的 7100 端口,接收 JT808 协议数据并存储到本地开发数据库
 *
 * 数据流向: 远程设备推送 → 116.204.117.57:7100 → 监听服务 → starby-dev 数据库 (同一服务器)
 */

import dotenv from 'dotenv';
import { RemoteJT808Server } from './src/jt808/remote-server';

// 加载环境变量
dotenv.config();

// JT808 监听配置
const JT808_HOST = '0.0.0.0'; // 监听所有网络接口
const JT808_PORT = parseInt(process.env.JT808_PORT || '7100', 10);

// 创建 JT808 监听服务器
const jt808Server = new RemoteJT808Server({
  host: JT808_HOST,
  port: JT808_PORT,
  onLocationUpdate: (phoneNumber: string, location: any) => {
    console.log(`[事件] 📍 位置更新: ${phoneNumber}`);
  },
  onDeviceRegister: (phoneNumber: string, authCode: string) => {
    console.log(`[事件] 📱 设备注册: ${phoneNumber}, authCode: ${authCode}`);
  },
  onError: (error: Error) => {
    console.error(`[事件] ❌ 错误: ${error.message}`);
  },
});

// 启动服务器
async function startServer() {
  try {
    console.log('\n========================================');
    console.log('启动 JT808 数据监听服务器');
    console.log('========================================\n');

    await jt808Server.start();

    console.log(`✅ 服务器运行中,监听 ${JT808_PORT} 端口`);
    console.log(`   部署位置: 远程服务器 116.204.117.57`);
    console.log(`   监听地址: ${JT808_HOST}:${JT808_PORT}`);
    console.log(`   数据库: starby-dev (本地 3307)`);
    console.log(`   按 Ctrl+C 停止\n`);

    // 优雅关闭
    process.on('SIGINT', async () => {
      console.log('\n\n收到停止信号,正在关闭服务器...');
      await remoteJT808Server.stop();
      process.exit(0);
    });

    process.on('SIGTERM', async () => {
      console.log('\n\n收到终止信号,正在关闭服务器...');
      await remoteJT808Server.stop();
      process.exit(0);
    });
  } catch (error) {
    console.error('❌ 启动失败:', error);
    process.exit(1);
  }
}

// 启动
startServer();
