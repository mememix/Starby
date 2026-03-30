"use strict";
/**
 * JT808消息解析器
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.JT808Parser = void 0;
var iconv_lite_1 = require("iconv-lite");
var protocol_1 = require("./protocol");
/**
 * 消息解析器
 */
var JT808Parser = /** @class */ (function () {
    function JT808Parser() {
        this.buffer = Buffer.alloc(0);
        this.MAX_BUFFER_SIZE = 1024 * 1024; // 1MB
    }
    /**
     * 添加数据到缓冲区
     */
    JT808Parser.prototype.addData = function (data) {
        this.buffer = Buffer.concat([this.buffer, data]);
        if (this.buffer.length > this.MAX_BUFFER_SIZE) {
            this.buffer = this.buffer.slice(this.buffer.length - this.MAX_BUFFER_SIZE);
        }
    };
    /**
     * 从缓冲区解析消息
     */
    JT808Parser.prototype.parseMessages = function () {
        var messages = [];
        var offset = 0;
        while (offset < this.buffer.length) {
            // 查找起始标识 0x7E
            var startIndex = this.buffer.indexOf(0x7E, offset);
            if (startIndex === -1) {
                break;
            }
            // 查找结束标识 0x7E
            var endIndex = this.buffer.indexOf(0x7E, startIndex + 1);
            if (endIndex === -1) {
                break;
            }
            // 提取消息体
            var messageData = this.buffer.slice(startIndex + 1, endIndex);
            try {
                // 反转义
                var unescapedData = (0, protocol_1.unescape)(messageData);
                // 校验
                if (unescapedData.length < 2) {
                    throw new Error('Message too short');
                }
                var checksum = unescapedData[unescapedData.length - 1];
                var calculatedChecksum = (0, protocol_1.calculateChecksum)(unescapedData.slice(0, -1));
                if (checksum !== calculatedChecksum) {
                    throw new Error("Checksum mismatch: expected ".concat(checksum, ", got ").concat(calculatedChecksum));
                }
                // 解析消息
                var message = this.parseMessage(unescapedData.slice(0, -1));
                messages.push(message);
            }
            catch (error) {
                console.error('[JT808] Parse error:', error);
            }
            offset = endIndex + 1;
        }
        // 清除已解析的数据
        this.buffer = this.buffer.slice(offset);
        return messages;
    };
    /**
     * 解析消息
     */
    JT808Parser.prototype.parseMessage = function (data) {
        var offset = 0;
        // 消息ID (2字节)
        var messageId = data.readUInt16BE(offset);
        offset += 2;
        // 消息体属性 (2字节)
        var messageBodyProps = data.readUInt16BE(offset);
        offset += 2;
        var messageBodyLength = messageBodyProps & 0x03FF;
        var hasSubpackage = (messageBodyProps & 0x2000) !== 0;
        var encryptionType = (messageBodyProps >> 10) & 0x07;
        // 终端手机号 (6字节 BCD)
        var phoneNumber = protocol_1.BCD.toString(data.slice(offset, offset + 6));
        offset += 6;
        // 消息流水号 (2字节)
        var messageSerialNo = data.readUInt16BE(offset);
        offset += 2;
        // 消息包封装项 (如果有)
        var packageCount;
        var packageNo;
        if (hasSubpackage) {
            packageCount = data.readUInt16BE(offset);
            offset += 2;
            packageNo = data.readUInt16BE(offset);
            offset += 2;
        }
        // 消息体
        var body = data.slice(offset, offset + messageBodyLength);
        return {
            header: {
                messageId: messageId,
                messageBodyProps: messageBodyProps,
                phoneNumber: phoneNumber,
                messageSerialNo: messageSerialNo,
                packageCount: packageCount,
                packageNo: packageNo,
            },
            body: body,
        };
    };
    /**
     * 解析终端注册消息体
     */
    JT808Parser.parseTerminalRegister = function (body) {
        var offset = 0;
        // 省域ID (2字节)
        var provinceId = body.readUInt16BE(offset);
        offset += 2;
        // 市县域ID (2字节)
        var cityId = body.readUInt16BE(offset);
        offset += 2;
        // 制造商ID (5字节)
        var manufacturerId = body.slice(offset, offset + 5).toString('ascii');
        offset += 5;
        // 终端型号 (20字节)
        var terminalModel = body.slice(offset, offset + 20).toString('ascii').trim();
        offset += 20;
        // 终端ID (7字节)
        var terminalId = body.slice(offset, offset + 7).toString('ascii');
        offset += 7;
        // 车牌颜色 (1字节)
        var licensePlateColor = body.readUInt8(offset);
        offset += 1;
        // 车牌 (剩余字节)
        var licensePlate = iconv_lite_1.default.decode(body.slice(offset), 'gbk');
        return {
            provinceId: provinceId,
            cityId: cityId,
            manufacturerId: manufacturerId,
            terminalModel: terminalModel,
            terminalId: terminalId,
            licensePlateColor: licensePlateColor,
            licensePlate: licensePlate,
        };
    };
    /**
     * 解析终端鉴权消息体
     */
    JT808Parser.parseTerminalAuth = function (body) {
        return {
            authCode: body.toString('ascii'),
        };
    };
    /**
     * 解析位置信息汇报消息体
     */
    JT808Parser.parseLocationReport = function (body) {
        var offset = 0;
        // 报警标志 (4字节)
        var alarmFlagValue = body.readUInt32BE(offset);
        offset += 4;
        // 状态标志 (4字节)
        var statusFlagValue = body.readUInt32BE(offset);
        offset += 4;
        // 纬度 (4字节)
        var latitude = body.readUInt32BE(offset);
        offset += 4;
        // 经度 (4字节)
        var longitude = body.readUInt32BE(offset);
        offset += 4;
        // 海拔高度 (2字节)
        var altitude = body.readUInt16BE(offset);
        offset += 2;
        // 速度 (2字节)
        var speed = body.readUInt16BE(offset);
        offset += 2;
        // 方向 (2字节)
        var direction = body.readUInt16BE(offset);
        offset += 2;
        // 时间 (6字节 BCD)
        var timeBcd = protocol_1.BCD.toString(body.slice(offset, offset + 6));
        offset += 6;
        var time = protocol_1.BCD.toDate(timeBcd);
        // 转换经纬度
        var latDegrees = (0, protocol_1.convertLatitude)(latitude);
        var lonDegrees = (0, protocol_1.convertLongitude)(longitude);
        return {
            alarmFlag: JT808Parser.parseAlarmFlag(alarmFlagValue),
            statusFlag: JT808Parser.parseStatusFlag(statusFlagValue),
            latitude: latitude,
            longitude: longitude,
            altitude: altitude,
            speed: speed,
            direction: direction,
            time: time,
            latDegrees: latDegrees,
            lonDegrees: lonDegrees,
        };
    };
    /**
     * 解析报警标志
     */
    JT808Parser.parseAlarmFlag = function (value) {
        return {
            emergency: (value & (1 << 0)) !== 0,
            overspeed: (value & (1 << 1)) !== 0,
            fatigue: (value & (1 << 2)) !== 0,
            danger: (value & (1 << 3)) !== 0,
            gnssLost: (value & (1 << 4)) !== 0,
            gnssAntennaLost: (value & (1 << 5)) !== 0,
            gnssAntennaShort: (value & (1 << 6)) !== 0,
            powerLow: (value & (1 << 7)) !== 0,
            powerLost: (value & (1 << 8)) !== 0,
            lcdLost: (value & (1 << 9)) !== 0,
            ttsLost: (value & (1 << 10)) !== 0,
            cameraLost: (value & (1 << 11)) !== 0,
            icCardLost: (value & (1 << 12)) !== 0,
            overspeedEarly: (value & (1 << 13)) !== 0,
            fatigueEarly: (value & (1 << 14)) !== 0,
            viotate: (value & (1 << 15)) !== 0,
            gpsTimeLost: (value & (1 << 16)) !== 0,
            positionLost: (value & (1 << 17)) !== 0,
        };
    };
    /**
     * 解析状态标志
     */
    JT808Parser.parseStatusFlag = function (value) {
        return {
            accOn: (value & (1 << 0)) !== 0,
            positioned: (value & (1 << 1)) !== 0,
            latSouth: (value & (1 << 2)) !== 0,
            lonWest: (value & (1 << 3)) !== 0,
            operation: (value & (1 << 4)) !== 0,
            encryption: (value & (1 << 5)) !== 0,
            load: (value & (1 << 8)) !== 0,
            oil: (value & (1 << 9)) !== 0,
            circuit: (value & (1 << 10)) !== 0,
            doorLocked: (value & (1 << 11)) !== 0,
            frontDoorOpen: (value & (1 << 12)) !== 0,
            backDoorOpen: (value & (1 << 13)) !== 0,
            driverDoorOpen: (value & (1 << 14)) !== 0,
            otherDoorOpen: (value & (1 << 15)) !== 0,
            gpsSparse: (value & (1 << 18)) !== 0,
            beidouSparse: (value & (1 << 19)) !== 0,
            glonassSparse: (value & (1 << 20)) !== 0,
            galileoSparse: (value & (1 << 21)) !== 0,
        };
    };
    return JT808Parser;
}());
exports.JT808Parser = JT808Parser;
