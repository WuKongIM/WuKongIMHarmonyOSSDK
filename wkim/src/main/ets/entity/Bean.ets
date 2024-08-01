import { JSON, util } from '@kit.ArkTS'
import { CommonUtil } from '../common/CommonUtil'
import { DateUtil } from '../common/DateUtil'
import { WKLogger } from '../common/WKLogger'
import { ReminderDB } from '../db/ReminderDB'
import { WKMessageContent } from '../model/WKMessageContent'
import { WKIM } from '../WKIM'

export class WKChannel {
  constructor(channelId: string, channelType: number) {
    this.channelId = channelId
    this.channelType = channelType
  }

  channelId: string
  channelType: number
  channelName: string = ""
  channelRemark: string = ""
  showNick: number = 0
  top: number = 0
  save: number = 0
  mute: number = 0
  forbidden: number = 0
  invite: number = 0
  status: number = 0
  follow: number = 0
  isDeleted: number = 0
  createdAt: string = ''
  updatedAt: string = ''
  avatar: string = ''
  version: number = 0
  online: number = 0
  lastOffline: number = 0
  deviceFlag: number = 0
  receipt: number = 0
  robot: number = 0
  category: string = ''
  username: string = ''
  avatarCacheKey: string = ''
  localExtra?: Record<string, Object>
  remoteExtra?: Record<string, Object>
  parentChannelId: string = ''
  parentChannelType: number = 0
}

export class WKChannelType {
  static readonly personal = 1;
  static readonly group = 2;
  static readonly customerService = 3;
  static readonly community = 4;
  static readonly communityTopic = 5;
}

export class WKChannelMember {
  channelId: string = ''
  channelType: number = WKChannelType.personal
  memberUID: string = ''
  memberName: string = ''
  memberRemark: string = ''
  memberAvatar: string = ''
  role = 0
  status = 0
  isDeleted = 0
  createdAt: string = ''
  updatedAt: string = ''
  version = 0
  robot = 0
  extra?: Record<string, object>
  remark: string = ''
  memberInviteUID: string = ''
  forbiddenExpirationTime = 0
  memberAvatarCacheKey: string = ''
}

export class WKMsgHeader {
  noPersist: boolean = false
  redDot: boolean = true
  syncOnce: boolean = false
}

export class WKMsg {
  header: WKMsgHeader = new WKMsgHeader();
  setting: WKMsgSetting = new WKMsgSetting();
  messageId = "";
  messageSeq = 0;
  clientSeq = 0;
  timestamp = 0;
  expireTime = 0;
  expireTimestamp = 0;
  clientMsgNo = "";
  fromUID = "";
  channelId = "";
  channelType = WKChannelType.personal;
  contentType = 0;
  content = "";
  status = 0;
  voiceStatus = 0;
  isDeleted = 0;
  searchableWord = "";
  private from?: WKChannel
  private channelInfo?: WKChannel
  private memberOfFrom?: WKChannelMember
  orderSeq = 0;
  viewed = 0;
  viewedAt = 0;
  topicId = "";
  localExtraMap?: Record<string, object>
  wkMsgExtra?: WKMsgExtra
  reactionList?: WKMsgReaction[]
  messageContent?: WKMessageContent

  constructor() {
    this.clientMsgNo = WKIM.shared.messageManager().generateClientMsgNo()
    this.timestamp = DateUtil.getCurrentSeconds()
    this.messageSeq = 0;
    this.expireTime = 0;
    this.expireTimestamp = 0;
    this.status = WKSendMsgResult.loading;
  }

  getChannelInfo(): WKChannel | undefined {
    return this.channelInfo
  }

  setChannelInfo(channel: WKChannel) {
    this.channelInfo = channel
  }

  getFrom(): WKChannel | undefined {
    return this.from
  }

  setFrom(channel: WKChannel) {
    this.from = channel
  }

  getMemberOfFrom(): WKChannelMember | undefined {
    return this.memberOfFrom
  }

  setMemberOfFrom(member: WKChannelMember) {
    this.memberOfFrom = member
  }

  toString(): string {
    return `clientMsgNo:${this.clientMsgNo},
            messageId:${this.messageId},
            messageSeq:${this.messageSeq},
            fromUID:${this.fromUID},
            channelId:${this.channelId},
            channelType:${this.channelType},
            isDeleted:${this.isDeleted},
            content:${this.content},
            `
  }
}

