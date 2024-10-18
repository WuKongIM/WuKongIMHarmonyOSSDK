import { MessageDB } from '../db/MessageDB'
import { WKMessageContent } from '../model/WKMessageContent'
import { WKIM } from '../WKIM'
import { ArrayList, HashMap, JSON, util } from '@kit.ArkTS'
import { WKTextContent } from '../model/WKTextContent'
import { WKImageContent } from '../model/WKImageContent'

import {
  ChannelMsgOptions,
  SyncOptions,
  WKChannel,
  WKChannelType,
  WKConversation,
  WKMentionInfo,
  WKMsg,
  WKMsgContentType,
  WKMsgEntity,
  WKMsgExtra,
  WKMsgHeader,
  WKMsgReaction,
  WKMsgSetting,
  WKReply,
  WKSendMsgResult,
  WKSendOptions,
  WKSyncChannelMsg
} from '../entity/Bean'
import { WKSendAckPacket, WKSendPacket } from '../protocol/WKPacket'
import { WKLogger } from '../common/WKLogger'
import { CommonUtil } from '../common/CommonUtil'
import { WKUnknownContent } from '../model/WKUnknownContent'
import { WKFormatErrorContent } from '../model/WKFormatErrorContent'
import { ConversationDB } from '../db/ConversationDB'
import { WKMediaMessageContent } from '../model/WKMediaMessageContent'
import { relationalStore } from '@kit.ArkData'
import { DateUtil } from '../common/DateUtil'
import { ReactionDB } from '../db/ReactionDB'

export type SendStatusPacket = (clientMsgSeq: number, messageId: string, messageSeq: number, reasonCode: number) => void

export type ClearChannelMessage = (channelId: string, channelType: number) => void

export type RefreshMessage = (msg: WKMsg) => void

export type NewMessages = (msgs: WKMsg[]) => void

export type DeletedMessage = (clientMsgNo: string) => void

export type RefreshExtra = (list: WKMsgExtra[]) => void

export type RefreshReaction = (list: WKMsgReaction[]) => void

export class MessageManager {
  static shared: MessageManager = new MessageManager()

  private constructor() {
    this.contentModels = new HashMap()
    this.contentModels.set(WKMsgContentType.Text, (jsonStr: string) => {
      return new WKTextContent('').decodeJson(jsonStr)
    })
    this.contentModels.set(WKMsgContentType.Image, (jsonStr: string) => {
      return new WKImageContent('').decodeJson(jsonStr)
    })
    this.sendStatusListeners = new Array()
    this.clearChannelMsgListeners = new Array()
    this.refreshMessageListeners = new Array()
    this.pushMsgsListeners = new Array()
    this.deletedMessageListeners = new Array()
    this.refreshExtraListeners = new Array()
    this.refreshReactionListeners = new Array()
  }

  private contentModels: HashMap<number, (jsonStr: string) => WKMessageContent>
  private insertedBack?: ((msg: WKMsg) => void)
  private deletedMessageListeners: DeletedMessage[]
  private refreshMessageListeners: RefreshMessage[]
  private clearChannelMsgListeners: ClearChannelMessage[]
  private sendStatusListeners: SendStatusPacket[]
  private pushMsgsListeners: NewMessages[]
  private refreshExtraListeners: RefreshExtra[]
  private refreshReactionListeners: RefreshReaction[]
  private wkOrderSeqFactor = 1000
  private uploadExtraIntervalId = 0

  registerMsgContent(contentType: number, model: (jsonStr: string) => WKMessageContent) {
    this.contentModels.set(contentType, model)
  }

  private getOrNearbyMsgSeq(orderSeq: number) {
    if (orderSeq % this.wkOrderSeqFactor == 0) {
      return orderSeq / this.wkOrderSeqFactor
    }
    return (orderSeq - orderSeq % this.wkOrderSeqFactor) / this.wkOrderSeqFactor
  }

  getMaxOrderSeqWithChannel(channelId: string, channelType: number): number {
    return MessageDB.shared.queryMaxMessageOrderSeqWithChannel(channelId, channelType)
  }

