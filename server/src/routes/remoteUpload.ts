/**
 * 远程文件上传API
 * 用于接收来自其他服务器的文件上传请求
 */

import { Router, Request, Response } from 'express';
import multer from 'multer';
import path from 'path';
import fs from 'fs';

const router = Router();

// 上传目录配置
const REMOTE_UPLOAD_BASE = '/Users/mememix/CodeBuddy/Starby/server/uploads/remote';

// 确保目录存在
if (!fs.existsSync(REMOTE_UPLOAD_BASE)) {
  fs.mkdirSync(REMOTE_UPLOAD_BASE, { recursive: true });
}

// multer配置
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    // 根据日期创建子目录
    const now = new Date();
    const year = now.getFullYear();
    const month = String(now.getMonth() + 1).padStart(2, '0');
    const day = String(now.getDate()).padStart(2, '0');
    const dateDir = path.join(REMOTE_UPLOAD_BASE, `${year}/${month}/${day}`);

    if (!fs.existsSync(dateDir)) {
      fs.mkdirSync(dateDir, { recursive: true });
    }

    cb(null, dateDir);
  },
  filename: (req, file, cb) => {
    // 生成唯一文件名
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, uniqueSuffix + path.extname(file.originalname));
  }
});

const upload = multer({
  storage: storage,
  limits: {
    fileSize: 10 * 1024 * 1024 // 10MB
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
 * POST /api/remote-upload
 * 接收远程文件上传
 */
router.post('/', upload.single('file'), async (req: Request, res: Response) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: '没有上传文件'
      });
    }

    const file = req.file;
    console.log(`[RemoteUpload] 收到文件: ${file.filename}, 大小: ${file.size} bytes`);

    // 构建访问URL - 使用相对路径，让前端自动拼接服务器地址
    const relativePath = file.path.replace(REMOTE_UPLOAD_BASE, '').replace(/^\//, '');
    const url = `/uploads/remote/${relativePath}`;

    console.log(`[RemoteUpload] 文件URL: ${url}`);

    res.json({
      success: true,
      message: '上传成功',
      data: {
        filename: file.filename,
        originalName: file.originalname,
        size: file.size,
        mimetype: file.mimetype,
        url: url,
        path: file.path
      }
    });
  } catch (error: any) {
    console.error('[RemoteUpload] 上传失败:', error);
    res.status(500).json({
      success: false,
      message: error.message || '上传失败'
    });
  }
});

/**
 * GET /api/remote-upload/health
 * 健康检查
 */
router.get('/health', (req: Request, res: Response) => {
  res.json({
    status: 'ok',
    service: '远程上传API',
    uploadDir: REMOTE_UPLOAD_BASE
  });
});

export default router;
