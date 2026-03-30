"use strict";
/**
 * JT808协议工具类
 * 参考标准: JT/T 808-2019 道路运输车辆卫星定位系统终端通讯协议及数据格式
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.BCD = void 0;
exports.calculateChecksum = calculateChecksum;
exports.escape = escape;
exports.unescape = unescape;
exports.convertLatitude = convertLatitude;
exports.convertLongitude = convertLongitude;
exports.toJT808Latitude = toJT808Latitude;
exports.toJT808Longitude = toJT808Longitude;
/**
 * BCD编码转换
 */
var BCD = /** @class */ (function () {
    function BCD() {
    }
    /**
     * Buffer转BCD字符串
     */
    BCD.toString = function (buffer) {
        var result = '';
        for (var i = 0; i < buffer.length; i++) {
            var high = (buffer[i] >> 4) & 0x0F;
            var low = buffer[i] & 0x0F;
            result += high.toString() + low.toString();
        }
        return result;
    };
    /**
     * 字符串转BCD Buffer
     */
    BCD.fromString = function (str) {
        var len = Math.ceil(str.length / 2);
        var buffer = Buffer.alloc(len);
        var strIndex = 0;
        for (var i = 0; i < len; i++) {
            var high = parseInt(str[strIndex++] || '0', 10);
            var low = parseInt(str[strIndex++] || '0', 10);
            buffer[i] = (high << 4) | low;
        }
        return buffer;
    };
    /**
     * BCD时间转Date (格式: YYMMDDHHMMSS)
     */
    BCD.toDate = function (bcdStr) {
        var year = 2000 + parseInt(bcdStr.substring(0, 2), 10);
        var month = parseInt(bcdStr.substring(2, 4), 10) - 1;
        var day = parseInt(bcdStr.substring(4, 6), 10);
        var hour = parseInt(bcdStr.substring(6, 8), 10);
        var minute = parseInt(bcdStr.substring(8, 10), 10);
        var second = parseInt(bcdStr.substring(10, 12), 10);
        return new Date(year, month, day, hour, minute, second);
    };
    /**
     * Date转BCD时间字符串
     */
    BCD.fromDate = function (date) {
        var year = (date.getFullYear() - 2000).toString().padStart(2, '0');
        var month = (date.getMonth() + 1).toString().padStart(2, '0');
        var day = date.getDate().toString().padStart(2, '0');
        var hour = date.getHours().toString().padStart(2, '0');
        var minute = date.getMinutes().toString().padStart(2, '0');
        var second = date.getSeconds().toString().padStart(2, '0');
        return year + month + day + hour + minute + second;
    };
    return BCD;
}());
exports.BCD = BCD;
/**
 * 校验码计算 (异或校验)
 */
function calculateChecksum(buffer) {
    var checksum = 0;
    for (var i = 0; i < buffer.length; i++) {
        checksum ^= buffer[i];
    }
    return checksum;
}
/**
 * 消息转义 (0x7D -> 0x7D 0x01, 0x7E -> 0x7D 0x02)
 */
function escape(buffer) {
    var result = [];
    for (var i = 0; i < buffer.length; i++) {
        if (buffer[i] === 0x7D) {
            result.push(0x7D, 0x01);
        }
        else if (buffer[i] === 0x7E) {
            result.push(0x7D, 0x02);
        }
        else {
            result.push(buffer[i]);
        }
    }
    return Buffer.from(result);
}
/**
 * 消息反转义
 */
function unescape(buffer) {
    var result = [];
    for (var i = 0; i < buffer.length; i++) {
        if (buffer[i] === 0x7D && i + 1 < buffer.length) {
            if (buffer[i + 1] === 0x01) {
                result.push(0x7D);
            }
            else if (buffer[i + 1] === 0x02) {
                result.push(0x7E);
            }
            i++;
        }
        else {
            result.push(buffer[i]);
        }
    }
    return Buffer.from(result);
}
/**
 * 经纬度转换 (JT808格式 -> 度)
 * JT808格式: 度×10^6，精确到百万分之一度 (例如: 31234567 = 31.234567度)
 */
function convertLatitude(value) {
    return value / 1000000;
}
function convertLongitude(value) {
    return value / 1000000;
}
/**
 * 经纬度转换 (度 -> JT808格式)
 * 度×10^6，精确到百万分之一度
 */
function toJT808Latitude(degrees) {
    return Math.round(degrees * 1000000);
}
function toJT808Longitude(degrees) {
    return Math.round(degrees * 1000000);
}
