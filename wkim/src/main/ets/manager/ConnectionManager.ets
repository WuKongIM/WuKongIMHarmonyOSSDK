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
  private readonly checkSendingInterval = 1000
  private readonly sendAckTimeout = 10
  private readonly maxSendAttempts = 5
  private readonly connTimeOut = 6000
  private checkNetIntervalId = 0
  private netConn?: connection.NetConnection
  private heartIntervalId = 0
  private requestIPIntervalId = 0
  private requestIPTime = 0
  private reconnectTimerId = 0
  private connAckTimerId = 0
  private connectionAttemptId = 0
  private connStatus: number
  private isCanReconnect = true
  private networkChanged = false
  private connectStatus = WKConnectStatus.fail

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

  private setConnectStatus(status: number, reasonCode?: number, connInfo?: ConnectionInfo) {
    this.connectStatus = status
    this.connectStatusListeners.forEach((back) => {
      back(status, reasonCode, connInfo)
    })
  }

  private close(isReconnect: boolean) {
    this.connectionAttemptId++
    const socket = this.tcpSocket
    this.tcpSocket = undefined
    this.connStatus = ConnStatus.fail
    this._cacheData = null
    this.clearConnAckTimer()
    this.clearHeartTimer()
    this.clearCheckNetworkTimer()
    CryptoUtils.shared.clear()
    if (isReconnect) {
      this.scheduleReconnect()
    }
    if (socket === undefined) {
      return
    }
    socket.off('message')
    socket.off('connect')
    socket.off('close')
    socket.off('error')
    socket.close((err) => {
      if (err) {
        WKLogger.error(`关闭连接错误，code:${err.code},msg:${err.message}`)
      }
    })
  }

  private scheduleReconnect() {
    if (!this.isCanReconnect || this.reconnectTimerId !== 0) {
      return
    }
    this.reconnectTimerId = setTimeout(() => {
      this.reconnectTimerId = 0
      this.connection()
    }, 1000)
  }

  private clearReconnectTimer() {
    if (this.reconnectTimerId !== 0) {
      clearTimeout(this.reconnectTimerId)
      this.reconnectTimerId = 0
    }
  }

  private clearConnAckTimer() {
    if (this.connAckTimerId !== 0) {
      clearTimeout(this.connAckTimerId)
      this.connAckTimerId = 0
    }
  }

  private clearRequestIPTimer() {
    if (this.requestIPIntervalId !== 0) {
      clearInterval(this.requestIPIntervalId)
      this.requestIPIntervalId = 0
    }
    this.requestIPTime = 0
  }

  private handleConnectionFailure(message: string, shouldReconnect: boolean = true) {
    WKLogger.error(message)
    this.clearRequestIPTimer()
    this.setConnectStatus(WKConnectStatus.fail)
    this.close(shouldReconnect)
  }

  disConnection(isLogout: boolean) {
    this.isCanReconnect = false
    this.clearReconnectTimer()
    this.clearRequestIPTimer()
    this.clearCheckNetworkTimer()
    this.clearHeartTimer()
    this.close(false)
    this.setConnectStatus(WKConnectStatus.fail)
    if (isLogout) {
      MessageDB.shared.updateSendingToFail()
      try {
        this.sendingMsgMap.clear()
      } catch (e) {
        WKLogger.error(`清理发送队列失败，error:${e}`)
      }
      WKDBHelper.shared.closeDB()
      CryptoUtils.shared.clear()
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
    if (this.connStatus === ConnStatus.conning || this.connStatus === ConnStatus.authenticating ||
      this.connStatus === ConnStatus.success) {
      return
    }
    this.isCanReconnect = true
    this.clearReconnectTimer()
    this.clearRequestIPTimer()
    const attemptId = ++this.connectionAttemptId
    this.connStatus = ConnStatus.conning
    this.setConnectStatus(WKConnectStatus.connecting)
    if (CommonUtil.strIsUnEmpty(WKIM.shared.config.address ?? '')) {
      let addr = WKIM.shared.config.address?.split(":")
      this.ip = addr![0]
      this.port = Number(addr![1])
      ConnectionManager.shared.connectionSocket()
    } else {
      if (WKIM.shared.config.provider.connectAddrCallback !== undefined) {
        // Always wait for the current provider result. A stale address from the previous
        // connection must not disable this attempt's address timeout.
        this.ip = ''
        this.port = 0
        this.requestIPIntervalId = setInterval(() => {
          if (attemptId !== this.connectionAttemptId) {
            return
          }
          if (this.ip !== '') {
            this.clearRequestIPTimer()
            return
          }
          WKLogger.error(`请求IP倒计时:${this.requestIPTime}/${WKIM.shared.config.requestIPTimeout}`)
          if (this.ip === '' && this.requestIPTime >= WKIM.shared.config.requestIPTimeout) {
            this.handleConnectionFailure('请求连接地址超时')
            return
          }
          this.requestIPTime += 1000
        }, 1000)
        WKIM.shared.config.provider.connectAddrCallback()
          .then((address) => {
            if (attemptId !== this.connectionAttemptId) {
              return
            }
            this.clearRequestIPTimer()
            let addr = address.split(":")
            this.ip = addr![0]
            this.port = Number(addr![1])
            ConnectionManager.shared.connectionSocket()
          })
          .catch((error: Error) => {
            if (attemptId !== this.connectionAttemptId) {
              return
            }
            this.handleConnectionFailure(`请求连接地址失败:${error.message}`)
          })
      } else {
        this.handleConnectionFailure('未提供connectAddrCallback', false)
      }
    }

  }

  private connectionSocket() {
    if (CommonUtil.strIsEmpty(this.ip) || !Number.isInteger(this.port) || this.port < 1 || this.port > 65535) {
      this.handleConnectionFailure(`非法地址，address:${this.ip}:${this.port}`)
      return
    }
    const attemptId = this.connectionAttemptId
    const tcpSocket = socket.constructTCPSocketInstance()
    this.tcpSocket = tcpSocket
    let options: socket.TCPConnectOptions = {
      address: this.getAddress(),
      timeout: this.connTimeOut
    }
    tcpSocket.connect(options).then(() => {
      if (attemptId !== this.connectionAttemptId || this.tcpSocket !== tcpSocket) {
        return
      }
      WKLogger.error('连接成功')
      this.connStatus = ConnStatus.authenticating
      this.addOnMessage(tcpSocket, attemptId)
      this.connAckTimerId = setTimeout(() => {
        if (attemptId === this.connectionAttemptId && this.tcpSocket === tcpSocket &&
          this.connStatus === ConnStatus.authenticating) {
          this.handleConnectionFailure('连接认证超时')
        }
      }, this.connTimeOut)
      this.sendConnPacket(tcpSocket, attemptId)
    }).catch((err: BusinessError) => {
      if (attemptId !== this.connectionAttemptId || this.tcpSocket !== tcpSocket) {
        return
      }
      this.handleConnectionFailure(`连接socket错误，code:${err.code},message:${err.message}`)
    })

  }

  private addOnMessage(tcpSocket: socket.TCPSocket, attemptId: number) {
    tcpSocket.on('message', (value: socket.SocketMessageInfo) => {
      if (attemptId !== this.connectionAttemptId || this.tcpSocket !== tcpSocket) {
        return
      }
      // let data = new Uint8Array(value.message)
      // this.cutData(data)
      let data = new Uint8Array(value.message).slice() // 或 new Uint8Array([...new Uint8Array(value.message)])
      this.cutData(data)
    })
    tcpSocket.on('close', () => {
      if (attemptId !== this.connectionAttemptId || this.tcpSocket !== tcpSocket) {
        return
      }
      this.handleConnectionFailure('连接被动断开')
    })
    tcpSocket.on('error', (err: BusinessError) => {
      if (attemptId !== this.connectionAttemptId || this.tcpSocket !== tcpSocket) {
        return
      }
      this.handleConnectionFailure(`连接异常，code:${err.code},message:${err.message}`)
    })
    tcpSocket.on('connect', () => {
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
          // 在解析 remainingLength 之前，先检查至少有足够字节读取 header
          if (lastMsgBytes.length < 2) {
            // 数据不足，等待更多数据
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
          this.handleConnectionFailure('收到非法数据包')
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
    if (packet === undefined) {
      WKLogger.error(`未知包--->`)
      return
    }
    WKLogger.error(`包类型：${packet?.header.packetType}`)
    if (packet.header.packetType === WKPacketType.connAck) {
      let connAck = packet as WKConnectAckPacket
      if (connAck.reasonCode === 1) {
        this.clearConnAckTimer()
        WKIM.shared.config.protoVersion = connAck.serviceProtoVersion
        CryptoUtils.shared.setServerKeyAndSalt(connAck.serverKey, connAck.salt)
        if (!CryptoUtils.shared.isReady) {
          this.handleConnectionFailure('连接会话密钥生成失败')
          return
        }
        this.connStatus = ConnStatus.success
        this.resendMsg()
        this.startCheckNetworkTimer()
        this.startSendingCheckTimer()
        this.startHeartTimer()
        this.setConnectStatus(WKConnectStatus.success, connAck.reasonCode, new ConnectionInfo(connAck.nodeId))
        this.setConnectStatus(WKConnectStatus.syncing)
        WKLogger.error('连接成功')
        const syncAttemptId = this.connectionAttemptId
        WKIM.shared.conversationManager().sync().then(() => {
          if (syncAttemptId === this.connectionAttemptId && this.isConnected()) {
            this.setConnectStatus(WKConnectStatus.syncCompleted)
          }
        }).catch((e: Error) => {
          WKLogger.error(`同步会话失败:${e.message}`)
          if (syncAttemptId === this.connectionAttemptId && this.isConnected()) {
            this.setConnectStatus(WKConnectStatus.success)
          }
        })
      } else {
        let status = WKConnectStatus.fail
        if (connAck.reasonCode === WKConnectStatus.kicked) {
          status = WKConnectStatus.kicked
        }
        this.setConnectStatus(status, connAck.reasonCode)
        WKLogger.error(`连接失败，code:${connAck.reasonCode}`)
        this.isCanReconnect = false
        this.close(false)
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
      try {
        this.sendingMsgMap.remove(sendAck.clientSeq)
      } catch (e) {
        WKLogger.error(`移除已回执消息失败，clientSeq:${sendAck.clientSeq},error:${e}`)
      }
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
    let result = CryptoUtils.shared.aesEncrypt(encryptContent)
    if (result === '') {
      WKLogger.error('收到消息本地未初始化密钥')
      return
    }
    let localMsgKey = CryptoUtils.shared.digestMD5(CommonUtil.stringToUint8Array(result))
    if (packet.msgKey != localMsgKey) {
      WKLogger.error(`非法消息-->期望msgKey：${localMsgKey}，实际msgKey：${packet.msgKey}`)
      return
    } else {
      packet.payload = CryptoUtils.shared.aesDecrypt(packet.payload)
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
    msg.messageId = packet.messageId === BigInt(0) ? '' : packet.messageId.toString()
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
    // CMD 已在解析时派发；不进入消息存储、发送恢复和最近会话更新。
    // 接收 ACK 仍由 decodePacket 在返回后按协议头处理。
    if (msg.contentType === WKMsgContentType.InsideMsg) {
      return
    }
    let recoveredSendingMessage = false
    if (packet.header.noPersist === false && packet.header.syncOnce === false) {
      let localMsg = MessageDB.shared.queryWithClientMsgNo(msg.clientMsgNo)
      recoveredSendingMessage = localMsg !== undefined && localMsg.status !== WKSendMsgResult.success
      let seq = MessageDB.shared.insert(msg)
      msg.clientSeq = seq
      if (recoveredSendingMessage) {
        this.completeSending(seq)
        let sendAck = new WKSendAckPacket()
        sendAck.clientSeq = seq
        sendAck.messageId = msg.messageId
        sendAck.messageSeq = msg.messageSeq
        sendAck.reasonCode = WKSendMsgResult.success
        WKIM.shared.messageManager().setSendStatus(sendAck)
      }
      let conv = ConversationDB.shared.insertWithWKMsg(msg, false)
      let list: WKConversation[] = []
      list.push(conv)
      WKIM.shared.conversationManager().setRefresh(list)
    }
    if (recoveredSendingMessage) {
      WKIM.shared.messageManager().refreshMessage(msg)
    } else {
      let list = new Array<WKMsg>()
      list.push(msg)
      WKIM.shared.messageManager().pushNewMsgs(list)
    }
  }

  private async sendConnPacket(tcpSocket: socket.TCPSocket, attemptId: number) {
    const initialized = await CryptoUtils.shared.init()
    if (attemptId !== this.connectionAttemptId || this.tcpSocket !== tcpSocket ||
      this.connStatus !== ConnStatus.authenticating || !initialized) {
      return
    }
    this.sendPacket(new WKConnectPacket())
  }

  sendPacket(packet: WKPacket) {
    let sendingMsg: SendingMsg | undefined
    if (packet.header.packetType === WKPacketType.send) {
      let send = packet as WKSendPacket
      try {
        if (this.sendingMsgMap.hasKey(send.clientSeq)) {
          sendingMsg = this.sendingMsgMap.get(send.clientSeq)
          sendingMsg!.packet = send
        } else {
          sendingMsg = new SendingMsg(send)
          this.sendingMsgMap.set(send.clientSeq, sendingMsg)
        }
      } catch (error) {
        WKLogger.error(`缓存发送包错误，code:${error.code},message:${error.message},error:${error}`)
      }
    }
    if (packet.header.packetType !== WKPacketType.connect && !this.isConnected()) {
      WKLogger.error('连接尚未认证，等待连接成功后发送')
      if (packet.header.packetType === WKPacketType.send) {
        this.ensureConnected()
      }
      return
    }
    const tcpSocket = this.tcpSocket
    if (tcpSocket === undefined) {
      WKLogger.error('发送时socket不存在')
      if (packet.header.packetType === WKPacketType.send) {
        this.ensureConnected()
      }
      return
    }
    if (sendingMsg !== undefined && sendingMsg.sendCount >= this.maxSendAttempts) {
      this.completeSending(sendingMsg.packet.clientSeq)
      this.markMessageFailed(sendingMsg)
      return
    }
    let data = WKIM.shared.config.protocol.encode(packet)
    if (data === undefined || data === null) {
      return
    }
    try {
      let tcpSendOption: socket.TCPSendOptions = {
        data: buffer.from(data).buffer
      }
      if (sendingMsg !== undefined) {
        sendingMsg.sendCount++
        sendingMsg.sendTime = DateUtil.getCurrentSeconds()
        sendingMsg.awaitingAck = true
      }
      tcpSocket.send(tcpSendOption).then(() => {
        WKLogger.debug(`发送消息成功`)
      }).catch((err: BusinessError) => {
        WKLogger.error(`发送消息错误，code:${err.code},message:${err.message}`)
        if (sendingMsg !== undefined) {
          sendingMsg.awaitingAck = false
        }
        if (this.tcpSocket === tcpSocket) {
          this.handleConnectionFailure('发送包失败')
        }
      });
    } catch (err) {
      WKLogger.error(`发送消息异常，code:${err.code},message:${err.message}`)
      if (sendingMsg !== undefined) {
        sendingMsg.awaitingAck = false
      }
      if (this.tcpSocket === tcpSocket) {
        this.handleConnectionFailure('发送包异常')
      }
    }
  }

  getConnectionState(): number {
    return this.connectStatus
  }

  getConnectStatus(): number {
    return this.getConnectionState()
  }

  isConnected(): boolean {
    return this.connStatus === ConnStatus.success && this.tcpSocket !== undefined && CryptoUtils.shared.isReady
  }

  ensureConnected() {
    if (!this.isConnected()) {
      this.connection()
    }
  }

  completeSending(clientSeq: number) {
    try {
      this.sendingMsgMap.remove(clientSeq)
    } catch (e) {
      WKLogger.error(`移除已同步消息失败，clientSeq:${clientSeq},error:${e}`)
    }
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
    try {
      if (this.sendingMsgMap.isEmpty()) {
        return
      }
      let messages: SendingMsg[] = new Array()
      this.sendingMsgMap.forEach((msg) => {
        if (msg !== undefined) {
          messages.push(msg)
        }
      })
      messages.sort((a: SendingMsg, b: SendingMsg): number => a.packet.clientSeq - b.packet.clientSeq)
      messages.forEach((msg) => {
        this.sendPacket(msg.packet)
      })
    } catch (e) {
      WKLogger.error(`重发消息错误，error:${e},code:${e.code},message:${e.message}`)
    }

  }

  private checkSendingMsg() {
    try {
      if (!this.isConnected() || this.sendingMsgMap.isEmpty()) {
        return
      }
      let retryPackets: WKSendPacket[] = new Array()
      let failedMessages: SendingMsg[] = new Array()
      let failedKeys: number[] = new Array()
      let nowTime = DateUtil.getCurrentSeconds()
      this.sendingMsgMap.forEach((v, k) => {
        if (v === undefined || !v.awaitingAck || nowTime - v.sendTime < this.sendAckTimeout) {
          return
        }
        if (v.sendCount >= this.maxSendAttempts) {
          failedMessages.push(v)
          failedKeys.push(k!)
        } else {
          v.awaitingAck = false
          retryPackets.push(v.packet)
        }
      })
      failedKeys.forEach((key) => {
        this.sendingMsgMap.remove(key)
      })
      failedMessages.forEach((msg) => {
        this.markMessageFailed(msg)
      })
      if (retryPackets.length > 0) {
        WKLogger.debug('消息ACK超时，重连后尝试重发')
        this.handleConnectionFailure('消息ACK超时')
      }
    } catch (e) {
      WKLogger.error(`检查发送中消息错误，error:${e},code:${e.code},message:${e.message}`)
    }
  }

  private markMessageFailed(msg: SendingMsg) {
    let sendAck = new WKSendAckPacket()
    sendAck.clientSeq = msg.packet.clientSeq
    sendAck.reasonCode = WKSendMsgResult.fail
    WKIM.shared.messageManager().setSendStatus(sendAck)
  }

  private startSendingCheckTimer() {
    this.clearCheckNetworkTimer()
    this.checkNetIntervalId = setInterval(() => {
      this.checkSendingMsg()
    }, this.checkSendingInterval)
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
      this.close(false)
    })
    this.netConn?.on('netLost', () => {
      this.networkChanged = true
      this.setConnectStatus(WKConnectStatus.noNetwork)
      this.close(false)
      WKLogger.error('网络丢失')
    })
  }

  private clearCheckNetworkTimer() {
    if (this.checkNetIntervalId !== 0) {
      clearInterval(this.checkNetIntervalId)
      this.checkNetIntervalId = 0
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
      this.heartIntervalId = 0
    }
  }
}

export class SendingMsg {
  packet: WKSendPacket
  sendCount = 0
  sendTime = 0
  awaitingAck = false

  constructor(packet: WKSendPacket) {
    this.packet = packet
  }
}

export class ConnStatus {
  static readonly unknown = 1
  static readonly conning = 2
  static readonly success = 3
  static readonly fail = 4
  static readonly authenticating = 5
}
