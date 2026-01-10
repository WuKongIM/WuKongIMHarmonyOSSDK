import { CommonUtil } from '../common/CommonUtil'
import { CryptoUtils } from '../common/CryptoUtils'
import { DateUtil } from '../common/DateUtil'
import { PreferencesUtil } from '../common/PreferencesUtil'
import { StringBuilder } from '../common/StringBuilder'
import { WKMsgSetting } from '../entity/Bean'
import { WKIM } from '../WKIM'
import { WKPacketType } from './WKPacketType'
import { WKPacketHeader } from './WKProtocol'

export class WKPacket {
  header: WKPacketHeader = new WKPacketHeader()
  flag: number = 0
}

export class WKPingPacket extends WKPacket {
  constructor() {
    super()
    this.header.packetType = WKPacketType.ping
  }
}

export class WKPongPacket extends WKPacket {
  constructor() {
    super();
    this.header.packetType = WKPacketType.pong
  }
}

export class WKConnectPacket extends WKPacket {
  deviceFlag: number = 0
  deviceID: string
  uid: string
  token: string
  serverKey = ''
  salt = ''
  timeDiff = 0
  reasonCode = 0
  clientTimestamp: number
  clientKey: string = ''

  constructor() {
    super()
    this.header.packetType = WKPacketType.connect
    this.deviceID = PreferencesUtil.getDeviceId()
    this.uid = WKIM.shared.config.uid!
    this.token = WKIM.shared.config.token!
    this.clientTimestamp = DateUtil.getCurrentMills()
    this.clientKey = CryptoUtils.shared.getPublicKey()
    this.deviceFlag = WKIM.shared.config.deviceFlagApp
  }
}

export class WKConnectAckPacket extends WKPacket {
  timeDiff: number = 0
  reasonCode: number = 0
  serverKey: string = ''
  salt: string = ''
  nodeId: number = 0
  serviceProtoVersion: number = 0

  constructor() {
    super();
    this.header.packetType = WKPacketType.connAck
  }
}


export class WKDisconnectPacket extends WKPacket {
  reasonCode: number = 0
  reason: string = ''

  constructor() {
    super()
    this.header.packetType = WKPacketType.disconnect
  }
}

export class WKRecvAckPacket extends WKPacket {
  messageId: BigInt = BigInt(0)
  messageSeq: number = 0

  constructor() {
    super();
    this.header.packetType = WKPacketType.recvAck
  }
}

export class WKRecvPacket extends WKPacket {
  setting: WKMsgSetting = new WKMsgSetting()
  msgKey: string = ''
  fromUID: string = ''
  channelId: string = ''
  channelType: number = 0
  clientMsgNo: string = ''
  streamNo: string = ''
  streamSeq: number = 0
  streamFlag: number = 0
  messageId: BigInt = BigInt('0')
  messageSeq: number = 0
  messageTime: number = 0
  expire: number = 0
  topicId: string = ''
  payload: string = ''

  constructor() {
    super();
    this.header.packetType = WKPacketType.recv
  }
}

export class WKSendPacket extends WKPacket {
  setting: WKMsgSetting = new WKMsgSetting()
  clientSeq: number = 0
  channelId: string = ''
  channelType: number = 0
  payload: string = ''
  clientMsgNo: string = ''
  topicId?: string
  expire: number = 0
  streamNo: string = ''

  constructor() {
    super();
    this.header.packetType = WKPacketType.send
  }


  encodeMsgKey(): string {
    let content = this.encodeMsgContent()
    let sb = new StringBuilder()
    sb.append(this.clientSeq)
    sb.append(this.clientMsgNo)
    sb.append(this.channelId)
    sb.append(this.channelType)
    sb.append(content)
    let msgKey = CryptoUtils.shared.aesEncrypt(sb.toString())
    return CryptoUtils.shared.digestMD5(CommonUtil.stringToUint8Array(msgKey))
  }

  encodeMsgContent(): string {
    return CryptoUtils.shared.aesEncrypt(this.payload)
  }
}

export class WKSendAckPacket extends WKPacket {
  clientSeq: number = 0
  messageId: string = ''
  messageSeq: number = 0
  reasonCode: number = 0

  constructor() {
    super();
    this.header.packetType = WKPacketType.sendAck
  }
}