  getOrSyncHistoryMessages(channel: WKChannel, option: ChannelMsgOptions) {
    let tempPullMode = option.pullMode
    let tempOldestOrderSeq = option.oldestOrderSeq
    let tempContain = option.contain
    if (option.aroundMsgOrderSeq !== 0) {
      let maxMsgSeq =
        MessageDB.shared.queryMaxMessageSeqNotDeletedWithChannel(channel.channelId, channel.channelType)
      let aroundMsgSeq = this.getOrNearbyMsgSeq(option.aroundMsgOrderSeq)
      if (maxMsgSeq >= aroundMsgSeq && maxMsgSeq - aroundMsgSeq <= option.limit) {
        tempOldestOrderSeq = this.getMaxOrderSeqWithChannel(channel.channelId, channel.channelType)
        if (tempOldestOrderSeq < option.aroundMsgOrderSeq) {
          tempOldestOrderSeq = option.aroundMsgOrderSeq;
        }
        tempContain = true;
        tempPullMode = 0;
      } else {
        let minOrderSeq =
          MessageDB.shared.queryOrderSeq(channel.channelId, channel.channelType, option.aroundMsgOrderSeq, 3)
        if (minOrderSeq == 0) {
          tempOldestOrderSeq = option.aroundMsgOrderSeq
        } else {
          if (minOrderSeq + option.limit < option.aroundMsgOrderSeq) {
            if (option.aroundMsgOrderSeq % this.wkOrderSeqFactor == 0) {
              tempOldestOrderSeq = (option.aroundMsgOrderSeq / this.wkOrderSeqFactor - 3) * this.wkOrderSeqFactor;
            } else {
              tempOldestOrderSeq = option.aroundMsgOrderSeq - 3;
            }
            //                        oldestOrderSeq = aroundMsgOrderSeq;
          } else {
            // todo 这里只会查询3条数据  oldestOrderSeq = minOrderSeq
            let startOrderSeq =
              MessageDB.shared.queryOrderSeq(channel.channelId, channel.channelType, option.aroundMsgOrderSeq,
                option.limit)
            if (startOrderSeq == 0) {
              tempOldestOrderSeq = option.aroundMsgOrderSeq;
            } else {
              tempOldestOrderSeq = startOrderSeq;
            }
          }
        }
        tempPullMode = 1
        tempContain = true
      }
    }
    option.contain = tempContain
    option.pullMode = tempPullMode
    option.oldestOrderSeq = tempOldestOrderSeq
    MessageDB.shared.queryOrSyncHistoryMessages(channel, option)
  }

  send(model: WKMessageContent, channel: WKChannel) {
    this.sendWithOption(model, channel, new WKSendOptions())
  }

  sendWithOption(model: WKMessageContent, channel: WKChannel, option: WKSendOptions) {
    if (channel.channelId === '') {
      return
    }
    let msg = new WKMsg()
    msg.setting = option.setting ?? new WKMsgSetting()
    msg.header = option.header ?? new WKMsgHeader()
    msg.messageContent = model
    msg.channelId = channel.channelId
    msg.channelType = channel.channelType
    msg.fromUID = WKIM.shared.config.uid!
    msg.contentType = model.contentType
    let tempOrderSeq = MessageDB.shared
      .queryMaxOrderSeq(channel.channelId, channel.channelType)
    msg.orderSeq = tempOrderSeq + 1
    msg.setChannelInfo(channel)
    let fromChannel =
      WKIM.shared.channelManager().getChannel(WKIM.shared.config.uid!, WKChannelType.personal)
    if (fromChannel !== undefined) {
      msg.setFrom(fromChannel)
    }
    let json = this.getSendPayload(msg.messageContent!)
    msg.content = JSON.stringify(json)
    if (!option.header.noPersist) {
      let row = MessageDB.shared.insert(msg)
      this.setInserted(msg)
      msg.clientSeq = row
      // 更新最近会话
      if (msg.clientSeq > 0) {
        let convMsg = ConversationDB.shared.insertWithWKMsg(msg, true)
        let list: WKConversation[] = []
        list.push(convMsg)
        WKIM.shared.conversationManager().setRefresh(list)
      }
    }
    if (msg.messageContent instanceof WKMediaMessageContent) {
      if (WKIM.shared.config.provider.uploadAttachmentCallback === undefined) {
        WKLogger.error('未注册uploadAttachmentCallback')
        return
      }
      WKIM.shared.config.provider.uploadAttachmentCallback(msg)
        .then((result: [boolean, WKMsg]) => {
          if (result[0]) {
            this.sendPacket(result[1])
          } else {
            WKLogger.error('上传文件失败')
          }
        })
    } else {
      this.sendPacket(msg)
    }
  }

