/**
 * HTTP文件上传工具
 * 用于替代SSH上传，直接通过HTTP API上传文件
 */

import FormData from 'form-data';
import axios from 'axios';

export interface HttpUploadOptions {
  file: string; // 本地文件路径
  uploadUrl: string; // 上传API URL
  fieldName?: string; // 表单字段名，默认为 'file'
  headers?: Record<string, string>; // 额外的请求头
}

export interface HttpUploadResult {
  success: boolean;
  url?: string;
  error?: string;
}

/**
 * 通过HTTP上传文件
 * @param options 上传选项
 * @returns 上传结果
 */
export async function uploadViaHttp(options: HttpUploadOptions): Promise<HttpUploadResult> {
  const {
    file,
    uploadUrl,
    fieldName = 'file',
    headers = {}
  } = options;

  try {
    const fs = require('fs');
    const path = require('path');

    // 检查文件是否存在
    if (!fs.existsSync(file)) {
      return {
        success: false,
        error: `文件不存在: ${file}`
      };
    }

    // 创建表单数据
    const formData = new FormData();
    formData.append(fieldName, fs.createReadStream(file), path.basename(file));

    console.log(`[HttpUploader] 开始上传: ${file} -> ${uploadUrl}`);

    // 发送请求
    const response = await axios.post(uploadUrl, formData, {
      headers: {
        ...formData.getHeaders(),
        ...headers
      },
      maxBodyLength: Infinity,
      maxContentLength: Infinity,
      timeout: 30000 // 30秒超时
    });

    console.log(`[HttpUploader] 上传响应: ${JSON.stringify(response.data)}`);

    // 检查响应
    if (response.data.success || response.data.url) {
      return {
        success: true,
        url: response.data.url || response.data.data?.url
      };
    } else {
      return {
        success: false,
        error: response.data.message || response.data.error || '上传失败'
      };
    }
  } catch (error: any) {
    console.error('[HttpUploader] 上传失败:', error.message);
    return {
      success: false,
      error: error.message || 'HTTP上传失败'
    };
  }
}

/**
 * 测试HTTP上传API是否可用
 * @param uploadUrl 上传API URL
 * @returns 是否可用
 */
export async function testHttpUploadApi(uploadUrl: string): Promise<boolean> {
  try {
    // 尝试访问服务器的health端点
    const baseUrl = uploadUrl.split('/api/remote-upload')[0];
    const healthUrl = `${baseUrl}/health`;
    const response = await axios.get(healthUrl, {
      timeout: 5000
    });
    return response.status === 200;
  } catch (error) {
    // 如果没有health接口，尝试OPTIONS请求
    try {
      await axios.options(uploadUrl, { timeout: 5000 });
      return true;
    } catch (e) {
      console.error('[HttpUploader] API测试失败:', error);
      return false;
    }
  }
}
