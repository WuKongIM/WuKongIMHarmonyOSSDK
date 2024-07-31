import { WKLogger } from '../common/WKLogger';
import { ConversationDB } from '../db/ConversationDB';
import { MessageDB } from '../db/MessageDB';
import { WKChannelType, WKConversation, WKConversationExtra, WKMsg } from '../entity/Bean';
import { WKIM } from '../WKIM';

export type RefreshListener = (list: WKConversation[]) => void

export type RefreshExtraListener = (e: WKConversationExtra[]) => void

export type DeletedListener = (channelId: string, channelType: number) => void

export class ConversationManager {
  static shared: ConversationManager = new ConversationManager();

  private constructor() {
    this.refreshListeners = new Array()
    this.deletedListeners = new Array()
    this.refreshExtrasListeners = new Array()
  }

  private refreshListeners: RefreshListener[]
  private refreshExtrasListeners: RefreshExtraListener[]
  private deletedListeners: DeletedListener[]

  clearAllRedDot(): boolean {
    return ConversationDB.shared.clearAllRedDot()
  }

  updateRedDot(channelId: string, channelType: number, count: number) {
    let r = ConversationDB.shared.updateWithField('unread_count', count, channelId, channelType)
    if (r) {
      let c = ConversationDB.shared.query(channelId, channelType)
      if (c !== undefined) {
        let list: WKConversation[] = []
        list.push(c)
        this.setRefresh(list)
      }
    }
    return r
  }

  clearAll() {
    return ConversationDB.shared.clearAll()
  }

  delete(channelId: string, channelType: number): boolean {
    let r = ConversationDB.shared.updateWithField('is_deleted', 1, channelId, channelType)
    if (r) {
      this.setDeleted(channelId, channelType)
    }
    return r
  }

  async syncExtra() {
    if (WKIM.shared.config.provider.syncConversationExtraCallback === undefined) {
      WKLogger.error('未提供syncConversationExtraCallback')
      return
    }
    let version = ConversationDB.shared.queryExtraMaxVersion()
    let extras = await WKIM.shared.config.provider.syncConversationExtraCallback(version)
    if (extras !== undefined && extras.length > 0) {
      ConversationDB.shared.insertOrReplaceExtras(extras)
      this.setRefreshExtras(extras)
    }
  }

  async sync(): Promise<WKConversation[] | undefined> {
    if (WKIM.shared.config.provider.syncConversationCallback === undefined) {
      WKLogger.error('未提供syncConversationCallback')
      return
    }
    let lastMsgseqs = ConversationDB.shared.queryLastMsgSeqs()
    let syncConv = await WKIM.shared.config.provider.syncConversationCallback(lastMsgseqs, 1000, 0)
    let list = new Array<WKConversation>()
    let msgList = new Array<WKMsg>()
    if (syncConv !== undefined && syncConv.conversations !== undefined && syncConv.conversations.length > 0) {
      for (let i = 0, size = syncConv.conversations.length; i < size; i++) {
        let msg = new WKConversation()
        let convMsg = syncConv.conversations[i]
        let channelType = convMsg.channelType
        let channelId = convMsg.channelId
        if (channelType == WKChannelType.communityTopic) {
          let str = channelId.split("@")
          msg.parentChannelId = str[0]
          msg.parentChannelType = WKChannelType.community
        }
        msg.channelId = convMsg.channelId
        msg.channelType = convMsg.channelType
        msg.lastClientMsgNo = convMsg.lastClientMsgNo
        msg.unreadCount = convMsg.unread
        msg.remoteExtra = convMsg.remoteExtra
        msg.version = convMsg.version
        msg.lastMsgTimestamp = convMsg.timestamp

        if (convMsg.recents !== undefined && convMsg.recents.length > 0) {
          for (let j = 0, len = convMsg.recents.length; j < len; j++) {
            let wkMsg = convMsg.recents[j]
            WKIM.shared.messageManager().parsingMsg(wkMsg)
            msgList.push(wkMsg)
          }
        }
        list.push(msg)
      }
    }
    if (list.length > 0) {
      ConversationDB.shared.insertOrReplaces(list)
    }
    if (msgList.length > 0) {
      MessageDB.shared.inserts(msgList)
    }
    this.setRefresh(list)
    return list
  }

  all(): WKConversation[] | undefined {
    return ConversationDB.shared.queryAll()
  }

  addRefreshListener(l: RefreshListener) {
    this.refreshListeners.push(l)
  }

  removeRefreshListener(l: RefreshListener) {
    for (let i = 0; i < this.refreshListeners.length; i++) {
      if (this.refreshListeners[i] === l) {
        this.refreshListeners.splice(i, 1)
        break
      }
    }
  }

  setRefresh(list: WKConversation[]) {
    if (this.refreshListeners.length === 0) {
      return
    }
    this.refreshListeners.forEach((l) => {
      l(list)
    })
  }

  addRefreshExtrasListener(l: RefreshExtraListener) {
    this.refreshExtrasListeners.push(l)
  }

  removeRefreshExtrasListener(l: RefreshExtraListener) {
    for (let i = 0; i < this.refreshExtrasListeners.length; i++) {
      if (this.refreshExtrasListeners[i] === l) {
        this.refreshExtrasListeners.splice(i, 1)
        break
      }
    }
  }

  setRefreshExtras(list: WKConversationExtra[]) {
    this.refreshExtrasListeners.forEach((l) => {
      l(list)
    })
  }

  addDeletedListener(l: DeletedListener) {
    this.deletedListeners.push(l)
  }

  removeDeletedListener(l: DeletedListener) {
    for (let i = 0; i < this.deletedListeners.length; i++) {
      if (this.deletedListeners[i] === l) {
        this.deletedListeners.splice(i, 1)
        break
      }
    }
  }

  setDeleted(channelId: string, channelType: number) {
    if (this.deletedListeners.length === 0) {
      return
    }
    this.deletedListeners.forEach((l) => {
      l(channelId, channelType)
    })
  }
}