  private sendPacket(wkMsg: WKMsg) {
    let sendPacket = new WKSendPacket()
    sendPacket.setting = wkMsg.setting
    sendPacket.header.noPersist = wkMsg.header.noPersist
    sendPacket.header.redDot = wkMsg.header.redDot
    sendPacket.header.syncOnce = wkMsg.header.syncOnce
    sendPacket.clientSeq = wkMsg.clientSeq
    sendPacket.channelId = wkMsg.channelId
    sendPacket.channelType = wkMsg.channelType
    sendPacket.clientMsgNo = wkMsg.clientMsgNo
    let json = this.getSendPayload(wkMsg.messageContent!)
    const resultJson: Record<string, Object> = {};
    Object.keys(json).forEach((key: string) => {
      if (key !== 'localPath' && key !== 'coverLocalPath') {
        resultJson[key] = json[key]
      }
    })
    let str = JSON.stringify(resultJson)
    sendPacket.payload = str
    WKLogger.error(`发送消息结构：${str}`)
    WKIM.shared.connectionManager().sendPacket(sendPacket)
  }

  addInsertedListener(back: ((msg: WKMsg) => void)) {
    this.insertedBack = back
  }

  private setInserted(msg: WKMsg) {
    this.insertedBack?.(msg)
  }

  addSendStatusListener(listener: SendStatusPacket) {
    this.sendStatusListeners.push(listener)
  }

  removeSendStatusListener(listener: SendStatusPacket) {
    for (let i = 0; i < this.sendStatusListeners.length; i++) {
      if (this.sendStatusListeners[i] === listener) {
        this.sendStatusListeners.splice(i, 1)
        break
      }
    }
  }

  setSendStatus(packet: WKSendAckPacket) {
    this.sendStatusListeners.forEach((l) => {
      l(packet.clientSeq, packet.messageId, packet.messageSeq, packet.reasonCode)
    })
  }

  addRefreshExtraListener(l: RefreshExtra) {
    this.refreshExtraListeners.push(l)
  }

  removeRefreshExtraListener(l: RefreshExtra) {
    for (let i = 0; i < this.refreshExtraListeners.length; i++) {
      if (this.refreshExtraListeners[i] === l) {
        this.refreshExtraListeners.splice(i, 1)
        break
      }
    }
  }

  setRefreshReactions(list: WKMsgReaction[]) {
    this.refreshReactionListeners.forEach((b) => {
      b(list)
    })
  }

  addRefreshReactionListener(listener: RefreshReaction) {
    this.refreshReactionListeners.push(listener)
  }

  removeRefreshReactionListener(listener: RefreshReaction) {
    for (let i = 0; i < this.refreshReactionListeners.length; i++) {
      if (this.refreshReactionListeners[i] === listener) {
        this.refreshReactionListeners.splice(i, 1)
        break
      }
    }
  }

  setRefreshExtras(list: WKMsgExtra[]) {
    this.refreshExtraListeners.forEach((b) => {
      b(list)
    })
  }

  addRefreshListener(listener: RefreshMessage) {
    this.refreshMessageListeners.push(listener)
  }

  removeRefreshListener(listener: RefreshMessage) {
    for (let i = 0; i < this.refreshMessageListeners.length; i++) {
      if (this.refreshMessageListeners[i] === listener) {
        this.refreshMessageListeners.splice(i, 1)
        break
      }
    }
  }

  private setRefresh(msg: WKMsg) {
    if (this.refreshMessageListeners.length > 0) {
      this.refreshMessageListeners.forEach((iRefresh) => {
        iRefresh(msg)
      })
    }
  }

  addNewMsgListener(listener: NewMessages) {
    this.pushMsgsListeners.push(listener)
  }

  removeNewMsgListener(listener: NewMessages) {
    for (let i = 0; i < this.pushMsgsListeners.length; i++) {
      if (this.pushMsgsListeners[i] === listener) {
        this.pushMsgsListeners.splice(i, 1)
        break
      }
    }
  }

  pushNewMsgs(msg: WKMsg[]) {
    if (this.pushMsgsListeners.length > 0) {
      this.pushMsgsListeners.forEach((back) => {
        back(msg)
      })
    }
  }

  addDeletedListener(listener: DeletedMessage) {
    this.deletedMessageListeners.push(listener)
  }

  removeDeletedListener(listener: DeletedMessage) {
    for (let i = 0; i < this.deletedMessageListeners.length; i++) {
      if (this.deletedMessageListeners[i] === listener) {
        this.deletedMessageListeners.splice(i, 1)
        break
      }
    }
  }

