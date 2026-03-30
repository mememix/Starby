/**
 * JT808消息类型定义
 */

// 消息ID枚举
export enum MessageId {
  // 终端→平台
  HEARTBEAT = 0x0002,
  TERMINAL_REGISTER = 0x0100,
  TERMINAL_AUTH = 0x0102,
  LOCATION_REPORT = 0x0200,

  // 平台→终端
  GENERAL_RESPONSE = 0x8001,
  TERMINAL_REGISTER_RESPONSE = 0x8100,
}

// 通用应答结果
export enum GeneralResponseResult {
  SUCCESS = 0,
  FAILURE = 1,
  MESSAGE_ERROR = 2,
  UNSUPPORTED = 3,
}

// 终端注册应答结果
export enum RegisterResponseResult {
  SUCCESS = 0,
  ALREADY_REGISTERED = 1,
  NOT_FOUND = 2,
  VERSION_ERROR = 3,
}

// 位置信息报警标志
export interface AlarmFlag {
  emergency: boolean;        // 0: 紧急报警
  overspeed: boolean;        // 1: 超速报警
  fatigue: boolean;          // 2: 疲劳驾驶报警
  danger: boolean;           // 3: 危险预警
  gnssLost: boolean;         // 4: GNSS模块发生故障
  gnssAntennaLost: boolean;  // 5: GNSS天线未接或被剪断
  gnssAntennaShort: boolean; // 6: GNSS天线短路
  powerLow: boolean;         // 7: 终端主电源欠压
  powerLost: boolean;         // 8: 终端主电源掉电
  lcdLost: boolean;          // 9: 终端LCD或显示器故障
  ttsLost: boolean;          // 10: TTS模块故障
  cameraLost: boolean;       // 11: 摄像头故障
  icCardLost: boolean;       // 12: 道路运输证IC卡模块故障
  overspeedEarly: boolean;   // 13: 超速预警
  fatigueEarly: boolean;     // 14: 疲劳驾驶预警
  viotate: boolean;          // 15: 违规行驶报警
  gpsTimeLost: boolean;      // 16: GNSS定位时间丢失
  positionLost: boolean;      // 17: GNSS定位丢失
}

// 位置信息状态标志
export interface StatusFlag {
  accOn: boolean;            // 0: ACC开
  positioned: boolean;       // 1: 定位
  latSouth: boolean;         // 2: 纬度南纬
  lonWest: boolean;          // 3: 经度西经
  operation: boolean;        // 4: 运营状态
  encryption: boolean;       // 5: 经纬度加密
  load: boolean;             // 8: 车辆载货状态
  oil: boolean;              // 9: 车辆油路断开
  circuit: boolean;          // 10: 车辆电路断开
  doorLocked: boolean;       // 11: 车门锁闭
  frontDoorOpen: boolean;    // 12: 前门开
  backDoorOpen: boolean;     // 13: 后门开
  driverDoorOpen: boolean;   // 14: 司机门开
  otherDoorOpen: boolean;    // 15: 其他门开
  gpsSparse: boolean;        // 18: 使用GPS卫星进行定位
  beidouSparse: boolean;     // 19: 使用北斗卫星进行定位
  glonassSparse: boolean;    // 20: 使用GLONASS卫星进行定位
  galileoSparse: boolean;    // 21: 使用Galileo卫星进行定位
}

// JT808消息头
export interface MessageHeader {
  messageId: number;
  messageBodyProps: number;
  phoneNumber: string;
  messageSerialNo: number;
  packageCount?: number;
  packageNo?: number;
}

// JT808消息
export interface JT808Message {
  header: MessageHeader;
  body: Buffer;
}

// 终端注册消息体
export interface TerminalRegisterBody {
  provinceId: number;
  cityId: number;
  manufacturerId: string;
  terminalModel: string;
  terminalId: string;
  licensePlateColor: number;
  licensePlate: string;
}

// 终端鉴权消息体
export interface TerminalAuthBody {
  authCode: string;
}

// 位置信息汇报消息体
export interface LocationReportBody {
  alarmFlag: AlarmFlag;
  statusFlag: StatusFlag;
  latitude: number;      // 原始JT808格式
  longitude: number;     // 原始JT808格式
  altitude: number;
  speed: number;
  direction: number;
  time: Date;
  latDegrees: number;    // 转换后的度数
  lonDegrees: number;    // 转换后的度数
}

// 通用应答消息体
export interface GeneralResponseBody {
  responseSerialNo: number;
  responseMessageId: number;
  result: GeneralResponseResult;
}

// 终端注册应答消息体
export interface TerminalRegisterResponseBody {
  responseSerialNo: number;
  result: RegisterResponseResult;
  authCode?: string;
}

// 终端会话
export interface TerminalSession {
  phoneNumber: string;
  socket: any;  // net.Socket
  authCode?: string;
  registered: boolean;
  lastHeartbeat: Date;
  lastLocation?: LocationReportBody;
}
