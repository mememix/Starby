import { Router, Request, Response, NextFunction } from 'express';
import multer from 'multer';
import { v4 as uuidv4 } from 'uuid';
import path from 'path';
import fs from 'fs';
import jwt from 'jsonwebtoken';
import prisma from '../lib/prisma';
import dotenv from 'dotenv';
import { compressImage } from '../utils/imageCompressor';
import { uploadToRemote, testSSHConnection } from '../utils/fileUploader';
import { uploadViaHttp, testHttpUploadApi } from '../utils/httpUploader';

dotenv.config();

const router = Router();

// 本地存储目录
const LOCAL_STORAGE_BASE = '/Users/mememix/CodeBuddy/Starby/server/uploads';

// 上传方式配置: 'local' | 'ssh' | 'http'
const UPLOAD_METHOD = process.env.UPLOAD_METHOD || 'http';

// HTTP上传API URL
const HTTP_UPLOAD_URL = process.env.HTTP_UPLOAD_URL || 'http://localhost:3000/api/remote-upload';

// JWT 认证中间件
const authenticate = (req: Request, res: Response, next: NextFunction) => {
  const JWT_SECRET = 'your-super-secret-jwt-key';
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      success: false,
      message: '未提供认证令牌'
    });
  }

  const token = authHeader.substring(7);
  try {
    const decoded = jwt.verify(token, JWT_SECRET) as any;
    req.userId = decoded.userId;
    next();
  } catch (error) {
    console.log('[Upload authenticate] VERIFY FAILED:', error);
    return res.status(401).json({
      success: false,
      message: '无效的认证令牌'
    });
  }
};

/**
 * 扩展 Request 类型以添加 userId 属性
 */
declare module 'express' {
  interface Request {
    userId?: string;
  }
}

/**
 * 生成文件名
 * @param prefix 文件前缀
 * @returns 文件名
 */
function generateFileName(prefix: string = 'tmp_'): string {
  const uuid = uuidv4().replace(/-/g, '');
  const timestamp = new Date().toISOString().replace(/[:.]/g, '').replace('T', '');
  return `${prefix}${uuid}_${timestamp}`;
}

/**
 * 生成日期目录路径
 * @param baseUrl 基础URL
 * @returns {url: string, localPath: string} 返回URL和本地路径
 */
function generateDatePath(baseUrl: string): { url: string, localPath: string } {
  const now = new Date();
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, '0');
  const day = String(now.getDate()).padStart(2, '0');

  // 生成URL路径
  const url = `${baseUrl}/data/${year}/${month}/${day}`;

  // 生成本地路径（从URL提取服务器地址）
  let localPath: string;
  if (baseUrl.includes('116.204.117.57:39000')) {
    // 用户头像路径
    localPath = `/data/${year}/${month}/${day}`;
  } else if (baseUrl.includes('xinghu.cjhdy.cn/minio')) {
    // 设备头像路径
    localPath = `/data/${year}/${month}/${day}`;
  } else {
    // 默认路径
    localPath = `/data/${year}/${month}/${day}`;
  }

  return { url, localPath };
}

/**
 * 确保目录存在
 * @param dirPath 目录路径
 */
function ensureDirectoryExists(dirPath: string): void {
  if (!fs.existsSync(dirPath)) {
    fs.mkdirSync(dirPath, { recursive: true });
    console.log(`[Upload] 创建目录: ${dirPath}`);
  }
}

/**
 * 保存文件到本地存储
 * @param sourceFilePath 源文件路径
 * @param subPath 子路径（如: avatars/users/）
 * @returns 本地URL
 */
function saveToLocal(sourceFilePath: string, subPath: string): string {
  const targetDir = path.join(LOCAL_STORAGE_BASE, subPath);
  ensureDirectoryExists(targetDir);

  const fileName = path.basename(sourceFilePath);
  const targetFilePath = path.join(targetDir, fileName);

  // 复制文件
  fs.copyFileSync(sourceFilePath, targetFilePath);

  // 构建本地URL - 使用相对路径，让前端自动拼接服务器地址
  const relativePath = path.join(subPath, fileName).replace(/\\/g, '/'); // 统一使用正斜杠
  const localUrl = `/uploads/${relativePath}`;

  console.log(`[Upload] 文件已保存到本地: ${targetFilePath}`);
  console.log(`[Upload] 本地URL: ${localUrl}`);

  return localUrl;
}