  private setDeleted(clientMsgNo: string) {
    if (this.deletedMessageListeners.length > 0) {
      this.deletedMessageListeners.forEach((back) => {
        back(clientMsgNo)
      })
    }
  }

  addClearChannelMsgListener(listener: ClearChannelMessage) {
    this.clearChannelMsgListeners.push(listener)
  }

  removeClearChannelMsgListener(listener: ClearChannelMessage) {
    for (let i = 0; i < this.clearChannelMsgListeners.length; i++) {
      if (this.clearChannelMsgListeners[i] === listener) {
        this.clearChannelMsgListeners.splice(i, 1)
        break
      }
    }
  }

  private setClearChannelMsg(channelId: string, channelType: number) {
    if (this.clearChannelMsgListeners.length > 0) {
      this.clearChannelMsgListeners.forEach((back) => {
        back(channelId, channelType)
      })
    }
  }

  getOrderSeq(messageSeq: number) {
    return messageSeq * this.wkOrderSeqFactor
  }

  getWithClientMsgNo(clientMsgNo: string) {
    let msg = MessageDB.shared.queryWithClientMsgNo(clientMsgNo)
    if (msg === undefined) {
      WKLogger.error(`查询到空到`)
    }
    return msg
  }

  async syncRemoteExtra(channel: WKChannel) {
    if (WKIM.shared.config.provider.syncMessageExtraCallback === undefined) {
      WKLogger.error('未提供syncMessageExtraCallback')
      return
    }
    let maxVersion = MessageDB.shared.queryMaxExtraVersion(channel.channelId, channel.channelType)
    let extras =
      await WKIM.shared.config.provider.syncMessageExtraCallback(channel, maxVersion, 100)
    if (extras !== null && extras.length > 0) {
      this.saveRemoteExtras(extras)
    }
  }

  getMsgReactions(messageId: string): WKMsgReaction[] {
    return ReactionDB.shared.queryWithMsgId(messageId)
  }

  saveRemoteExtras(list: WKMsgExtra[]) {
    if (list.length > 0) {
      MessageDB.shared.insertExtras(list)
      this.setRefreshExtras(list)
    }
  }

  saveReactions(list: WKMsgReaction[]) {
    if (list.length > 0) {
      ReactionDB.shared.inserts(list)
      this.setRefreshReactions(list)
    }
  }

  async syncChannelMsgs(channel: WKChannel, startSeq: number, endSeq: number,
    pullModel: number, limit: number): Promise<WKSyncChannelMsg | undefined> {
    if (WKIM.shared.config.provider.syncMessageCallback === undefined) {
      WKLogger.error('未提供syncMessageCallback')
      return undefined
    }
    let syncOption = new SyncOptions(startSeq, endSeq, pullModel, limit)
    let msg = await WKIM.shared.config.provider.syncMessageCallback(channel, syncOption)
    if (msg.msgs !== undefined && msg.msgs.length > 0) {
      msg.msgs.forEach((m) => {
        m.status = WKSendMsgResult.success
        this.parsingMsg(m)
      })
      MessageDB.shared.inserts(msg.msgs)
    }
    return msg
  }


  generateClientMsgNo() {
    return `${util.generateRandomUUID().replaceAll("-", "")}6`
  }


  private getSendPayload(model: WKMessageContent): Record<string, Object> {
    let json = model.encodeJson()
    json['type'] = model.contentType
    if (model.entities !== undefined && model.entities?.length > 0) {
      let arr: Record<string, Object>[] = new Array()
      model.entities?.forEach((v) => {
        let json: Record<string, Object> = {}
        json['offset'] = v.offset
        json['length'] = v.length
        json['type'] = v.type
        json['value'] = v.value
        arr.push(json)
      })
      json['entities'] = arr
    }
    if (model.reply !== undefined) {
      json['reply'] = model.reply.encode()
    }
    if (model.mentionInfo !== undefined) {
      let mentionJson: Record<string, Object> = {}
      if (model.mentionInfo?.mentionAll) {
        mentionJson['all'] = 1
      }

      if (model.mentionInfo?.uidList !== undefined && model.mentionInfo?.uidList.length > 0) {
        mentionJson['uids'] = model.mentionInfo?.uidList
      }
      json['mention'] = mentionJson
    }
    return json
  }

