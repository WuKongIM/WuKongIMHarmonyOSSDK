import socket from '@ohos.net.socket';
import { CommonUtil } from '../common/CommonUtil';
import { WKLogger } from '../common/WKLogger';
import { WKIM } from '../WKIM';
import { BusinessError } from '@kit.BasicServicesKit';
import {
  WKConnectAckPacket,
  WKConnectPacket,
  WKPacket,
  WKPingPacket,
  WKRecvAckPacket,
  WKRecvPacket,
  WKSendAckPacket,
  WKSendPacket
} from '../protocol/WKPacket';
import buffer from '@ohos.buffer';
import { WKReader } from '../protocol/WKReader';
import { WKPacketType } from '../protocol/WKPacketType';
import { StringBuilder } from '../common/StringBuilder';
import { CryptoUtils } from '../common/CryptoUtils';
import {
  ConnectionInfo,
  WKConnectStatus,
  WKConversation,
  WKMsg,
  WKMsgContentType,
  WKSendMsgResult
} from '../entity/Bean';
import { HashMap } from '@kit.ArkTS';
import { WKPacketHeader } from '../protocol/WKProtocol';
import { DateUtil } from '../common/DateUtil';
import connection from '@ohos.net.connection';
import { MessageDB } from '../db/MessageDB';
import { ConversationDB } from '../db/ConversationDB';
import { WKDBHelper } from '../db/WKDBHelper';

export type ConnStatusListener = (status: number, reasonCode?: number, connInfo?: ConnectionInfo) => void

export class ConnectionManager {
  static shared: ConnectionManager = new ConnectionManager();
  private tcpSocket?: socket.TCPSocket
  private ip: string = ''
  private port: number = 0
  private connectStatusListeners: ConnStatusListener[]
  private sendingMsgMap: HashMap<number, SendingMsg> = new HashMap()
  // private readonly checkNetInterval = 1000
  private readonly connTimeOut = 6000
  private checkNetIntervalId = 0
  private netConn?: connection.NetConnection
  private heartIntervalId = 0
  private requestIPIntervalId = 0
  private requestIPTime = 0
  private connStatus: number
  private isCanReconnect = true
  private networkChanged = false

  private constructor() {
    this.connectStatusListeners = new Array()
    this.connStatus = 1
  }

  addConnectStatusListener(l: ConnStatusListener) {
    this.connectStatusListeners.push(l)
  }

  removeConnectStatusListener(l: ConnStatusListener) {
    for (let i = 0; i < this.connectStatusListeners.length; i++) {
      if (this.connectStatusListeners[i] === l) {
        this.connectStatusListeners.splice(i, 1)
        break
      }
    }
  }

  private setConnectStatus(status: number,reasonCode?:number,connInfo?:ConnectionInfo) {
    this.connectStatusListeners.forEach((back) => {
      back(status,reasonCode,connInfo)
    })
  }

  private close(isReconnect: boolean) {
    this.tcpSocket?.off('message')
    this.tcpSocket?.off('connect')
    this.tcpSocket?.off('close')
    this.tcpSocket?.close((err) => {
      if (err) {
        WKLogger.error(`关闭连接错误，code:${err.code},msg:${err.message}`)
      }
      this.connStatus = ConnStatus.fail
      this.tcpSocket = undefined
      if (isReconnect) {
        setTimeout(() => {
          this.connection()
        }, 1000)

      }
    })
  }

  disConnection(isLogout: boolean) {
    this.clearCheckNetworkTimer()
    this.clearHeartTimer()
    this.close(false)
    if (isLogout) {
      MessageDB.shared.updateSendingToFail()
      WKDBHelper.shared.closeDB()
      WKIM.shared.config.uid = undefined
      WKIM.shared.config.token = undefined
      WKIM.shared.config.address = undefined
    }
  }

