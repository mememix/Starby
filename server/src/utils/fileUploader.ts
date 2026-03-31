/**
 * 文件上传工具
 * 支持SCP（需要SSH免密）和rsync两种上传方式
 */

import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

export interface UploadOptions {
  filePath: string;
  remotePath: string;
  host: string;
  user?: string;
  method?: 'scp' | 'rsync';
}

export interface UploadResult {
  success: boolean;
  url?: string;
  error?: string;
}

/**
 * 上传文件到远程服务器
 * @param options 上传选项
 * @returns 上传结果
 */
export async function uploadToRemote(options: UploadOptions): Promise<UploadResult> {
  const {
    filePath,
    remotePath,
    host,
    user = 'root',
    method = 'scp' // 默认使用scp
  } = options;

  const fileName = require('path').basename(filePath);
  const remoteFilePath = `${remotePath}/${fileName}`;

  try {
    if (method === 'rsync') {
      // 使用 rsync 上传（比scp更稳定）
      await execAsync(
        `rsync -avz --no-o --no-g -e "ssh -o StrictHostKeyChecking=no" ${filePath} ${user}@${host}:${remotePath}`
      );
      console.log(`[FileUploader] rsync上传成功: ${host}${remoteFilePath}`);
    } else {
      // 使用 scp 上传
      await execAsync(
        `scp -o StrictHostKeyChecking=no ${filePath} ${user}@${host}:${remoteFilePath}`
      );
      console.log(`[FileUploader] scp上传成功: ${host}${remoteFilePath}`);
    }

    // 构建远程URL
    const url = buildRemoteUrl(host, remoteFilePath);
    return { success: true, url };
  } catch (error: any) {
    console.error(`[FileUploader] 上传失败 (${method}):`, error);
    return {
      success: false,
      error: error.message || '文件上传失败'
    };
  }
}

/**
 * 构建远程URL
 * @param host 主机地址
 * @param remoteFilePath 远程文件路径
 * @returns 完整的URL
 */
function buildRemoteUrl(host: string, remoteFilePath: string): string {
  if (host.includes('116.204.117.57:39000')) {
    return `http://${host}${remoteFilePath}`;
  } else {
    return `https://${host}/minio${remoteFilePath}`;
  }
}

/**
 * 测试SSH连接
 * @param host 主机地址
 * @param user 用户名
 * @returns 是否连接成功
 */
export async function testSSHConnection(host: string, user: string = 'root'): Promise<boolean> {
  try {
    await execAsync(`ssh -o StrictHostKeyChecking=no ${user}@${host} "echo 'OK'"`);
    return true;
  } catch (error) {
    console.error('[FileUploader] SSH连接测试失败:', error);
    return false;
  }
}