  getMessageModel(jsonStr: string): WKMessageContent | undefined {
    if (!CommonUtil.isJSONStr(jsonStr)) {
      return new WKFormatErrorContent()
    }
    let json = JSON.parse(jsonStr) as Record<string, Object>
    let contentType = json['type']
    if (contentType === null || contentType === undefined) {
      return new WKFormatErrorContent()
    }
    let type = Number(contentType).valueOf()
    if (!this.contentModels.hasKey(type)) {
      return new WKUnknownContent()
    }
    let msgContent = this.contentModels.get(type)
    let model = msgContent(jsonStr)
    let reply = json['reply']
    if (reply !== null && reply !== undefined) {
      let replyJson = reply as Record<string, Object>
      model.reply = new WKReply().decode(replyJson)
    }
    let entities = json['entities']
    if (entities !== null && entities !== undefined) {
      model.entities = new ArrayList()
      let jsonArr = entities as Record<string, Object>[]
      jsonArr.forEach((v) => {
        let entity = new WKMsgEntity()
        entity.offset = CommonUtil.readNumber(v, 'offset')
        entity.length = CommonUtil.readNumber(v, 'length')
        entity.type = CommonUtil.readString(v, 'type')
        entity.value = CommonUtil.readString(v, 'value')
        model.entities?.add(entity)
      })
    }
    let mention = json['mention']
    if (mention !== null && mention !== undefined) {
      let mentionJson = mention as Record<string, Object>
      model.mentionInfo = new WKMentionInfo()
      model.mentionInfo.mentionAll = CommonUtil.readNumber(mentionJson, 'all') > 0
      let list = mentionJson['uids']
      if (list instanceof Array) {
        let uidList = list as Array<string>
        if (uidList !== null && uidList.length > 0) {
          model.mentionInfo.uidList = uidList
          uidList.forEach((uid) => {
            if (uid === WKIM.shared.config.uid) {
              model.mentionInfo!.isMentionMe = true
            }
          })
        }
      }
      if (model.mentionInfo.mentionAll) {
        model.mentionInfo.isMentionMe = true
      }
    }
    return model
  }

  parsingMsg(msg: WKMsg) {
    msg.orderSeq = this.getOrderSeq(msg.messageSeq)
    if (CommonUtil.strIsEmpty(msg.content)) {
      msg.contentType = WKMsgContentType.ContentFormatError
      msg.messageContent = new WKFormatErrorContent()
      return
    }
    let json = CommonUtil.jsonToRecord(msg.content)
    if (json === undefined) {
      msg.contentType = WKMsgContentType.ContentFormatError
      msg.messageContent = new WKFormatErrorContent()
      return
    }
    let type = json['type']
    if (type !== undefined && type !== null) {
      msg.contentType = type as number
    }

    if (CommonUtil.strIsEmpty(msg.fromUID)) {
      let fromUID = json['from_uid']
      if (fromUID !== undefined && fromUID !== null) {
        msg.fromUID = fromUID.toString()
      }
    }

    if (msg.contentType === WKMsgContentType.InsideMsg) {
      WKIM.shared.cmdManager().handle(json)
    }

    if (msg.contentType != WKMsgContentType.SignalDecryptError &&
      msg.contentType != WKMsgContentType.ContentFormatError) {
      msg.messageContent = this.getMessageModel(msg.content)
    }

    if (CommonUtil.strIsUnEmpty(msg.channelId) && CommonUtil.strIsUnEmpty(msg.fromUID) &&
      msg.channelType === WKChannelType.personal && msg.channelId === WKIM.shared.config.uid) {
      msg.channelId = msg.fromUID
    }
    msg.isDeleted = this.isDeleted(json)
  }

  private isDeleted(json?: Record<string, Object>) {
    let isDeleted = 0
    if (json === undefined) {
      return isDeleted
    }
    let list = json['visibles']
    if (list === undefined && list === null) {
      return isDeleted
    }
    if (list instanceof Array && list.length > 0) {
      let isIncludeLoginUser = false
      let uidList = list as Array<string>
      uidList.forEach((uid) => {
        if (uid === WKIM.shared.config.uid) {
          isIncludeLoginUser = true
        }
      })
      isDeleted = isIncludeLoginUser ? 0 : 1
    }
    return isDeleted
  }

  updateContent(clientMsgNo: string, messageContent: WKMessageContent) {
    let json = messageContent.encodeJson()
    let content = JSON.stringify(json)
    let cv: relationalStore.ValuesBucket = {
      'content': content
    }
    let isSuccess = MessageDB.shared.updateMsgFieldWithClientMsgNo(clientMsgNo, cv)
    if (isSuccess) {
      let msg = MessageDB.shared.queryWithClientMsgNo(clientMsgNo)
      if (msg !== undefined) {
        this.setRefresh(msg)
      }
    }
  }