  connection() {
    if (CommonUtil.strIsEmpty(WKIM.shared.config.uid ?? '') ||
    CommonUtil.strIsEmpty(WKIM.shared.config.token ?? '')) {
      WKLogger.error("未初始化uid或token未空")
      return
    }
    if (this.connStatus === ConnStatus.conning) {
      return
    }
    this.connStatus = ConnStatus.conning
    this.setConnectStatus(WKConnectStatus.connecting)
    if (CommonUtil.strIsUnEmpty(WKIM.shared.config.address ?? '')) {
      let addr = WKIM.shared.config.address?.split(":")
      this.ip = addr![0]
      this.port = Number(addr![1])
      ConnectionManager.shared.connectionSocket()
    } else {
      if (WKIM.shared.config.provider.connectAddrCallback !== undefined) {
        this.requestIPIntervalId = setInterval(() => {
          if (this.ip !== '') {
            clearInterval(this.requestIPIntervalId)
          }
          WKLogger.error(`请求IP倒计时:${this.requestIPTime}/${WKIM.shared.config.requestIPTimeout}`)
          if (this.ip === '' && this.requestIPTime >= WKIM.shared.config.requestIPTimeout) {
            clearInterval(this.requestIPIntervalId)
            this.close(true)
          }
          this.requestIPTime += 1000
        }, 1000)
        WKIM.shared.config.provider.connectAddrCallback()
          .then((address) => {
            let addr = address.split(":")
            this.ip = addr![0]
            this.port = Number(addr![1])
            ConnectionManager.shared.connectionSocket()
            clearInterval(this.requestIPIntervalId)
          })
      } else {
        WKLogger.error('未提供connectAddrCallback')
      }
    }

  }

  private connectionSocket() {
    if (CommonUtil.strIsEmpty(this.ip) || this.port === 0) {
      WKLogger.error(`非法地址，address:${this.ip}:${this.port}`)
      this.close(true)
      return
    }
    this.tcpSocket = socket.constructTCPSocketInstance()
    let options: socket.TCPConnectOptions = {
      address: this.getAddress(),
      timeout: this.connTimeOut
    }
    this.tcpSocket.connect(options).then(() => {
      WKLogger.error('连接成功')
      this.connStatus = ConnStatus.success
      this.addOnMessage()
      this.sendConnPacket()
    }).catch((err: BusinessError) => {
      this.connStatus = ConnStatus.fail
      this.close(true)
      WKLogger.error(`连接socket错误，code:${err.code},message:${err.message}`)
    })

  }

  private addOnMessage() {
    this.tcpSocket?.on('message', (value: socket.SocketMessageInfo) => {
      let data = new Uint8Array(value.message)
      this.cutData(data)
    })
    this.tcpSocket?.on('close', () => {
      WKLogger.error('断开连接')
    })
    this.tcpSocket?.on('connect', () => {
      WKLogger.error('已连接')
    })
  }

  _cacheData?: Uint8Array | null

  private cutData(data: Uint8Array) {
    if (this._cacheData == null || this._cacheData?.length == 0) {
      this._cacheData = data
    } else {
      // 上次存在未解析完的消息
      let temp = new Uint8Array([...this._cacheData, ...data])
      this._cacheData = temp
    }

    let lastMsgBytes = this._cacheData!
    let readLength = 0
    while (lastMsgBytes.length > 0 && readLength != lastMsgBytes.length) {
      readLength = lastMsgBytes.length
      let readData = new WKReader(lastMsgBytes)
      let b = readData.readUint8()
      let packetType = b >> 4
      if ((b >> 4) == WKPacketType.pong) {
        WKLogger.debug('pong')
        let bytes = lastMsgBytes.subarray(1, lastMsgBytes.length)
        this._cacheData = lastMsgBytes = bytes
      } else {
        if (packetType < 10) {
          if (lastMsgBytes.length < 5) {
            this._cacheData = lastMsgBytes;
            break;
          }
          let remainingLength = readData.readVariableLength();
          if (remainingLength == -1) {
            //剩余长度被分包
            this._cacheData = lastMsgBytes;
            break;
          }
          if (remainingLength > 1 << 21) {
            this._cacheData = null;
            break;
          }
          let bytes = this.encodeVariableLength(remainingLength);

          if (remainingLength + 1 + bytes.length > lastMsgBytes.length) {
            //半包情况
            this._cacheData = lastMsgBytes;
          } else {
            let msg = lastMsgBytes.subarray(0, remainingLength + 1 + bytes.length)
            this.decodePacket(msg)
            let temps =
              lastMsgBytes.subarray(msg.length, lastMsgBytes.length);
            this._cacheData = lastMsgBytes = temps;
          }
        } else {
          this._cacheData = null;
          // 数据包错误，重连
          this.connection();
          break;
        }
      }
    }
  }

