/**
 * JT808消息编码器
 */

import {
  MessageHeader,
  GeneralResponseBody,
  TerminalRegisterResponseBody,
  GeneralResponseResult,
  RegisterResponseResult,
  MessageId,
} from './types';
import {
  BCD,
  calculateChecksum,
  escape,
} from './protocol';

/**
 * 消息编码器
 */
export class JT808Encoder {
  private static messageSerialNo = 0;

  /**
   * 获取下一个消息流水号
   */
  private static getNextSerialNo(): number {
    this.messageSerialNo = (this.messageSerialNo + 1) % 0xFFFF;
    return this.messageSerialNo;
  }

  /**
   * 编码消息
   */
  static encode(
    messageId: number,
    phoneNumber: string,
    body: Buffer,
    serialNo?: number
  ): Buffer {
    const messageSerialNo = serialNo ?? this.getNextSerialNo();

    // 消息体属性
    const messageBodyLength = body.length;
    const messageBodyProps = messageBodyLength & 0x03FF;

    // 构建消息头
    const header = Buffer.alloc(12);
    let offset = 0;

    // 消息ID
    header.writeUInt16BE(messageId, offset);
    offset += 2;

    // 消息体属性
    header.writeUInt16BE(messageBodyProps, offset);
    offset += 2;

    // 终端手机号 (BCD)
    const phoneBcd = BCD.fromString(phoneNumber.padStart(12, '0'));
    phoneBcd.copy(header, offset);
    offset += 6;

    // 消息流水号
    header.writeUInt16BE(messageSerialNo, offset);
    offset += 2;

    // 组合消息头和消息体
    const message = Buffer.concat([header, body]);

    // 计算校验码
    const checksum = calculateChecksum(message);

    // 转义
    const escaped = escape(Buffer.concat([message, Buffer.from([checksum])]));

    // 添加首尾标识
    return Buffer.concat([Buffer.from([0x7E]), escaped, Buffer.from([0x7E])]);
  }

  /**
   * 编码通用应答
   */
  static encodeGeneralResponse(
    phoneNumber: string,
    responseSerialNo: number,
    responseMessageId: number,
    result: GeneralResponseResult,
    serialNo?: number
  ): Buffer {
    const body = Buffer.alloc(5);
    let offset = 0;

    // 应答流水号
    body.writeUInt16BE(responseSerialNo, offset);
    offset += 2;

    // 应答ID
    body.writeUInt16BE(responseMessageId, offset);
    offset += 2;

    // 结果
    body.writeUInt8(result, offset);
    offset += 1;

    return this.encode(MessageId.GENERAL_RESPONSE, phoneNumber, body, serialNo);
  }

  /**
   * 编码终端注册应答
   */
  static encodeTerminalRegisterResponse(
    phoneNumber: string,
    responseSerialNo: number,
    result: RegisterResponseResult,
    authCode?: string,
    serialNo?: number
  ): Buffer {
    const bodyLength = authCode ? 3 + authCode.length : 3;
    const body = Buffer.alloc(bodyLength);
    let offset = 0;

    // 应答流水号
    body.writeUInt16BE(responseSerialNo, offset);
    offset += 2;

    // 结果
    body.writeUInt8(result, offset);
    offset += 1;

    // 鉴权码 (可选)
    if (authCode) {
      body.write(authCode, offset, 'ascii');
      offset += authCode.length;
    }

    return this.encode(MessageId.TERMINAL_REGISTER_RESPONSE, phoneNumber, body, serialNo);
  }
}