export class WKMsgExtra {
  messageId = ''
  channelId = ''
  channelType: number = WKChannelType.personal
  readed = 0
  readedCount = 0
  unreadCount = 0
  revoke = 0
  isMutualDeleted = 0
  revoker = ''
  extraVersion = 0
  editedAt = 0
  contentEdit = ''
  needUpload = 0
  isPinned = 0
  contentEditMsgModel?: WKMessageContent
}

export class WKConversation {
  channelId: string = ''
  channelType: number = WKChannelType.personal
  lastClientMsgNo: string = ''
  isDeleted: number = 0
  version: number = 0
  unreadCount = 0
  lastMsgTimestamp = 0
  lastMsgSeq = 0
  parentChannelId = ''
  parentChannelType = WKChannelType.personal
  localExtra?: Record<string, Object>
  remoteExtra?: WKConversationExtra
  private reminders?: WKReminder[]
  private msg?: WKMsg
  private channel?: WKChannel

  setMsg(msg: WKMsg) {
    this.msg = msg
  }

  getMsg(): WKMsg | undefined {
    if (this.msg === undefined) {
      WKLogger.error(`去查询消息${this.lastClientMsgNo}`)
      this.msg = WKIM.shared.messageManager().getWithClientMsgNo(this.lastClientMsgNo)
    }
    if (this.msg === undefined) {
      WKLogger.error(`返回undefined了`)
      return undefined
    }
    if (this.msg.isDeleted === 1) {
      WKLogger.error(`消息被删除`)
      return undefined
    }
    return this.msg
  }

  setChannel(channel: WKChannel) {
    this.channel = channel
  }

  getChannel(): WKChannel | undefined {
    return this.channel
  }

  getReminders(): WKReminder[] | undefined {
    if (this.reminders === undefined) {
      this.reminders = ReminderDB.shared.queryWithChannelAndDone(this.channelId, this.channelType, 0)
    }
    return this.reminders
  }

  setReminders(list: WKReminder[]) {
    this.reminders = list
  }
}

export class WKConversationExtra {
  channelId: string = ''
  channelType: number = WKChannelType.personal
  browseTo = 0
  keepMessageSeq = 0
  keepOffsetY = 0
  draft = ''
  version = 0
  draftUpdatedAt = 0
}

export class WKReminder {
  reminderId = 0
  messageId = ''
  channelId: string = ''
  channelType: number = WKChannelType.personal
  messageSeq = 0
  type = 0
  isLocate = 0
  uid = ''
  text = ''
  data?: Record<string, Object>
  version = 0
  done = 0
  needUpload = 0
  publisher = ''
}

export class WKMsgContentType {
  static readonly Unknown: number = -1;
  static readonly Text: number = 1;
  static readonly Image: number = 2;
  static readonly Gif: number = 3;
  static readonly Voice: number = 4;
  static readonly Video: number = 5;
  static readonly Location: number = 6;
  static readonly Card: number = 7;
  static readonly File: number = 8;
  static readonly MultipleForward: number = 11;
  static readonly VectorSticker: number = 12;
  static readonly EmojiSticker: number = 13;
  static readonly ContentFormatError = 97; // 内容格式错误
  static readonly SignalDecryptError = 98; // 解密错误
  static readonly InsideMsg = 99; // cmd消息
}

export class WKMsgReaction {
  messageId = ""
  channelId = ""
  channelType = WKChannelType.personal
  uid = ""
  name = ""
  seq = 0
  emoji = ""
  isDeleted = 0
  createdAt = ""
}

export class WKCMD {
  cmd: string = ''
  paramJsonObject?: Record<string, Object>

  constructor(cmd: string, param?: Record<string, Object>) {
    this.cmd = cmd
    this.paramJsonObject = param
  }
}

export class WKMentionInfo {
  isMentionMe = false
  mentionAll = false
  uidList?: string[]
}

export class WKReply {
  rootMid = ''
  messageId = ''
  messageSeq = 0
  fromUID = ''
  fromName = ''
  contentEdit = ''
  editAt = 0
  revoke = 0
  contentEditMsgModel?: WKMessageContent
  payload?: WKMessageContent

