# 星护伙伴 Flutter App 配置文件

## 环境配置说明

### 开发环境 (开发调试用)
```yaml
API_BASE_URL: http://192.168.1.153:3000/api
WS_BASE_URL: ws://192.168.1.153:3000/ws/location
AMAP_ANDROID_KEY: 你的高德地图Android Key
AMAP_IOS_KEY: 你的高德地图iOS Key
```

### 生产环境 (正式发布用)
```yaml
API_BASE_URL: https://api.starby.com/api
WS_BASE_URL: wss://api.starby.com/ws/location
AMAP_ANDROID_KEY: 你的高德地图Android Key
AMAP_IOS_KEY: 你的高德地图iOS Key
```

## 如何获取高德地图API Key

1. 访问 [高德开放平台](https://console.amap.com/dev/key/app)
2. 创建应用
3. 添加Key:
   - 选择平台: Android / iOS
   - 输入包名: com.starby.mobile
   - 输入SHA1签名(Android)
4. 复制生成的Key到配置文件

## 网络配置

### 开发环境
- 确保手机和电脑在同一局域网
- 修改IP地址为你电脑的局域网IP
- Android设备需在AndroidManifest.xml配置网络安全

### 生产环境
- 使用HTTPS域名
- 配置SSL证书
- 确保防火墙开放相应端口

## 切换环境

修改 `lib/config/app_config.dart` 中的 `ENV` 变量:
- `dev`: 开发环境
- `prod`: 生产环境
