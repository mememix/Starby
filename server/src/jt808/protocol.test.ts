/**
 * JT808协议单元测试
 */

import { BCD, calculateChecksum, escape, unescape, convertLatitude, convertLongitude } from './protocol';
import { JT808Parser } from './parser';
import { JT808Encoder } from './encoder';
import { MessageId, GeneralResponseResult, RegisterResponseResult } from './types';

describe('JT808 Protocol', () => {
  describe('BCD Encoding', () => {
    test('should convert buffer to BCD string', () => {
      const buffer = Buffer.from([0x01, 0x38, 0x00, 0x00, 0x00, 0x01]);
      const result = BCD.toString(buffer);
      expect(result).toBe('013800000001');
    });

    test('should convert string to BCD buffer', () => {
      const str = '013800000001';
      const result = BCD.fromString(str);
      expect(result).toEqual(Buffer.from([0x01, 0x38, 0x00, 0x00, 0x00, 0x01]));
    });

    test('should convert BCD time to Date', () => {
      const bcdStr = '260314121500';
      const result = BCD.toDate(bcdStr);
      expect(result.getFullYear()).toBe(2026);
      expect(result.getMonth()).toBe(2); // March (0-indexed)
      expect(result.getDate()).toBe(14);
      expect(result.getHours()).toBe(12);
      expect(result.getMinutes()).toBe(15);
      expect(result.getSeconds()).toBe(0);
    });
  });

  describe('Checksum', () => {
    test('should calculate XOR checksum', () => {
      const buffer = Buffer.from([0x01, 0x02, 0x03, 0x04]);
      const checksum = calculateChecksum(buffer);
      expect(checksum).toBe(0x04); // 0x01 ^ 0x02 ^ 0x03 ^ 0x04 = 0x04
    });
  });

  describe('Escape/Unescape', () => {
    test('should escape 0x7E to 0x7D 0x02', () => {
      const buffer = Buffer.from([0x01, 0x7E, 0x02]);
      const escaped = escape(buffer);
      expect(escaped).toEqual(Buffer.from([0x01, 0x7D, 0x02, 0x02]));
    });

    test('should escape 0x7D to 0x7D 0x01', () => {
      const buffer = Buffer.from([0x01, 0x7D, 0x02]);
      const escaped = escape(buffer);
      expect(escaped).toEqual(Buffer.from([0x01, 0x7D, 0x01, 0x02]));
    });

    test('should unescape correctly', () => {
      const buffer = Buffer.from([0x01, 0x7D, 0x02, 0x02]);
      const unescaped = unescape(buffer);
      expect(unescaped).toEqual(Buffer.from([0x01, 0x7E, 0x02]));
    });
  });

  describe('Coordinate Conversion', () => {
    test('should convert JT808 latitude to degrees', () => {
      const jt808Lat = 30234567; // 30.234567度
      const degrees = convertLatitude(jt808Lat);
      expect(degrees).toBeCloseTo(30.234567, 6);
    });

    test('should convert JT808 longitude to degrees', () => {
      const jt808Lon = 121234567; // 121.234567度
      const degrees = convertLongitude(jt808Lon);
      expect(degrees).toBeCloseTo(121.234567, 6);
    });

    test('should convert degrees to JT808 latitude', () => {
      const degrees = 30.234567;
      const jt808Lat = toJT808Latitude(degrees);
      expect(jt808Lat).toBe(30234567);
    });

    test('should convert degrees to JT808 longitude', () => {
      const degrees = 121.234567;
      const jt808Lon = toJT808Longitude(degrees);
      expect(jt808Lon).toBe(121234567);
    });
  });
});