/**
 * 通过HTTP上传文件
 * @param filePath 文件路径
 * @returns 上传URL
 */
async function uploadViaHttpInternal(filePath: string): Promise<string> {
  console.log(`[Upload] 使用HTTP上传: ${filePath}`);

  // 测试HTTP上传API是否可用
  const apiAvailable = await testHttpUploadApi(HTTP_UPLOAD_URL);
  if (!apiAvailable) {
    console.warn('[Upload] HTTP上传API不可用,回退到本地存储');
    return saveToLocal(filePath, 'avatars/users/');
  }

  // 通过HTTP上传
  const result = await uploadViaHttp({
    file: filePath,
    uploadUrl: HTTP_UPLOAD_URL,
    fieldName: 'file'
  });

  if (result.success && result.url) {
    console.log(`[Upload] HTTP上传成功: ${result.url}`);
    return result.url;
  } else {
    console.warn(`[Upload] HTTP上传失败: ${result.error},回退到本地存储`);
    return saveToLocal(filePath, 'avatars/users/');
  }
}

/**
 * 保存文件到远程服务器（已废弃，使用 fileUploader.ts 中的方法）
 * @deprecated 请使用 fileUploader.ts 中的 uploadToRemote 方法
 */

/**
 * ==================== 用户头像上传 ====================
 */
const userUploadDir = '/tmp/user_avatars';

// 确保临时目录存在
ensureDirectoryExists(userUploadDir);

// 配置 multer 临时存储
const userStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, userUploadDir);
  },
  filename: (req, file, cb) => {
    cb(null, generateFileName('user_') + path.extname(file.originalname));
  }
});

const userUpload = multer({
  storage: userStorage,
  limits: {
    fileSize: 5 * 1024 * 1024 // 5MB
  },
  fileFilter: (req, file, cb) => {
    const allowedTypes = /jpeg|jpg|png|gif|webp/;
    const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());
    const mimetype = allowedTypes.test(file.mimetype);

    if (extname && mimetype) {
      return cb(null, true);
    } else {
      cb(new Error('只支持图片格式 (jpeg, jpg, png, gif, webp)'));
    }
  }
});

/**
 * POST /api/upload/user-avatar
 * 上传用户头像到 http://116.204.117.57:39000/data/yy/mm/dd/
 */
