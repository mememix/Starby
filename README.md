# Starby - 定位追踪设备管理平台

## 项目简介

Starby 是一个完整的定位追踪设备管理系统，包含移动端 App、管理后台和后端服务。系统支持设备实时定位、历史轨迹回放、电子围栏、设备绑定等功能。

## 项目结构

```
Starby/
├── lib/                    # Flutter 移动端应用（用户 App）
│   ├── screens/           # 页面组件
│   ├── widgets/           # 自定义组件
│   ├── models/            # 数据模型
│   ├── services/          # 业务服务
│   └── ...
├── server/                # Node.js 后端服务
│   ├── src/
│   │   ├── config/       # 配置文件
│   │   ├── jt808/        # JT808 协议处理
│   │   ├── lib/          # Prisma ORM 配置
│   │   ├── middleware/   # 中间件
│   │   ├── models/       # 数据模型
│   │   ├── routes/       # API 路由
│   │   ├── utils/        # 工具函数
│   │   └── app.ts        # 主应用入口
│   ├── prisma/           # Prisma Schema 定义
│   └── .env              # 环境变量配置
├── admin/                # React 管理后台
│   ├── src/
│   │   ├── pages/        # 页面组件
│   │   ├── components/   # 公共组件
│   │   ├── layouts/      # 布局组件
│   │   ├── utils/        # 工具函数
│   │   └── main.tsx      # 主入口
│   └── vite.config.ts    # Vite 配置
└── README.md             # 项目文档
```

## 技术栈

### 移动端 (Flutter)
- **Flutter SDK**: >=3.0.0 <4.0.0
- **地图**: flutter_map + 高德地图瓦片
- **状态管理**: Provider
- **网络请求**: Dio
- **本地存储**: SharedPreferences
- **图片加载**: cached_network_image

### 后端服务 (Node.js + TypeScript)
- **运行时**: Node.js >=18.0.0
- **框架**: Express
- **数据库**: MySQL / PostgreSQL
- **ORM**: Prisma
- **协议**: JT808（GPS 设备通信协议）
- **实时通信**: Socket.IO
- **缓存**: Redis
- **认证**: JWT

### 管理后台 (React + TypeScript)
- **框架**: React 19
- **UI 库**: Ant Design
- **路由**: React Router DOM
- **构建工具**: Vite
- **HTTP 客户端**: Axios

## 数据库配置

### 配置方式

1. 复制环境变量模板：
```bash
cd server
cp .env.example .env
```

2. 编辑 `.env` 文件，填写实际的数据库连接信息：
```env
DATABASE_URL="mysql://用户名:密码@数据库地址:端口/数据库名?timezone=%2B08%3A00"
```

3. 初始化数据库（首次部署）：
```bash
npx prisma migrate deploy
```

### 数据库表结构

主要数据表：
- `sys_user` - 后台管理系统用户
- `lot_user` - App 端用户（主用户表）
- `lot_device` - 设备信息表
- `lot_user_device_bind` - 用户设备绑定关系表
- `lot_location` - 设备位置记录表
- `lot_fence` - 电子围栏表
- `lot_user_login_device` - 用户登录设备记录表

## 环境变量配置

### 后端服务

配置文件：`server/.env`（参考 `server/.env.example`）

```env
# 数据库连接
DATABASE_URL="mysql://用户名:密码@数据库地址:端口/数据库名?timezone=%2B08%3A00"

# JWT 密钥（生产环境请使用强密码）
JWT_SECRET="your-super-secret-jwt-key"
JWT_EXPIRES_IN="7d"

# 服务器配置
PORT=3001
NODE_ENV=production
```

### 移动端高德地图配置

配置位置：`lib/config/app_config.dart`

下载代码后需要替换为你的高德地图 Key：

**方式一：直接修改配置文件（简单）**

编辑 `lib/config/app_config.dart`，将以下占位符替换为真实值：
- `your-amap-android-key-here` → 高德 Android Key
- `your-amap-ios-key-here` → 高德 iOS Key
- `your-amap-web-key-here` → 高德 Web服务 Key
- `https://api.starby.com/api` → 实际的 API 地址

**方式二：编译时注入（推荐）**

```bash
flutter build apk \
  --dart-define=AMAP_ANDROID_KEY=你的key \
  --dart-define=AMAP_IOS_KEY=你的key \
  --dart-define=AMAP_WEB_KEY=你的key \
  --dart-define=API_BASE_URL=https://你的域名/api
```

### 管理后台 API 配置

配置位置：`admin/src/utils/api.ts`，修改 API 地址为你的服务器地址。

## API 端口说明

### 后端服务端口

| 服务 | 开发环境 | 生产环境 | 说明 |
|------|---------|---------|------|
| HTTP API | 3000 | 3000 | RESTful API 服务 |
| JT808 | 7100 | 7100 | GPS 设备通信协议端口 |

### 主要 API 端点

#### 认证相关
- `POST /api/auth/register` - 用户注册
- `POST /api/auth/login` - 用户登录
- `POST /api/auth/verify-code` - 验证码登录
- `POST /api/auth/send-code` - 发送短信验证码
- `POST /api/auth/refresh` - 刷新 Token

