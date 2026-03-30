"use strict";
/**
 * JT808消息类型定义
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.RegisterResponseResult = exports.GeneralResponseResult = exports.MessageId = void 0;
// 消息ID枚举
var MessageId;
(function (MessageId) {
    // 终端→平台
    MessageId[MessageId["HEARTBEAT"] = 2] = "HEARTBEAT";
    MessageId[MessageId["TERMINAL_REGISTER"] = 256] = "TERMINAL_REGISTER";
    MessageId[MessageId["TERMINAL_AUTH"] = 258] = "TERMINAL_AUTH";
    MessageId[MessageId["LOCATION_REPORT"] = 512] = "LOCATION_REPORT";
    // 平台→终端
    MessageId[MessageId["GENERAL_RESPONSE"] = 32769] = "GENERAL_RESPONSE";
    MessageId[MessageId["TERMINAL_REGISTER_RESPONSE"] = 33024] = "TERMINAL_REGISTER_RESPONSE";
})(MessageId || (exports.MessageId = MessageId = {}));
// 通用应答结果
var GeneralResponseResult;
(function (GeneralResponseResult) {
    GeneralResponseResult[GeneralResponseResult["SUCCESS"] = 0] = "SUCCESS";
    GeneralResponseResult[GeneralResponseResult["FAILURE"] = 1] = "FAILURE";
    GeneralResponseResult[GeneralResponseResult["MESSAGE_ERROR"] = 2] = "MESSAGE_ERROR";
    GeneralResponseResult[GeneralResponseResult["UNSUPPORTED"] = 3] = "UNSUPPORTED";
})(GeneralResponseResult || (exports.GeneralResponseResult = GeneralResponseResult = {}));
// 终端注册应答结果
var RegisterResponseResult;
(function (RegisterResponseResult) {
    RegisterResponseResult[RegisterResponseResult["SUCCESS"] = 0] = "SUCCESS";
    RegisterResponseResult[RegisterResponseResult["ALREADY_REGISTERED"] = 1] = "ALREADY_REGISTERED";
    RegisterResponseResult[RegisterResponseResult["NOT_FOUND"] = 2] = "NOT_FOUND";
    RegisterResponseResult[RegisterResponseResult["VERSION_ERROR"] = 3] = "VERSION_ERROR";
})(RegisterResponseResult || (exports.RegisterResponseResult = RegisterResponseResult = {}));