router.post('/user-avatar', authenticate, userUpload.single('avatar'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: '没有上传文件'
      });
    }

    const userId = BigInt(req.userId as string);
    const file = req.file;
    console.log(`[User Avatar Upload] 用户ID: ${userId}, 文件: ${file.filename}, 大小: ${file.size} bytes`);

    // 生成日期路径
    const { url: baseUrl, localPath } = generateDatePath('http://116.204.117.57:39000');
    console.log(`[User Avatar Upload] 目标URL: ${baseUrl}`);

    // 读取文件并转换为 base64
    const fileBuffer = fs.readFileSync(file.path);
    const base64Image = fileBuffer.toString('base64');
    const mimeType = file.mimetype;
    const dataUrl = `data:${mimeType};base64,${base64Image}`;

    console.log(`[User Avatar Upload] Base64长度: ${dataUrl.length} 字符`);

    // 压缩图片
    console.log(`[User Avatar Upload] 开始压缩图片...`);
    const compressedDataUrl = await compressImage(dataUrl);
    console.log(`[User Avatar Upload] 压缩后长度: ${compressedDataUrl.length} 字符`);

    // 将压缩后的 base64 转换为 Buffer
    const matches = compressedDataUrl.match(/^data:image\/([a-zA-Z]+);base64,(.+)$/);
    if (!matches) {
      throw new Error('无效的 base64 格式');
    }

    const compressedBuffer = Buffer.from(matches[2], 'base64');
    const compressedFileName = generateFileName('tmp_') + '.jpg';

    // 保存压缩后的文件
    const compressedFilePath = path.join(userUploadDir, compressedFileName);
    fs.writeFileSync(compressedFilePath, compressedBuffer);

    console.log(`[User Avatar Upload] 压缩文件已保存: ${compressedFilePath}`);

    let remoteUrl: string;

    // 根据配置选择上传方式
    switch (UPLOAD_METHOD) {
      case 'http':
        remoteUrl = await uploadViaHttpInternal(compressedFilePath);
        break;
      case 'ssh':
        const sshConnected = await testSSHConnection('116.204.117.57:39000');
        if (!sshConnected) {
          console.warn('[User Avatar Upload] SSH连接失败，回退到本地存储');
          remoteUrl = saveToLocal(compressedFilePath, 'avatars/users/');
        } else {
          const uploadResult = await uploadToRemote({
            filePath: compressedFilePath,
            remotePath: localPath,
            host: '116.204.117.57:39000',
            method: 'scp'
          });

          if (!uploadResult.success) {
            console.warn('[User Avatar Upload] SSH上传失败，回退到本地存储');
            remoteUrl = saveToLocal(compressedFilePath, 'avatars/users/');
          } else {
            remoteUrl = uploadResult.url!;
          }
        }
        break;
      case 'local':
      default:
        remoteUrl = saveToLocal(compressedFilePath, 'avatars/users/');
        break;
    }

    console.log(`[User Avatar Upload] 最终URL: ${remoteUrl}`);

    // 更新用户头像
    await prisma.$queryRaw`
      UPDATE lot_user
      SET avatar_url = ${remoteUrl},
          update_time = NOW()
      WHERE user_id = ${userId}
    `;

    console.log(`[User Avatar Upload] 用户头像已更新`);

    // 清理临时文件
    try {
      fs.unlinkSync(file.path);
      fs.unlinkSync(compressedFilePath);
      console.log(`[User Avatar Upload] 临时文件已清理`);
    } catch (cleanupError) {
      console.warn(`[User Avatar Upload] 清理临时文件失败:`, cleanupError);
    }

    res.json({
      success: true,
      message: '用户头像上传成功',
      data: {
        avatarUrl: remoteUrl,
        originalSize: file.size,
        compressedSize: compressedBuffer.length
      }
    });
  } catch (error: any) {
    console.error('[User Avatar Upload] Error:', error);
    res.status(500).json({
      success: false,
      message: error.message || '用户头像上传失败'
    });
  }
});

/**
 * ==================== 设备头像上传 ====================
 */
const deviceUploadDir = '/tmp/device_avatars';

// 确保临时目录存在
ensureDirectoryExists(deviceUploadDir);

// 配置 multer 临时存储
const deviceStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, deviceUploadDir);
  },
  filename: (req, file, cb) => {
    cb(null, generateFileName('device_') + path.extname(file.originalname));
  }
});

const deviceUpload = multer({
  storage: deviceStorage,
  limits: {
    fileSize: 5 * 1024 * 1024 // 5MB
  },
  fileFilter: (req, file, cb) => {
    const allowedTypes = /jpeg|jpg|png|gif|webp/;
    const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());
    const mimetype = allowedTypes.test(file.mimetype);

    if (extname && mimetype) {
      return cb(null, true);
    } else {
      cb(new Error('只支持图片格式 (jpeg, jpg, png, gif, webp)'));
    }
  }
});

/**
 * POST /api/upload/device-avatar/:deviceId
 * 上传设备头像到 https://xinghu.cjhdy.cn/minio/data/yyyy/mm/dd/
 */
