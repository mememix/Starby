// src/utils/smsService.ts
// 腾讯云短信发送工具类

const TencentCloudSDK = require('tencentcloud-sdk-nodejs');

// 导入短信客户端
const smsClient = TencentCloudSDK.sms.v20210111.Client;

// 环境变量配置
const SECRET_ID = process.env.TENCENT_CLOUD_SECRET_ID || '';
const SECRET_KEY = process.env.TENCENT_CLOUD_SECRET_KEY || '';
const SMS_APP_ID = process.env.SMS_APP_ID || '';
const SIGN_NAME = process.env.SMS_SIGN_NAME || '星护伙伴';
const TEMPLATE_ID = process.env.SMS_TEMPLATE_ID || '';

// 验证码存储（生产环境应使用Redis）
const verificationCodes = new Map<string, {
  code: string;
  expireTime: number;
  phone: string;
  lastSentTime: number; // 上次发送时间
}>();

/**
 * 生成6位数字验证码
 */
function generateVerificationCode(): string {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

/**
 * 发送验证码
 * @param phone 手机号
 * @param code 验证码
 * @returns 发送结果
 */
async function sendVerificationCode(phone: string, code: string): Promise<{
  success: boolean;
  message: string;
}> {
  try {
    // 检查是否配置了腾讯云
    if (!SECRET_ID || !SECRET_KEY || !SMS_APP_ID || !TEMPLATE_ID) {
      console.warn('[SMS Service] 腾讯云短信未配置，使用模拟模式');
      console.log(`[SMS Service] 模拟发送验证码到 ${phone}: ${code}`);

      // 模拟发送成功
      return {
        success: true,
        message: '验证码已发送（模拟模式）'
      };
    }

    // 初始化客户端
    const clientConfig = {
      credential: {
        secretId: SECRET_ID,
        secretKey: SECRET_KEY,
      },
      region: 'ap-guangzhou', // 广州地域
      profile: {
        httpProfile: {
          endpoint: 'sms.tencentcloudapi.com',
        },
      },
    };

    const client = new smsClient(clientConfig);

    // 构建请求参数
    const params = {
      PhoneNumberSet: [`+86${phone}`],
      TemplateId: TEMPLATE_ID,
      TemplateParamSet: [code], // 验证码（模板：验证码为：{1}，若非本人操作，请勿泄露。）
      SmsSdkAppId: SMS_APP_ID,
      SignName: SIGN_NAME,
    };

    console.log(`[SMS Service] 发送短信到 ${phone}, 验证码: ${code}`);

    // 发送短信
    const response = await client.SendSms(params);

    // 检查发送结果
    const sendStatus = response.SendStatusSet && response.SendStatusSet[0];

    if (sendStatus && sendStatus.Code !== 'Ok') {
      console.error('[SMS Service] 发送失败:', {
        Code: sendStatus.Code,
        Message: sendStatus.Message,
        PhoneNumber: sendStatus.PhoneNumber
      });

      // 根据错误码返回更详细的错误信息
      let errorMessage = '验证码发送失败，请稍后重试';
      if (sendStatus.Code === 'LimitExceeded.PhoneNumberDailyLimit') {
        errorMessage = '该手机号今日发送次数已达上限，请明天再试';
      } else if (sendStatus.Code === 'LimitExceeded.PhoneNumberOneHourLimit') {
        errorMessage = '该手机号1小时内发送次数已达上限，请稍后再试';
      } else if (sendStatus.Code === 'LimitExceeded.PhoneNumberFiveMinuteLimit') {
        errorMessage = '该手机号5分钟内发送次数已达上限，请稍后再试';
      } else if (sendStatus.Code === 'SignatureNotExistOrIllegal') {
        errorMessage = '短信签名不存在或不合法，请联系管理员';
      } else if (sendStatus.Code === 'TemplateNotExistOrIllegal') {
        errorMessage = '短信模板不存在或不合法，请联系管理员';
      }

      return {
        success: false,
        message: errorMessage
      };
    }

    console.log('[SMS Service] 发送成功:', response);

    return {
      success: true,
      message: '验证码已发送'
    };
  } catch (error) {
    console.error('[SMS Service] 发送异常:', error);
    return {
      success: false,
      message: '验证码发送失败，请稍后重试'
    };
  }
}

/**
 * 保存验证码到内存（生产环境应使用Redis）
 * @param phone 手机号
 * @param code 验证码
 */
function saveVerificationCode(phone: string, code: string): void {
  const expireTime = Date.now() + 5 * 60 * 1000; // 5分钟后过期
  verificationCodes.set(phone, {
    code,
    expireTime,
    phone,
    lastSentTime: Date.now(), // 记录发送时间
  });

  // 5分钟后自动清理
  setTimeout(() => {
    verificationCodes.delete(phone);
  }, 5 * 60 * 1000);
}

/**
 * 验证验证码
 * @param phone 手机号
 * @param code 验证码
 * @returns 验证结果
 */
function verifyCode(phone: string, code: string): boolean {
  const stored = verificationCodes.get(phone);
  
  if (!stored) {
    return false;
  }

  // 检查是否过期
  if (Date.now() > stored.expireTime) {
    verificationCodes.delete(phone);
    return false;
  }

  // 验证码是否匹配
  const isValid = stored.code === code;
  
  // 验证成功后删除验证码，防止重复使用
  if (isValid) {
    verificationCodes.delete(phone);
  }

  return isValid;
}

/**
 * 发送验证码接口
 * @param phone 手机号
 * @returns 发送结果
 */
export async function sendLoginCode(phone: string): Promise<{
  success: boolean;
  message: string;
  code?: string; // 仅用于测试，生产环境不返回
}> {
  // 验证手机号格式
  if (!/^1[3-9]\d{9}$/.test(phone)) {
    return {
      success: false,
      message: '手机号格式不正确'
    };
  }

  // 开发环境下取消发送频率限制
  if (process.env.NODE_ENV !== 'development') {
    // 检查是否频繁发送（1分钟内只能发送一次）
    const lastSent = verificationCodes.get(phone);
    if (lastSent && Date.now() - lastSent.lastSentTime < 60 * 1000) {
      const remainingSeconds = Math.ceil(60 - (Date.now() - lastSent.lastSentTime) / 1000);
      return {
        success: false,
        message: `请${remainingSeconds}秒后再试`
      };
    }
  }

  // 生成验证码
  const code = generateVerificationCode();
  
  // 保存验证码
  saveVerificationCode(phone, code);
  
  // 发送短信
  const result = await sendVerificationCode(phone, code);

  // 开发环境下返回验证码用于测试
  if (process.env.NODE_ENV === 'development') {
    return {
      ...result,
      code, // 仅开发环境返回
    };
  }

  return result;
}

/**
 * 验证登录验证码
 * @param phone 手机号
 * @param code 验证码
 * @returns 验证结果
 */
export function verifyLoginCode(phone: string, code: string): boolean {
  return verifyCode(phone, code);
}

// 导出清理函数（用于测试）
export function clearVerificationCodes(): void {
  verificationCodes.clear();
}