#### 设备管理
- `GET /api/devices` - 获取当前用户的设备列表
- `GET /api/devices/all` - 获取所有设备（管理员）
- `GET /api/devices/:id` - 获取设备详情
- `GET /api/devices/:id/location` - 获取设备实时位置
- `GET /api/devices/:id/history` - 获取设备历史轨迹
- `POST /api/devices/bind` - 绑定设备
- `POST /api/devices/:id/unbind` - 解绑设备
- `PUT /api/devices/:id` - 更新设备信息

#### 围栏管理
- `GET /api/fences` - 获取围栏列表
- `POST /api/fences` - 创建围栏
- `PUT /api/fences/:id` - 更新围栏
- `DELETE /api/fences/:id` - 删除围栏

#### 用户管理（管理员）
- `GET /api/devices/users` - 获取用户列表
- `GET /api/devices/stats` - 获取统计数据

## 安装和运行

### 前置要求

- **Node.js**: >=18.0.0
- **Flutter SDK**: >=3.0.0 <4.0.0
- **MySQL**: >=5.7 或 PostgreSQL
- **Redis**: >=6.0

### 1. 后端服务

```bash
# 进入后端目录
cd server

# 安装依赖
npm install

# 配置环境变量
cp .env.example .env
# 编辑 .env 文件，填写数据库连接等配置

# 生成 Prisma Client
npm run prisma:generate

# 开发模式运行
npm run dev

# 生产模式运行
npm run build
npm start
```

### 2. 管理后台

```bash
# 进入管理后台目录
cd admin

# 安装依赖
npm install

# 开发模式运行
npm run dev

# 生产环境构建
npm run build

# 预览构建结果
npm run preview
```

### 3. 移动端 App

```bash
# 进入项目根目录（Flutter 项目）
cd /path/to/Starby

# 获取依赖
flutter pub get

# 运行开发版本（需要连接设备或模拟器）
flutter run

# 构建 Android APK
flutter build apk

# 构建 iOS
flutter build ios
```

## 开发指南

### 后端开发

后端使用 TypeScript + Express，遵循 RESTful API 设计规范。

主要目录说明：
- `src/routes/` - API 路由定义
- `src/middleware/` - 中间件（认证、错误处理等）
- `src/utils/` - 工具函数
- `src/jt808/` - JT808 协议处理
- `prisma/` - 数据库 Schema 定义

### 前端开发（管理后台）

管理后台使用 React + TypeScript + Ant Design。

主要目录说明：
- `src/pages/` - 页面组件
- `src/layouts/` - 布局组件
- `src/components/` - 公共组件
- `src/utils/` - 工具函数（包括 API 封装）

### 移动端开发

移动端使用 Flutter，使用 Provider 进行状态管理。

主要目录说明：
- `lib/screens/` - 页面组件
- `lib/widgets/` - 自定义组件
- `lib/models/` - 数据模型
- `lib/services/` - 业务服务

## 部署说明

### 服务器环境准备

```bash
# 安装 Node.js (>=18)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo bash -
sudo apt install -y nodejs

# 安装 PM2 进程管理器
npm install -g pm2

# 安装 Nginx
sudo apt install -y nginx
```

### 后端服务部署

```bash
# 1. 克隆代码
git clone https://github.com/mememix/Starby.git
cd Starby/server

# 2. 安装依赖
npm install

# 3. 配置环境变量
cp .env.example .env
# 编辑 .env 填写数据库连接、JWT密钥等

# 4. 生成 Prisma Client 并同步数据库
npm run prisma:generate
npm run prisma:migrate

# 5. 编译 TypeScript
npm run build

# 6. 使用 PM2 启动
pm2 start ecosystem.config.json
pm2 startup
pm2 save
```

### 管理后台部署

```bash
# 1. 构建生产版本
cd admin
npm install
npm run build

# 2. 部署到 Nginx
sudo cp -r dist/* /var/www/starby-admin/
```

Nginx 配置示例 (`/etc/nginx/sites-available/starby-admin`)：
```nginx
server {
    listen 80;
    server_name admin.yourdomain.com;

    root /var/www/starby-admin;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /api {
        proxy_pass http://127.0.0.1:3001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### 移动端构建

```bash
# 修改 lib/config/app_config.dart 中的 API 地址和地图 Key 后

# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS (需要 Mac + Xcode)
flutter build ios --release
```

## 常见问题

### 1. 数据库连接失败

检查 `server/.env` 中的 `DATABASE_URL` 配置是否正确，确保数据库服务可访问。

### 2. JWT 认证失败

确保前后端的 `JWT_SECRET` 一致。

### 3. 跨域问题

后端已配置 CORS，如需修改请查看 `src/app.ts` 中的 CORS 配置。

### 4. 设备无法连接

检查 JT808 端口（默认 7100）是否开放，以及设备的网络配置。

### 5. 管理后台
- 地址 http://admin.xinghu.tech/starby-admin
- 账户名：admin
- 密码：admin123


## 联系方式

- 项目名称: Starby
- 开发团队: 星护科技
- 技术支持: link@starby.cn

## 许可证

Copyright 2026 Starby. All rights reserved.