  encode(): Record<string, Object> {
    let json: Record<string, Object> = {}
    json['root_mid'] = this.rootMid
    json['message_id'] = this.messageId
    json['message_seq'] = this.messageSeq
    json['from_uid'] = this.fromUID
    json['from_name'] = this.fromName
    if (this.payload !== undefined) {
      let payloadJson = this.payload!.encodeJson()
      payloadJson['type'] = this.payload!.contentType
      json['payload'] = payloadJson
    }
    return json
  }

  decode(json: Record<string, Object>): WKReply | undefined {
    this.rootMid = CommonUtil.readString(json, 'root_mid')
    this.messageId = CommonUtil.readString(json, 'message_id')
    this.messageSeq = CommonUtil.readNumber(json, 'message_seq')
    this.fromUID = CommonUtil.readString(json, 'from_uid')
    this.fromName = CommonUtil.readString(json, 'from_name')
    let payload = json['payload']
    if (payload !== null && payload !== undefined) {
      let payloadJson = payload as Record<string, Object>
      this.payload = WKIM.shared.messageManager().getMessageModel(JSON.stringify(payloadJson))
    }
    return this
  }
}

export class WKMsgEntity {
  offset = 0
  length = 0
  type = ''
  value = ''
}

export class WKMsgSetting {
  receipt = 0
  topic = 0
  stream = 0

  decode(v: number): WKMsgSetting {
    this.receipt = (v >> 7 & 0x01)
    this.topic = (v >> 3 & 0x01)
    this.stream = (v >> 2 & 0x001)
    return this
  }

  encode(): number {
    return this.receipt << 7 | this.topic << 3 | this.stream << 2
  }
}

export class WKSendMsgResult {
  static readonly loading = 0
  static readonly success = 1
  static readonly fail = 2
  static readonly notOnWhiteList = 13 // 不在白名单内
  static readonly noRelation = 3 // 非好友或不在频道内
  static readonly blackList = 4 // 黑名单
}

export class WKConnectStatus {
  static readonly fail: number = 0 // 失败
  static readonly success: number = 1 // 成功
  static readonly kicked: number = 2 // 被踢
  static readonly syncing: number = 3 // 同步中
  static readonly connecting: number = 4 // 连接中
  static readonly noNetwork: number = 5 // 无网络
  static readonly syncCompleted: number = 6 // 同步完成
}

export class ConnectionInfo {
  nodeId: number

  constructor(nodeId: number) {
    this.nodeId = nodeId
  }
}


export class WKSendOptions {
  setting: WKMsgSetting = new WKMsgSetting()
  header: WKMsgHeader = new WKMsgHeader()
  expire = 0;
  topicId = "";
}

export type ISyncing = () => void

export type IResult = (list: WKMsg[]) => void

export class ChannelMsgOptions {
  oldestOrderSeq: number = 0
  contain: boolean = false
  pullMode: number = 0
  limit: number = 0
  aroundMsgOrderSeq: number = 0
  iSyncing: ISyncing
  iResult: IResult

  constructor(iSyncing: ISyncing,
    iResult: IResult) {
    this.iSyncing = iSyncing
    this.iResult = iResult
  }
}

export class SyncOptions {
  startMessageSeq: number = 0
  endMessageSeq: number = 0
  limit: number = 30
  pullMode: number = 0

  constructor(startSeq: number, endSeq: number, pullMode: number, limit?: number) {
    this.startMessageSeq = startSeq
    this.endMessageSeq = endSeq
    this.pullMode = pullMode
    if (limit !== undefined && limit > 0) {
      this.limit = limit
    }
  }
}

export class SyncChannelMemberOptions {
  searchKey: string = ''
  page: number = 0
  limit: number = 20
}

export class WKSyncConversation {
  uid = ''
  conversations?: WKSyncConvMsg[]
}

export class WKSyncConvMsg {
  channelId = ''
  channelType = 0
  lastClientMsgNo = ''
  lastMsgSeq = 0
  offsetMsgSeq = 0
  timestamp = 0
  unread = 0
  version = 0
  recents?: WKMsg[]
  remoteExtra?: WKConversationExtra
}

export class WKSyncChannelMsg {
  startMessageSeq = 0
  endMessageSeq = 0
  more = 0
  msgs?: WKMsg[]
}