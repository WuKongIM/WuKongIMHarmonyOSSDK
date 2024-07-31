import { WKPacketType } from './WKPacketType';
import { HashMap } from '@kit.ArkTS';
import {
  WKConnectAckPacket,
  WKConnectPacket,
  WKDisconnectPacket,
  WKPacket,
  WKPingPacket,
  WKPongPacket,
  WKRecvAckPacket,
  WKRecvPacket,
  WKSendAckPacket,
  WKSendPacket
} from './WKPacket';
import { WKReader } from './WKReader';
import { WKWriter } from './WKWriter';
import { WKIM } from '../WKIM';
import { CommonUtil } from '../common/CommonUtil';
import { WKLogger } from '../common/WKLogger';
import { WKMsgSetting } from '../entity/Bean';

export class WKPacketHeader {
  packetType: WKPacketType = WKPacketType.reserved
  noPersist: boolean = false
  redDot: boolean = true
  syncOnce: boolean = false
  remainingLength: number = 0
  hasServerVersion: boolean = false // connAck包是否返回了服务器版本号
}

export class WKProtocol {
  packetEncodeMap: HashMap<WKPacketType, (packet: WKPacket) => Array<number>> = new HashMap()
  packetDecodeMap: HashMap<WKPacketType, (header: WKPacketHeader, reader: WKReader) => WKPacket> = new HashMap()

  constructor() {
    this.packetEncodeMap[WKPacketType.connect] = encodeConnect
    this.packetEncodeMap[WKPacketType.send] = encodeSend
    this.packetEncodeMap[WKPacketType.recvAck] = encodeRecvAck

    this.packetDecodeMap[WKPacketType.recv] = decodeRecv
    this.packetDecodeMap[WKPacketType.connAck] = decodeConnAck
    this.packetDecodeMap[WKPacketType.sendAck] = decodeSendAck
    this.packetDecodeMap[WKPacketType.disconnect] = decodeDisconnect
  }

  encode(packet: WKPacket): Uint8Array {
    let writer = new WKWriter()
    if (packet.header.packetType != WKPacketType.ping && packet.header.packetType != WKPacketType.pong) {
      let func: (packet: WKPacket) => Array<number> = this.packetEncodeMap[packet.header.packetType]
      if (func === null || func === undefined) {
        WKLogger.error(`不支持的协议包->${packet.header.packetType}`)
      }
      let body: Array<number> = func!(packet)
      let header: Array<number> = encodeHeader(packet, body.length)
      writer.writeBytes(header)
      writer.writeBytes(body)
    } else {
      let header = encodeHeader(packet, 0)
      writer.writeBytes(header)
    }
    return writer.toUint8List()
  }

  decode(data: Uint8Array): WKPacket {
    let reader = new WKReader(data)
    let header = decodeHeader(reader)
    if (header.packetType == WKPacketType.ping) {
      return new WKPingPacket()
    }
    if (header.packetType == WKPacketType.pong) {
      return new WKPongPacket()
    }
    let func: (header: WKPacketHeader, reader: WKReader) => WKPacket = this.packetDecodeMap[header.packetType]
    if (func == null) {
      WKLogger.error(`不支持的协议包->${header.packetType}`)
    }
    return func(header, reader)
  }
}

function decodeHeader(reader: WKReader): WKPacketHeader {
  let b = reader.readByte()
  let header = new WKPacketHeader()
  header.noPersist = (b & 0x01) > 0
  header.redDot = ((b >> 1) & 0x01) > 0
  header.syncOnce = ((b >> 2) & 0x01) > 0
  header.packetType = (b >> 4) as WKPacketType
  if (header.packetType != WKPacketType.ping &&
    header.packetType != WKPacketType.pong) {
    header.remainingLength = reader.readVariableLength();
  }
  if (header.packetType === WKPacketType.connAck) {
    header.hasServerVersion = (b & 0x01) > 0;
  }
  return header;
}

function encodeHeader(packet: WKPacket, remainingLength: number) {
  if (packet.header.packetType == WKPacketType.ping ||
    packet.header.packetType == WKPacketType.pong) {
    return [(packet.header.packetType.valueOf() << 4) | 0];
  }
  let headers: Array<number> = [];
  let typeAndFlags = (encodeBool(false) << 3) |
    (encodeBool(packet.header.syncOnce) << 2) |
    (encodeBool(packet.header.redDot) << 1) |
  encodeBool(packet.header.noPersist)
  headers.push(packet.header.packetType.valueOf() << 4 | 0 | typeAndFlags)
  let vLen = encodeVariableLength(remainingLength)
  headers.push(...vLen)
  return headers;
}

function encodeBool(b: boolean) {
  return b ? 1 : 0;
}