router.post('/device-avatar/:deviceId', authenticate, deviceUpload.single('avatar'), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const deviceId = BigInt(req.params.deviceId);
    const userId = BigInt(req.userId as string);

    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: '没有上传文件'
      });
    }

    const file = req.file;
    console.log(`[Device Avatar Upload] 用户ID: ${userId}, 设备ID: ${deviceId}, 文件: ${file.filename}, 大小: ${file.size} bytes`);

    // 验证设备是否属于当前用户
    const binding = await prisma.deviceBinding.findFirst({
      where: {
        userId: userId,
        deviceId: deviceId,
        bindStatus: true
      }
    });

    if (!binding) {
      return res.status(403).json({
        success: false,
        message: '无权限修改该设备信息'
      });
    }

    // 生成日期路径
    const { url: baseUrl, localPath } = generateDatePath('https://xinghu.cjhdy.cn/minio');
    console.log(`[Device Avatar Upload] 目标URL: ${baseUrl}`);

    // 读取文件并转换为 base64
    const fileBuffer = fs.readFileSync(file.path);
    const base64Image = fileBuffer.toString('base64');
    const mimeType = file.mimetype;
    const dataUrl = `data:${mimeType};base64,${base64Image}`;

    console.log(`[Device Avatar Upload] Base64长度: ${dataUrl.length} 字符`);

    // 压缩图片
    console.log(`[Device Avatar Upload] 开始压缩图片...`);
    const compressedDataUrl = await compressImage(dataUrl);
    console.log(`[Device Avatar Upload] 压缩后长度: ${compressedDataUrl.length} 字符`);

    // 将压缩后的 base64 转换为 Buffer
    const matches = compressedDataUrl.match(/^data:image\/([a-zA-Z]+);base64,(.+)$/);
    if (!matches) {
      throw new Error('无效的 base64 格式');
    }

    const compressedBuffer = Buffer.from(matches[2], 'base64');
    const compressedFileName = generateFileName('tmp_') + '.jpg';

    // 保存压缩后的文件
    const compressedFilePath = path.join(deviceUploadDir, compressedFileName);
    fs.writeFileSync(compressedFilePath, compressedBuffer);

    console.log(`[Device Avatar Upload] 压缩文件已保存: ${compressedFilePath}`);

    let remoteUrl: string;

    // 根据配置选择上传方式
    switch (UPLOAD_METHOD) {
      case 'http':
        remoteUrl = await uploadViaHttpInternal(compressedFilePath);
        break;
      case 'ssh':
        const sshConnected = await testSSHConnection('xinghu.cjhdy.cn');
        if (!sshConnected) {
          console.warn('[Device Avatar Upload] SSH连接失败，回退到本地存储');
          remoteUrl = saveToLocal(compressedFilePath, 'avatars/devices/');
        } else {
          const uploadResult = await uploadToRemote({
            filePath: compressedFilePath,
            remotePath: localPath,
            host: 'xinghu.cjhdy.cn',
            method: 'scp'
          });

          if (!uploadResult.success) {
            console.warn('[Device Avatar Upload] SSH上传失败，回退到本地存储');
            remoteUrl = saveToLocal(compressedFilePath, 'avatars/devices/');
          } else {
            remoteUrl = uploadResult.url!;
          }
        }
        break;
      case 'local':
      default:
        remoteUrl = saveToLocal(compressedFilePath, 'avatars/devices/');
        break;
    }

    console.log(`[Device Avatar Upload] 最终URL: ${remoteUrl}`);

    // 更新设备头像
    console.log('[Device Avatar Upload] 开始更新数据库...');
    const updatedDevice = await prisma.device.update({
      where: { deviceId },
      data: {
        avatar: remoteUrl,
        updateTime: new Date()
      }
    });
    console.log('[Device Avatar Upload] 数据库更新成功，新头像URL:', updatedDevice.avatar);

    // 验证更新结果
    const verifiedDevice = await prisma.device.findUnique({
      where: { deviceId }
    });
    console.log('[Device Avatar Upload] 验证数据库中的头像URL:', verifiedDevice?.avatar);

    console.log(`[Device Avatar Upload] 设备头像已更新`);

    // 清理临时文件
    try {
      fs.unlinkSync(file.path);
      fs.unlinkSync(compressedFilePath);
      console.log(`[Device Avatar Upload] 临时文件已清理`);
    } catch (cleanupError) {
      console.warn(`[Device Avatar Upload] 清理临时文件失败:`, cleanupError);
    }

    res.json({
      success: true,
      message: '设备头像上传成功',
      data: {
        avatarUrl: remoteUrl,
        originalSize: file.size,
        compressedSize: compressedBuffer.length,
        device: {
          deviceId: deviceId.toString(),
          deviceName: binding.deviceName
        }
      }
    });
  } catch (error: any) {
    console.error('[Device Avatar Upload] Error:', error);
    res.status(500).json({
      success: false,
      message: error.message || '设备头像上传失败'
    });
  }
});

export default router;