  updateViewedAt(clientMsgNo: string, viewedAt: number) {
    let cv: relationalStore.ValuesBucket = {
      'viewed': 1,
      'viewed_at': viewedAt
    }
    let isSuccess = MessageDB.shared.updateMsgFieldWithClientMsgNo(clientMsgNo, cv)
    if (isSuccess) {
      let msg = MessageDB.shared.queryWithClientMsgNo(clientMsgNo)
      if (msg !== undefined) {
        this.setRefresh(msg)
      }
    }
  }

  updateLocalExtra(clientMsgNo: string, extra: Record<string, Object>) {
    let extraText = JSON.stringify(extra)
    let cv: relationalStore.ValuesBucket = {
      'extra': extraText
    }
    let isSuccess = MessageDB.shared.updateMsgFieldWithClientMsgNo(clientMsgNo, cv)
    if (isSuccess) {
      let msg = MessageDB.shared.queryWithClientMsgNo(clientMsgNo)
      if (msg !== undefined) {
        this.setRefresh(msg)
      }
    }
  }

  updateEdit(messageId: string, channelId: string, channelType: number, content: string) {
    let msg = MessageDB.shared.queryExtraWithMsgId(messageId)
    if (msg === undefined) {
      msg = new WKMsgExtra()
    }
    msg.messageId = messageId
    msg.channelId = channelId
    msg.channelType = channelType
    msg.editedAt = DateUtil.getCurrentSeconds()
    msg.contentEdit = content
    msg.needUpload = 1
    let list: WKMsgExtra[] = []
    list.push(msg)
    MessageDB.shared.insertExtras(list)
    this.setRefreshExtras(list)
    this.setUploadExtra(msg)
  }

  private setUploadExtra(extra: WKMsgExtra) {
    if (WKIM.shared.config.provider.uploadMessageExtraCallback === undefined) {
      WKLogger.error('未提供uploadMessageExtraCallback')
      return
    }
    WKIM.shared.config.provider.uploadMessageExtraCallback(extra)
    setTimeout(() => {
      this.startCheckNeedUploadExtraTimer()
    }, 5000)
  }

  private startCheckNeedUploadExtraTimer() {
    if (this.uploadExtraIntervalId !== 0) {
      clearInterval(this.uploadExtraIntervalId)
    }
    this.uploadExtraIntervalId = setInterval(() => {
      let list = MessageDB.shared.queryExtraWithNeddUpload(1)
      if (list.length > 0) {
        list.forEach((extra) => {
          if (WKIM.shared.config.provider.uploadMessageExtraCallback === undefined) {
            WKLogger.error('未提供uploadMessageExtraCallback')
            return
          }
          WKIM.shared.config.provider.uploadMessageExtraCallback(extra)
        })
      } else {
        clearInterval(this.uploadExtraIntervalId)
      }
    }, 5000)
  }

  clearWithChannel(channelId: string, channelType: number) {
    let r = MessageDB.shared.deleteWithChannel(channelId, channelType)
    if (r) {
      this.setClearChannelMsg(channelId, channelType)
    }
  }

  deleteWithClientMsgNo(clientMsgNo: string) {
    let r = MessageDB.shared.deleteWithClientMsgNo(clientMsgNo)
    if (!r) {
      return
    }
    this.setDeleted(clientMsgNo)
    let wkMsg = this.getWithClientMsgNo(clientMsgNo)
    if (wkMsg === undefined) {
      return
    }
    let coverMsg = ConversationDB.shared
      .query(wkMsg.channelId, wkMsg.channelType)
    if (coverMsg === undefined || coverMsg.lastClientMsgNo !== clientMsgNo) {
      return
    }
    let tempMsg = MessageDB.shared.queryMaxOrderSeqNotDeletedWithChannel(
      wkMsg.channelId, wkMsg.channelType)
    if (tempMsg === undefined) {
      return
    }
    let uiMsg = ConversationDB.shared.insertWithWKMsg(tempMsg, true)
    if (uiMsg != null) {
      let uiMsgs: WKConversation[] = []
      uiMsgs.push(uiMsg)
      WKIM.shared.conversationManager().setRefresh(uiMsgs)
    }
  }
}