describe('JT808 Parser', () => {
  describe('parseTerminalRegister', () => {
    test('should parse terminal register message', () => {
      const body = Buffer.alloc(44);
      let offset = 0;
      
      // Province ID
      body.writeUInt16BE(31, offset);
      offset += 2;
      
      // City ID
      body.writeUInt16BE(100, offset);
      offset += 2;
      
      // Manufacturer ID (5 bytes)
      body.write('TEST1', offset);
      offset += 5;
      
      // Terminal Model (20 bytes)
      body.write('MODEL123'.padEnd(20, '\0'), offset);
      offset += 20;
      
      // Terminal ID (7 bytes)
      body.write('TERM001', offset);
      offset += 7;
      
      // License Plate Color
      body.writeUInt8(1, offset);
      offset += 1;
      
      // License Plate
      body.write('京A12345', offset);

      const result = JT808Parser.parseTerminalRegister(body);

      expect(result.provinceId).toBe(31);
      expect(result.cityId).toBe(100);
      expect(result.manufacturerId).toBe('TEST1');
      expect(result.terminalModel).toBe('MODEL123');
      expect(result.terminalId).toBe('TERM001');
      expect(result.licensePlateColor).toBe(1);
    });
  });

  describe('parseLocationReport', () => {
    test('should parse location report message', () => {
      const body = Buffer.alloc(28);
      let offset = 0;

      // Alarm flag
      body.writeUInt32BE(0x00000000, offset);
      offset += 4;

      // Status flag
      body.writeUInt32BE(0x00000003, offset); // ACC on, positioned
      offset += 4;

      // Latitude (30.234567 degrees -> 30234567)
      body.writeUInt32BE(30234567, offset);
      offset += 4;

      // Longitude (121.234567 degrees -> 121234567)
      body.writeUInt32BE(121234567, offset);
      offset += 4;

      // Altitude
      body.writeUInt16BE(100, offset);
      offset += 2;

      // Speed
      body.writeUInt16BE(600, offset); // 60.0 km/h
      offset += 2;

      // Direction
      body.writeUInt16BE(90, offset);
      offset += 2;

      // Time (BCD: 2026-03-14 12:15:00)
      const timeBuffer = Buffer.from([0x26, 0x03, 0x14, 0x12, 0x15, 0x00]);
      timeBuffer.copy(body, offset);

      const result = JT808Parser.parseLocationReport(body);

      expect(result.alarmFlag.emergency).toBe(false);
      expect(result.statusFlag.accOn).toBe(true);
      expect(result.statusFlag.positioned).toBe(true);
      expect(result.altitude).toBe(100);
      expect(result.speed).toBe(600);
      expect(result.direction).toBe(90);
    });
  });
});

describe('JT808 Encoder', () => {
  describe('encodeGeneralResponse', () => {
    test('should encode general response correctly', () => {
      const phoneNumber = '013800000001';
      const responseSerialNo = 1;
      const responseMessageId = MessageId.HEARTBEAT;
      const result = GeneralResponseResult.SUCCESS;

      const encoded = JT808Encoder.encodeGeneralResponse(
        phoneNumber,
        responseSerialNo,
        responseMessageId,
        result
      );

      // Check message structure
      expect(encoded[0]).toBe(0x7E); // Start flag
      expect(encoded[encoded.length - 1]).toBe(0x7E); // End flag

      // Unescape and verify content
      const unescaped = unescape(encoded.slice(1, -1));
      
      // Verify message ID (0x8001)
      expect(unescaped.readUInt16BE(0)).toBe(0x8001);
    });
  });

  describe('encodeTerminalRegisterResponse', () => {
    test('should encode terminal register response with auth code', () => {
      const phoneNumber = '013800000001';
      const responseSerialNo = 1;
      const result = RegisterResponseResult.SUCCESS;
      const authCode = 'AUTH1234';

      const encoded = JT808Encoder.encodeTerminalRegisterResponse(
        phoneNumber,
        responseSerialNo,
        result,
        authCode
      );

      // Check message structure
      expect(encoded[0]).toBe(0x7E); // Start flag
      expect(encoded[encoded.length - 1]).toBe(0x7E); // End flag

      // Verify message ID (0x8100)
      const unescaped = unescape(encoded.slice(1, -1));
      expect(unescaped.readUInt16BE(0)).toBe(0x8100);
    });
  });
});
