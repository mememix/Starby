/**
 * 图像压缩工具
 * 自动将头像压缩到合适尺寸和质量，确保base64编码后不超过5000字符
 */

import sharp = require('sharp');

export interface CompressionOptions {
  maxWidth?: number;
  maxHeight?: number;
  quality?: number; // JPEG质量 (1-100)
  maxBase64Length?: number; // 最大base64长度（包含前缀）
}

const DEFAULT_OPTIONS: CompressionOptions = {
  maxWidth: 128, // 减小最大尺寸以减少数据量
  maxHeight: 128,
  quality: 50, // 降低质量以进一步减少数据量
  maxBase64Length: 60000, // 数据库限制约65KB，设置为60KB留出安全余量
};

/**
 * 压缩图像并返回base64 URL
 * @param input 输入数据：base64字符串、Buffer或文件路径
 * @param options 压缩选项
 * @returns 压缩后的base64 URL (data:image/jpeg;base64,...)
 */
export async function compressImage(
  input: string | Buffer,
  options: CompressionOptions = {}
): Promise<string> {
  const opts = { ...DEFAULT_OPTIONS, ...options };
  
  try {
    // 解析输入数据
    let imageBuffer: Buffer;
    
    if (typeof input === 'string') {
      // 检查是否为base64 URL
      if (input.startsWith('data:')) {
        // 提取base64部分
        const matches = input.match(/^data:image\/([a-zA-Z]+);base64,(.+)$/);
        if (!matches) {
          // 无效的base64图像URL，直接返回原始输入
          console.warn('[ImageCompressor] 无效的base64图像URL格式，跳过压缩');
          return input;
        }
        // const mimeType = matches[1];
        const base64Data = matches[2];
        
        // 检查base64数据是否为空
        if (!base64Data || base64Data.trim().length === 0) {
          console.warn('[ImageCompressor] base64数据为空，跳过压缩');
          return input;
        }
        
        try {
          imageBuffer = Buffer.from(base64Data, 'base64');
          
          // 验证Buffer长度
          if (imageBuffer.length === 0) {
            console.warn('[ImageCompressor] Buffer为空，跳过压缩');
            return input;
          }
        } catch (bufferError) {
          console.warn('[ImageCompressor] 无法解析base64数据:', bufferError);
          return input;
        }
      } else {
        // 不是data:开头的字符串，可能是其他格式，直接返回
        console.warn('[ImageCompressor] 输入不是base64图像URL，跳过压缩');
        return input;
      }
    } else {
      // Buffer输入
      imageBuffer = input;
      
      // 验证Buffer长度
      if (imageBuffer.length === 0) {
        console.warn('[ImageCompressor] Buffer为空，跳过压缩');
        return 'data:image/jpeg;base64,';
      }
    }
    
    // 检查图像格式并获取元数据
    const metadata = await sharp(imageBuffer).metadata();
    
    // 计算目标尺寸（保持宽高比）
    let targetWidth = metadata.width || opts.maxWidth!;
    let targetHeight = metadata.height || opts.maxHeight!;
    
    if (metadata.width && metadata.height) {
      const widthRatio = opts.maxWidth! / metadata.width;
      const heightRatio = opts.maxHeight! / metadata.height;
      const ratio = Math.min(widthRatio, heightRatio);
      
      if (ratio < 1) {
        // 需要缩小
        targetWidth = Math.floor(metadata.width * ratio);
        targetHeight = Math.floor(metadata.height * ratio);
      }
    }
    
    // 确保最小尺寸
    targetWidth = Math.max(32, targetWidth);
    targetHeight = Math.max(32, targetHeight);
    
    // 压缩图像
    let compressedBuffer = await sharp(imageBuffer)
      .resize(targetWidth, targetHeight, {
        fit: 'inside',
        withoutEnlargement: true, // 不放大图像
      })
      .jpeg({
        quality: opts.quality,
        mozjpeg: true, // 更好的压缩
      })
      .toBuffer();
    
    // 检查base64长度
    const base64Data = compressedBuffer.toString('base64');
    const base64Url = `data:image/jpeg;base64,${base64Data}`;
    const prefixLength = 'data:image/jpeg;base64,'.length;
    const totalLength = base64Url.length;

    console.log(`[ImageCompressor] First compression: ${totalLength} chars (target: ${opts.maxBase64Length})`);
    
    // 如果仍然超过限制，逐步降低质量
    if (totalLength > opts.maxBase64Length!) {
      let currentQuality = opts.quality!;
      let attempts = 0;
      const maxAttempts = 5;
      
      while (totalLength > opts.maxBase64Length! && attempts < maxAttempts && currentQuality > 10) {
        attempts++;
        currentQuality = Math.max(10, currentQuality - 15); // 每次降低15质量
        
        compressedBuffer = await sharp(imageBuffer)
          .resize(targetWidth, targetHeight, {
            fit: 'inside',
            withoutEnlargement: true,
          })
          .jpeg({
            quality: currentQuality,
            mozjpeg: true,
          })
          .toBuffer();
        
        const newBase64Data = compressedBuffer.toString('base64');
        const newBase64Url = `data:image/jpeg;base64,${newBase64Data}`;
        const newTotalLength = newBase64Url.length;
        
        if (newTotalLength <= opts.maxBase64Length!) {
          return newBase64Url;
        }
      }
      
      // 如果还是太大，进一步缩小尺寸
      if (totalLength > opts.maxBase64Length!) {
        let currentWidth = targetWidth;
        let currentHeight = targetHeight;
        attempts = 0;
        
        while (totalLength > opts.maxBase64Length! && attempts < 3 && currentWidth > 32) {
          attempts++;
          currentWidth = Math.max(32, Math.floor(currentWidth * 0.7));
          currentHeight = Math.max(32, Math.floor(currentHeight * 0.7));
          
          compressedBuffer = await sharp(imageBuffer)
            .resize(currentWidth, currentHeight, {
              fit: 'inside',
              withoutEnlargement: true,
            })
            .jpeg({
              quality: Math.max(10, currentQuality),
              mozjpeg: true,
            })
            .toBuffer();
          
          const newBase64Data = compressedBuffer.toString('base64');
          const newBase64Url = `data:image/jpeg;base64,${newBase64Data}`;
          const newTotalLength = newBase64Url.length;
          
          if (newTotalLength <= opts.maxBase64Length!) {
            return newBase64Url;
          }
        }
      }
    }
    
    return base64Url;
  } catch (error) {
    console.error('图像压缩失败:', error);
    // 如果压缩失败，返回原始输入（如果是base64）
    if (typeof input === 'string' && input.startsWith('data:')) {
      return input;
    }
    throw error;
  }
}

/**
 * 检查base64 URL是否超过长度限制
 * @param base64Url base64 URL
 * @param maxLength 最大长度（默认5000）
 * @returns 是否超过限制
 */
export function isBase64UrlTooLong(base64Url: string, maxLength: number = 5000): boolean {
  return base64Url.length > maxLength;
}

/**
 * 获取base64 URL的长度信息
 * @param base64Url base64 URL
 * @returns 长度信息对象
 */
export function getBase64UrlInfo(base64Url: string): {
  totalLength: number;
  prefixLength: number;
  base64Length: number;
  mimeType?: string;
} {
  const matches = base64Url.match(/^data:(image\/[a-zA-Z]+);base64,(.+)$/);
  if (!matches) {
    return {
      totalLength: base64Url.length,
      prefixLength: 0,
      base64Length: base64Url.length,
    };
  }
  
  const mimeType = matches[1];
  const base64Data = matches[2];
  const prefixLength = `data:${mimeType};base64,`.length;
  
  return {
    totalLength: base64Url.length,
    prefixLength,
    base64Length: base64Data.length,
    mimeType,
  };
}