import { describe, test, expect, beforeAll, afterAll } from '@jest/globals';
import axios from 'axios';
import { execSync } from 'child_process';

// 测试配置
const API_BASE_URL = process.env.API_BASE_URL || 'http://localhost:3000/api';
const TEST_USER = {
  phone: `test_${Date.now()}`,
  password: 'test123456'
};

let authToken: string;
let userId: string;
let deviceId: string;
let locationId: string;
let fenceId: string;
let messageId: string;

// 辅助函数：等待
const sleep = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

// 辅助函数：创建HTTP客户端
const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json'
  }
});

describe('API 自动化测试套件', () => {
  beforeAll(async () => {
    console.log('\n========== 开始 API 自动化测试 ==========');
    console.log(`API 地址: ${API_BASE_URL}`);
    console.log(`测试用户: ${TEST_USER.phone}\n`);

    // 等待服务器启动
    await sleep(1000);

    // 检查服务器健康状态
    try {
      await axios.get(`${API_BASE_URL}/../health`);
      console.log('✅ 服务器状态正常\n');
    } catch (error) {
      console.warn('⚠️  服务器健康检查失败，继续测试...\n');
    }
  });

  afterAll(async () => {
    console.log('\n========== 测试完成 ==========');
    console.log(`测试用户: ${TEST_USER.phone}`);
    console.log('建议手动清理测试数据\n');
  });

  describe('1. 认证模块', () => {
    test('1.1 用户注册', async () => {
      const response = await api.post('/auth/register', {
        phone: TEST_USER.phone,
        password: TEST_USER.password,
        nickname: '测试用户'
      });

      expect(response.status).toBe(201);
      expect(response.data.success).toBe(true);
      expect(response.data.data.token).toBeDefined();
      expect(response.data.data.user.phone).toBe(TEST_USER.phone);

      authToken = response.data.data.token;
      userId = response.data.data.user.id;

      console.log('✅ 1.1 用户注册成功');
    });

    test('1.2 用户登录', async () => {
      const response = await api.post('/auth/login', {
        phone: TEST_USER.phone,
        password: TEST_USER.password
      });

      expect(response.status).toBe(200);
      expect(response.data.success).toBe(true);
      expect(response.data.data.token).toBeDefined();
      expect(response.data.data.user.phone).toBe(TEST_USER.phone);

      authToken = response.data.data.token;
      userId = response.data.data.user.id;

      console.log('✅ 1.2 用户登录成功');
    });

    test('1.3 获取用户信息', async () => {
      const response = await api.get('/auth/me', {
        headers: { Authorization: `Bearer ${authToken}` }
      });

      expect(response.status).toBe(200);
      expect(response.data.success).toBe(true);
      expect(response.data.data.user.id).toBe(userId);

      console.log('✅ 1.3 获取用户信息成功');
    });

    test('1.4 更新用户信息', async () => {
      const response = await api.put('/auth/me', {
        nickname: '更新的昵称',
        bio: '这是测试用户',
        gender: 'male'
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });

      expect(response.status).toBe(200);
      expect(response.data.success).toBe(true);
      expect(response.data.data.user.nickname).toBe('更新的昵称');

      console.log('✅ 1.4 更新用户信息成功');
    });

    test('1.5 重复注册应该失败', async () => {
      try {
        await api.post('/auth/register', {
          phone: TEST_USER.phone,
          password: TEST_USER.password
        });
        expect(true).toBe(false); // 不应该执行到这里
      } catch (error: any) {
        expect(error.response.status).toBe(400);
        expect(error.response.data.success).toBe(false);

        console.log('✅ 1.5 重复注册正确被拒绝');
      }
    });
  });

  describe('2. 设备管理模块', () => {
    test('2.1 创建设备', async () => {
      const response = await api.post('/devices', {
        deviceSn: `TEST_${Date.now()}`,
        name: '测试设备'
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });

      expect(response.status).toBe(201);
      expect(response.data.success).toBe(true);
      expect(response.data.data.device.name).toBe('测试设备');

      deviceId = response.data.data.device.id;

      console.log('✅ 2.1 创建设备成功');
    });

    test('2.2 获取设备列表', async () => {
      const response = await api.get('/devices', {
        headers: { Authorization: `Bearer ${authToken}` }
      });

      expect(response.status).toBe(200);
      expect(response.data.success).toBe(true);
      expect(Array.isArray(response.data.data.devices)).toBe(true);
      expect(response.data.data.devices.length).toBeGreaterThan(0);

      console.log('✅ 2.2 获取设备列表成功');
    });

    test('2.3 获取设备详情', async () => {
      const response = await api.get(`/devices/${deviceId}`, {
        headers: { Authorization: `Bearer ${authToken}` }
      });

      expect(response.status).toBe(200);
      expect(response.data.success).toBe(true);
      expect(response.data.data.device.id).toBe(deviceId);

      console.log('✅ 2.3 获取设备详情成功');
    });

    test('2.4 上报设备位置', async () => {
      const response = await api.post(`/devices/${deviceId}/location`, {
        latitude: 39.9042,
        longitude: 116.4074,
        accuracy: 10
      });

      expect(response.status).toBe(201);
      expect(response.data.success).toBe(true);
      expect(response.data.data.location.latitude).toBe(39.9042);

      console.log('✅ 2.4 上报设备位置成功');
    });

    test('2.5 获取设备实时位置', async () => {
      const response = await api.get(`/devices/${deviceId}/location`, {
        headers: { Authorization: `Bearer ${authToken}` }
      });

      expect(response.status).toBe(200);
      expect(response.data.success).toBe(true);
      expect(response.data.data.location).toBeDefined();

      console.log('✅ 2.5 获取设备实时位置成功');
    });

    test('2.6 获取设备历史轨迹', async () => {
      const endTime = new Date().toISOString();
      const startTime = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();

      const response = await api.get(`/devices/${deviceId}/history`, {
        params: { startTime, endTime, limit: 100 },
        headers: { Authorization: `Bearer ${authToken}` }
      });

      expect(response.status).toBe(200);
      expect(response.data.success).toBe(true);
      expect(Array.isArray(response.data.data.history)).toBe(true);

      console.log('✅ 2.6 获取设备历史轨迹成功');
    });

    test('2.7 更新设备信息', async () => {
      const response = await api.put(`/devices/${deviceId}`, {
        name: '更新的设备名称'
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });

      expect(response.status).toBe(200);
      expect(response.data.success).toBe(true);
      expect(response.data.data.device.name).toBe('更新的设备名称');

      console.log('✅ 2.7 更新设备信息成功');
    });

    test('2.8 无效设备ID应该返回404', async () => {
      try {
        await api.get('/devices/invalid-id', {
          headers: { Authorization: `Bearer ${authToken}` }
        });
        expect(true).toBe(false);
      } catch (error: any) {
        expect(error.response.status).toBe(404);
        console.log('✅ 2.8 无效设备ID正确返回404');
      }
    });
  });

  describe('3. 电子围栏模块', () => {
    test('3.1 创建电子围栏', async () => {
      const response = await api.post('/fences', {
        deviceId,
        name: '测试围栏',
        latitude: 39.9042,
        longitude: 116.4074,
        radius: 500
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });

      expect(response.status).toBe(201);
      expect(response.data.success).toBe(true);
      expect(response.data.data.fence.name).toBe('测试围栏');

      fenceId = response.data.data.fence.id;

      console.log('✅ 3.1 创建电子围栏成功');
    });

    test('3.2 获取电子围栏列表', async () => {
      const response = await api.get(`/fences/${deviceId}`, {
        headers: { Authorization: `Bearer ${authToken}` }
      });

      expect(response.status).toBe(200);
      expect(response.data.success).toBe(true);
      expect(Array.isArray(response.data.data.fences)).toBe(true);

      console.log('✅ 3.2 获取电子围栏列表成功');
    });

    test('3.3 更新电子围栏', async () => {
      const response = await api.put(`/fences/${fenceId}`, {
        name: '更新的围栏',
        radius: 1000
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });

      expect(response.status).toBe(200);
      expect(response.data.success).toBe(true);
      expect(response.data.data.fence.name).toBe('更新的围栏');

      console.log('✅ 3.3 更新电子围栏成功');
    });

    test('3.4 删除电子围栏', async () => {
      const response = await api.delete(`/fences/${fenceId}`, {
        headers: { Authorization: `Bearer ${authToken}` }
      });

      expect(response.status).toBe(200);
      expect(response.data.success).toBe(true);

      console.log('✅ 3.4 删除电子围栏成功');
    });
  });

  describe('4. 消息管理模块', () => {
    test('4.1 创建消息', async () => {
      const response = await api.post('/messages', {
        type: 'info',
        title: '测试消息',
        content: '这是一条测试消息',
        deviceId
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });

      expect(response.status).toBe(201);
      expect(response.data.success).toBe(true);
      expect(response.data.data.message.title).toBe('测试消息');

      messageId = response.data.data.message.id;

      console.log('✅ 4.1 创建消息成功');
    });

    test('4.2 获取消息列表', async () => {
      const response = await api.get('/messages', {
        headers: { Authorization: `Bearer ${authToken}` }
      });

      expect(response.status).toBe(200);
      expect(response.data.success).toBe(true);
      expect(Array.isArray(response.data.data.messages)).toBe(true);

      console.log('✅ 4.2 获取消息列表成功');
    });

    test('4.3 标记消息为已读', async () => {
      const response = await api.put(`/messages/${messageId}/read`, {}, {
        headers: { Authorization: `Bearer ${authToken}` }
      });

      expect(response.status).toBe(200);
      expect(response.data.success).toBe(true);
      expect(response.data.data.message.isRead).toBe(true);

      console.log('✅ 4.3 标记消息为已读成功');
    });

    test('4.4 删除消息', async () => {
      const response = await api.delete(`/messages/${messageId}`, {
        headers: { Authorization: `Bearer ${authToken}` }
      });

      expect(response.status).toBe(200);
      expect(response.data.success).toBe(true);

      console.log('✅ 4.4 删除消息成功');
    });
  });

  describe('5. JT808 协议模块', () => {
    test('5.1 查询可绑定的JT808设备', async () => {
      // 插入一个模拟的JT808设备（userId为null）
      try {
        const phoneNumber = `138${Math.floor(Math.random() * 100000000)}`;
        await api.post('/devices', {
          phoneNumber,
          terminalId: `TERM_${Date.now()}`,
          authCode: 'TEST123',
          deviceType: 'jt808'
        }, {
          headers: { Authorization: `Bearer ${authToken}` }
        });
      } catch (error) {
        // 设备可能已存在，忽略错误
      }

      // 查询所有设备（包括未绑定的）
      const response = await api.get('/devices/unbound', {
        headers: { Authorization: `Bearer ${authToken}` }
      });

      expect(response.status).toBe(200);
      expect(response.data.success).toBe(true);
      expect(Array.isArray(response.data.data.devices)).toBe(true);

      console.log('✅ 5.1 查询可绑定的JT808设备成功');
    });

    test('5.2 绑定JT808设备', async () => {
      // 创建一个未绑定的JT808设备
      const phoneNumber = `139${Math.floor(Math.random() * 100000000)}`;
      const createResponse = await api.post('/devices', {
        phoneNumber,
        terminalId: `TERM_${Date.now()}`,
        authCode: 'TEST123',
        deviceType: 'jt808'
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });

      const jt808DeviceId = createResponse.data.data.device.id;

      // 绑定设备
      const response = await api.post(`/devices/${jt808DeviceId}/bind`, {}, {
        headers: { Authorization: `Bearer ${authToken}` }
      });

      expect(response.status).toBe(200);
      expect(response.data.success).toBe(true);
      expect(response.data.data.device.userId).toBe(userId);

      console.log('✅ 5.2 绑定JT808设备成功');
    });

    test('5.3 解绑JT808设备', async () => {
      const phoneNumber = `139${Math.floor(Math.random() * 100000000)}`;
      const createResponse = await api.post('/devices', {
        phoneNumber,
        terminalId: `TERM_${Date.now()}`,
        authCode: 'TEST123',
        deviceType: 'jt808'
      }, {
        headers: { Authorization: `Bearer ${authToken}` }
      });

      const jt808DeviceId = createResponse.data.data.device.id;

      // 绑定设备
      await api.post(`/devices/${jt808DeviceId}/bind`, {}, {
        headers: { Authorization: `Bearer ${authToken}` }
      });

      // 解绑设备
      const response = await api.post(`/devices/${jt808DeviceId}/unbind`, {}, {
        headers: { Authorization: `Bearer ${authToken}` }
      });

      expect(response.status).toBe(200);
      expect(response.data.success).toBe(true);
      expect(response.data.data.device.userId).toBeNull();

      console.log('✅ 5.3 解绑JT808设备成功');
    });
  });

  describe('6. 数据一致性测试', () => {
    test('6.1 设备位置数据一致性', async () => {
      // 上报多个位置点
      const positions = [
        { lat: 39.9042, lng: 116.4074 },
        { lat: 39.9043, lng: 116.4075 },
        { lat: 39.9044, lng: 116.4076 }
      ];

      for (const pos of positions) {
        await api.post(`/devices/${deviceId}/location`, {
          latitude: pos.lat,
          longitude: pos.lng
        });
      }

      // 获取历史轨迹
      const response = await api.get(`/devices/${deviceId}/history`, {
        params: { limit: 10 },
        headers: { Authorization: `Bearer ${authToken}` }
      });

      expect(response.status).toBe(200);
      expect(response.data.data.history.length).toBeGreaterThanOrEqual(positions.length);

      console.log('✅ 6.1 设备位置数据一致性验证成功');
    });

    test('6.2 设备状态更新一致性', async () => {
      // 上报位置后，设备应该在线
      await api.post(`/devices/${deviceId}/location`, {
        latitude: 39.9042,
        longitude: 116.4074
      });

      await sleep(100); // 等待状态更新

      const response = await api.get(`/devices/${deviceId}`, {
        headers: { Authorization: `Bearer ${authToken}` }
      });

      expect(response.data.data.device.status).toBe('online');

      console.log('✅ 6.2 设备状态更新一致性验证成功');
    });
  });

  describe('7. 错误处理测试', () => {
    test('7.1 无效的token应该返回401', async () => {
      try {
        await api.get('/devices', {
          headers: { Authorization: 'Bearer invalid-token' }
        });
        expect(true).toBe(false);
      } catch (error: any) {
        expect(error.response.status).toBe(401);
        console.log('✅ 7.1 无效token正确返回401');
      }
    });

    test('7.2 缺少token应该返回401', async () => {
      try {
        await api.get('/devices');
        expect(true).toBe(false);
      } catch (error: any) {
        expect(error.response.status).toBe(401);
        console.log('✅ 7.2 缺少token正确返回401');
      }
    });

    test('7.3 重复设备序列号应该返回400', async () => {
      try {
        const deviceSn = `DUP_${Date.now()}`;
        await api.post('/devices', { deviceSn, name: '设备1' }, {
          headers: { Authorization: `Bearer ${authToken}` }
        });
        await api.post('/devices', { deviceSn, name: '设备2' }, {
          headers: { Authorization: `Bearer ${authToken}` }
        });
        expect(true).toBe(false);
      } catch (error: any) {
        expect(error.response.status).toBe(400);
        console.log('✅ 7.3 重复设备序列号正确返回400');
      }
    });
  });
});