function encodeVariableLength(len: number): Array<number> {
  let ret: Array<number> = []
  while (len > 0) {
    let digit = len % 0x80
    len = Math.floor(len / 0x80)
    if (len > 0) {
      digit |= 0x80
    }
    ret.push(digit)
  }
  return ret
}

function encodeConnect(packet: WKConnectPacket): Array<number> {
  let writer = new WKWriter()
  writer.writeUint8(WKIM.shared.config.protoVersion)
  writer.writeUint8(packet.deviceFlag)
  writer.writeString(packet.deviceID)
  writer.writeString(packet.uid)
  writer.writeString(packet.token)
  writer.writeUint64(BigInt(packet.clientTimestamp))
  writer.writeString(packet.clientKey)
  return writer.getData()
}

function encodeSend(packet: WKSendPacket): Array<number> {
  let writer = new WKWriter()
  writer.writeUint8(packet.setting.encode());
  writer.writeUint32(packet.clientSeq);
  writer.writeString(packet.clientMsgNo);
  if (packet.setting.stream == 1) {
    writer.writeString(packet.streamNo);
  }
  writer.writeString(packet.channelId);
  writer.writeUint8(packet.channelType);
  if (WKIM.shared.config.protoVersion >= 3) {
    writer.writeUint32(packet.expire);
  }
  writer.writeString(packet.encodeMsgKey());
  if (packet.setting.topic == 1) {
    writer.writeString(packet.topicId === undefined ? "" : packet.topicId)
  }
  let payload = CommonUtil.stringToNumbers(packet.encodeMsgContent())
  writer.writeBytes(payload)
  return writer.getData()
}

function encodeRecvAck(packet: WKRecvAckPacket): Array<number> {
  let writer = new WKWriter()
  writer.writeUint64(packet.messageId)
  writer.writeUint32(packet.messageSeq)
  return writer.getData()
}

function decodeConnAck(header: WKPacketHeader, reader: WKReader): WKConnectAckPacket {
  let connAck = new WKConnectAckPacket()
  if (header.hasServerVersion) {
    let serviceVersion = reader.readByte()
    let version = Math.min(serviceVersion, WKIM.shared.config.protoVersion)
    connAck.serviceProtoVersion = version
  }
  connAck.timeDiff = Number(reader.readUint64().valueOf())
  connAck.reasonCode = reader.readUint8()
  connAck.serverKey = reader.readString()
  connAck.salt = reader.readString()
  if (connAck.serviceProtoVersion >= 4) {
    connAck.nodeId = Number(reader.readUint64().valueOf())
  }
  return connAck
}

function decodeRecv(header: WKPacketHeader, reader: WKReader): WKRecvPacket {
  let recv = new WKRecvPacket()
  recv.header = header
  let setting = reader.readUint8();
  recv.setting = new WKMsgSetting().decode(setting)
  recv.msgKey = reader.readString()
  recv.fromUID = reader.readString()
  recv.channelId = reader.readString()
  recv.channelType = reader.readUint8()
  if (WKIM.shared.config.protoVersion >= 3) {
    recv.expire = reader.readUint32()
  }
  recv.clientMsgNo = reader.readString()
  if (recv.setting.stream == 1) {
    recv.streamNo = reader.readString()
    recv.streamSeq = reader.readUint32()
    recv.streamFlag = reader.readByte()
  }
  recv.messageId = reader.readUint64()
  recv.messageSeq = reader.readUint32()
  recv.messageTime = reader.readUint32()
  if (recv.setting.topic == 1) {
    recv.topicId = reader.readString();
  }
  let payload = reader.readRemaining()
  let str = String.fromCharCode(...payload)
  // recv.payload = CryptoUtils.aesDecrypt(str)
  recv.payload = str
  return recv
}

function decodeSendAck(_: WKPacketHeader, reader: WKReader): WKSendAckPacket {
  let sendAck = new WKSendAckPacket()
  sendAck.messageId = reader.readUint64().toString()
  sendAck.clientSeq = reader.readUint32()
  sendAck.messageSeq = reader.readUint32()
  sendAck.reasonCode = reader.readUint8()

  WKLogger.error(`sendAck messageID:${sendAck.messageId}`)
  WKLogger.error(`sendAck clientSeq:${sendAck.clientSeq}`)
  WKLogger.error(`sendAck messageSeq:${sendAck.messageSeq}`)
  WKLogger.error(`sendAck reasonCode:${sendAck.reasonCode}`)
  return sendAck
}

function decodeDisconnect(_: WKPacketHeader, reader: WKReader): WKDisconnectPacket {
  let disConn = new WKDisconnectPacket()
  disConn.reasonCode = reader.readUint8()
  disConn.reason = reader.readString()
  return disConn
}