  encodeVariableLength(len: number): Array<number> {
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

  private decodePacket(data: Uint8Array) {
    let packet = WKIM.shared.config.protocol.decode(data)
    WKLogger.error(`包类型：${packet?.header.packetType}`)
    if (packet.header.packetType === WKPacketType.connAck) {
      let connAck = packet as WKConnectAckPacket
      if (connAck.reasonCode === 1) {
        WKIM.shared.config.protoVersion = connAck.serviceProtoVersion
        CryptoUtils.setServerKeyAndSalt(connAck.serverKey, connAck.salt)
        this.resendMsg()
        this.startCheckNetworkTimer()
        this.startHeartTimer()
        this.setConnectStatus(WKConnectStatus.success,connAck.reasonCode,new ConnectionInfo(connAck.nodeId))
        this.setConnectStatus(WKConnectStatus.syncing)
        WKLogger.error('连接ack成功')
        WKIM.shared.conversationManager().sync().then(() => {
          this.setConnectStatus(WKConnectStatus.syncCompleted)
        })
      } else {
        let status = WKConnectStatus.fail
        if (connAck.reasonCode === WKConnectStatus.kicked) {
          status = WKConnectStatus.kicked
        }
        this.setConnectStatus(status,connAck.reasonCode)
        WKLogger.error(`连接失败，code:${connAck.reasonCode}`)
      }
    } else if (packet.header.packetType === WKPacketType.recv) {
      let recvPacket = packet as WKRecvPacket
      this.verifyRecvMsg(recvPacket)
      if (!recvPacket.header.noPersist) {
        this.sendRecvAckPacket(
          recvPacket.messageId, recvPacket.messageSeq, recvPacket.header)
      }
    } else if (packet.header.packetType === WKPacketType.sendAck) {
      let sendAck = packet as WKSendAckPacket
      WKIM.shared.messageManager().setSendStatus(sendAck)
    } else if (packet.header.packetType === WKPacketType.disconnect) {
      this.disConnection(true)
      this.setConnectStatus(WKConnectStatus.kicked)
    } else if (packet.header.packetType == WKPacketType.pong) {
      WKLogger.info('pong')
    }
  }

  private sendRecvAckPacket(messageId: BigInt, messageSeq: number, header: WKPacketHeader) {
    let ackPacket = new WKRecvAckPacket()
    ackPacket.header.noPersist = header.noPersist
    ackPacket.header.syncOnce = header.syncOnce
    ackPacket.header.redDot = header.redDot
    ackPacket.messageId = messageId
    ackPacket.messageSeq = messageSeq
    this.sendPacket(ackPacket)
  }

  private verifyRecvMsg(packet: WKRecvPacket) {
    let sb = new StringBuilder()
    sb.append(packet.messageId.toString())
    sb.append(packet.messageSeq)
    sb.append(packet.clientMsgNo)
    sb.append(packet.messageTime)
    sb.append(packet.fromUID)
    sb.append(packet.channelId)
    sb.append(packet.channelType)
    sb.append(packet.payload)
    let encryptContent = sb.toString()
    let result = CryptoUtils.aesEncrypt(encryptContent)
    let localMsgKey = CryptoUtils.digestMD5(CommonUtil.stringToUint8Array(result))
    if (packet.msgKey != localMsgKey) {
      WKLogger.error(`非法消息-->期望msgKey：$localMsgKey，实际msgKey：${packet.msgKey}`)
      return
    } else {
      packet.payload = CryptoUtils.aesDecrypt(packet.payload)
      WKLogger.debug(packet.toString())
      this.saveRecvMsg(packet)
    }
  }

  private saveRecvMsg(packet: WKRecvPacket) {
    let msg = new WKMsg()
    msg.header.noPersist = packet.header.noPersist
    msg.header.syncOnce = packet.header.syncOnce
    msg.header.redDot = packet.header.redDot
    msg.setting = packet.setting
    msg.status = WKSendMsgResult.success
    msg.messageId = packet.messageId.toString()
    msg.messageSeq = packet.messageSeq
    msg.timestamp = packet.messageTime
    msg.expireTime = packet.expire
    if (msg.expireTime > 0) {
      msg.expireTimestamp = msg.expireTime + msg.timestamp
    }
    msg.clientMsgNo = packet.clientMsgNo
    msg.fromUID = packet.fromUID
    msg.channelId = packet.channelId
    msg.channelType = packet.channelType
    msg.topicId = packet.topicId
    msg.content = packet.payload
    WKIM.shared.messageManager().parsingMsg(msg)
    if (packet.header.noPersist === false && packet.header.syncOnce === false) {
      let seq = MessageDB.shared.insert(msg)
      msg.clientSeq = seq
      let conv = ConversationDB.shared.insertWithWKMsg(msg,false)
      let list: WKConversation[] = []
      list.push(conv)
      WKIM.shared.conversationManager().setRefresh(list)
    }
    if (msg.contentType !== WKMsgContentType.InsideMsg) {
      let list = new Array<WKMsg>()
      list.push(msg)
      WKIM.shared.messageManager().pushNewMsgs(list)
    }
  }

  private sendConnPacket() {
    this.sendPacket(new WKConnectPacket())
  }

  sendPacket(packet: WKPacket) {
    if (packet.header.packetType === WKPacketType.send) {
      let send = packet as WKSendPacket
      this.removeSendingMsg()
      this.sendingMsgMap.set(send.clientSeq, new SendingMsg(send))
    }
    let data = WKIM.shared.config.protocol.encode(packet)
    let tcpSendOption: socket.TCPSendOptions = {
      data: buffer.from(data).buffer
    }
    this.tcpSocket?.send(tcpSendOption).then(() => {
      WKLogger.debug(`发送消息成功`)
    }).catch((err: BusinessError) => {
      WKLogger.error(`发送消息错误，code:${err.code},message:${err.message}`)
      this.close(true)
    });
  }

  private getAddress(): socket.NetAddress {
    WKLogger.error(`绑定的IP：${this.ip},${this.port}`)
    let address: socket.NetAddress = {
      address: this.ip,
      port: this.port
    }
    return address

  }

  private resendMsg() {
    if (this.sendingMsgMap.isEmpty()) {
      return
    }
    this.sendingMsgMap.forEach((msg) => {
      if (msg?.isCanResend) {
        this.sendPacket(msg.packet)
      }
    })
  }

  private removeSendingMsg() {
    if (!this.sendingMsgMap.isEmpty()) {
      let ids: number[] = new Array()
      this.sendingMsgMap.forEach((sendingMsg, key) => {
        if (sendingMsg?.isCanResend) {
          ids.push(key!)
        }
      });
      if (ids.length > 0) {
        for (let i = 0; i < ids.length; i++) {
          this.sendingMsgMap.remove(ids[i])
        }
      }
    }
  }

  private checkSendingMsg() {
    if (this.sendingMsgMap.isEmpty()) {
      return
    }
    this.sendingMsgMap.forEach((v, k) => {
      if (v?.sendCount === 5 && v.isCanResend) {
        v.isCanResend = false
        // 修改发送状态
      } else {
        let nowTime = DateUtil.getCurrentSeconds()
        if (nowTime - v?.sendTime! > 10) {
          v!.sendTime = nowTime
          v!.sendCount++
          this.sendingMsgMap.set(k, v)
          this.sendPacket(v?.packet!)
          WKLogger.debug("消息发送失败，尝试重发中...");
        }
      }
    })
    this.removeSendingMsg()
  }

  private startCheckNetworkTimer() {
    this.clearCheckNetworkTimer()
    if (this.netConn === undefined) {
      this.netConn = connection.createNetConnection()
      this.netConn.register((err) => {
        if (err) {
          WKLogger.error(`订阅网络状态错误，code:${err.code},msg:${err.message}`)
        } else {
          WKLogger.error('订阅网络状态成功')
          this.addNetworkListener()
        }
      })
    }
  }

  private addNetworkListener() {
    this.netConn?.on('netAvailable', () => {
      // 网络可用
      if (this.isCanReconnect && this.networkChanged) {
        this.close(true)
      }
      this.networkChanged = false
      WKLogger.error('网络正常')
    })
    this.netConn?.on('netUnavailable', () => {
      // 网络不可用
      WKLogger.error('网络不可用')
      this.networkChanged = true
      this.setConnectStatus(WKConnectStatus.noNetwork)
      this.checkSendingMsg()
    })
    this.netConn?.on('netLost', () => {
      this.networkChanged = true
      this.setConnectStatus(WKConnectStatus.noNetwork)
      WKLogger.error('网络丢失')
    })
  }

  private clearCheckNetworkTimer() {
    if (this.checkNetIntervalId !== 0) {
      clearInterval(this.checkNetIntervalId)
    }
  }

  private startHeartTimer() {
    this.clearHeartTimer()
    this.heartIntervalId = setInterval(() => {
      this.sendPacket(new WKPingPacket())
      WKLogger.debug('ping')
    }, WKIM.shared.config.heartbeatInterval)
  }

  private clearHeartTimer() {
    if (this.heartIntervalId !== 0) {
      clearInterval(this.heartIntervalId)
    }
  }
}

export class SendingMsg {
  packet: WKSendPacket
  sendCount = 0
  sendTime = 0
  isCanResend = false

  constructor(packet: WKSendPacket) {
    this.packet = packet
    this.sendTime = DateUtil.getCurrentSeconds()
  }
}

export class ConnStatus {
  static readonly unknown = 1
  static readonly conning = 2
  static readonly success = 3
  static readonly fail = 4
}