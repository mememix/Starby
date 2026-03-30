# JT808协议模块

## 概述

JT808协议模块实现了JT/T 808-2019道路运输车辆卫星定位系统终端通讯协议，支持终端注册、鉴权、位置汇报、心跳等核心功能。

## 功能特性

- ✅ JT808协议完整解析
- ✅ TCP服务器实现
- ✅ 终端会话管理
- ✅ 位置数据存储
- ✅ 与现有手机定位兼容
- ✅ 数据库集成

## 快速开始

### 1. 配置环境变量

在 `.env` 文件中添加：

```env
JT808_PORT=8080
```

### 2. 数据库迁移

```bash
cd server
npx prisma migrate dev
```

### 3. 启动服务

服务会随主应用自动启动，JT808服务器监听在8080端口。

## API接口

### 获取设备最新位置

```
GET /api/jt808/location/:phoneNumber
```

### 获取设备历史轨迹

```
GET /api/jt808/history/:phoneNumber?startTime=xxx&endTime=xxx
```

### JT808服务器状态

```
GET /api/jt808/status
```

## 支持的消息类型

| 消息ID | 名称 | 方向 |
|--------|------|------|
| 0x0002 | 心跳 | 终端→平台 |
| 0x0100 | 终端注册 | 终端→平台 |
| 0x0102 | 终端鉴权 | 终端→平台 |
| 0x0200 | 位置信息汇报 | 终端→平台 |
| 0x8001 | 通用应答 | 平台→终端 |
| 0x8100 | 终端注册应答 | 平台→终端 |

## 模块架构

```
src/jt808/
├── types.ts          # 类型定义
├── protocol.ts       # 协议工具类
├── parser.ts         # 消息解析器
├── encoder.ts        # 消息编码器
├── server.ts         # TCP服务器
├── session-manager.ts # 会话管理
├── storage.ts        # 数据存储
├── index.ts          # 模块入口
└── README.md         # 文档
```

## 数据库设计

### devices表新增字段

- `phoneNumber`: JT808设备手机号
- `deviceType`: 设备类型 (mobile/JT808)
- `isOnline`: 在线状态
- `authCode`: 鉴权码
- `manufacturerId`: 制造商ID
- `terminalModel`: 终端型号
- `lastLatitude/lastLongitude`: 最后位置

### locations表新增字段

- `source`: 数据源 (mobile/JT808)
- `altitude`: 海拔
- `speed`: 速度
- `direction`: 方向
- JT808报警和状态标志

## 测试

### 使用客户端模拟器

```bash
# 启动JT808服务器
npm run jt808

# 运行客户端模拟器
npx ts-node src/jt808/client-simulator.ts
```

### 使用JT808设备模拟器

使用JT808设备模拟器连接到 `tcp://localhost:8080` 进行测试。

## 开发进度

- ✅ Phase 1: 协议解析核心 (4小时)
- ✅ Phase 2: 核心消息处理 (6小时)
- ✅ Phase 3: TCP服务器 (4小时)
- ✅ Phase 4: 位置数据处理 (4小时)
- ⏳ Phase 5: 集成测试 (4小时)
- ⏳ Phase 6: 优化与完善 (4小时)

**总计**: 约30小时开发时间

## 注意事项

1. 保留现有手机定位功能，两套系统并行
2. JT808端口默认8080，可通过环境变量修改
3. 设备超时时间5分钟，超时自动清理会话
4. 位置数据同时支持手机和JT808两种来源
