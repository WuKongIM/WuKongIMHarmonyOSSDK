import { WKChannelType, WKConversation, WKConversationExtra, WKMsg, WKReminder } from '../entity/Bean'
import { relationalStore } from '@kit.ArkData'
import { WKDBConst } from './WKDBConst'
import { CommonUtil } from '../common/CommonUtil'
import { WKDBHelper } from './WKDBHelper'
import { WKLogger } from '../common/WKLogger'
import { ChannelDB } from './ChannelDB'
import { ReminderDB } from './ReminderDB'

export class ConversationDB {
  static shared: ConversationDB = new ConversationDB()

  private constructor() {
  }

  readonly tag = 'ConversationDB'
  readonly extraCols =
    `IFNULL(${WKDBConst.tableConversationExtra}.browse_to,0) AS browse_to,IFNULL(${WKDBConst.tableConversationExtra}.keep_message_seq,0) AS keep_message_seq,IFNULL(${WKDBConst.tableConversationExtra}.keep_offset_y,0) AS keep_offset_y,IFNULL(${WKDBConst.tableConversationExtra}.draft,'') AS draft,IFNULL(${WKDBConst.tableConversationExtra}.draft_updated_at,0) AS draft_updated_at,IFNULL(${WKDBConst.tableConversationExtra}.version,0) AS extra_version`
  readonly channelCols =
    `${WKDBConst.tableChannel}.channel_remark,${WKDBConst.tableChannel}.channel_name,${WKDBConst.tableChannel}.top,${WKDBConst.tableChannel}.mute,${WKDBConst.tableChannel}.save,${WKDBConst.tableChannel}.status as channel_status,${WKDBConst.tableChannel}.forbidden,${WKDBConst.tableChannel}.invite,${WKDBConst.tableChannel}.follow,${WKDBConst.tableChannel}.is_deleted as channel_is_deleted,${WKDBConst.tableChannel}.show_nick,${WKDBConst.tableChannel}.avatar,${WKDBConst.tableChannel}.avatar_cache_key,${WKDBConst.tableChannel}.online,${WKDBConst.tableChannel}.last_offline,${WKDBConst.tableChannel}.category,${WKDBConst.tableChannel}.receipt,${WKDBConst.tableChannel}.robot,${WKDBConst.tableChannel}.parent_channel_id AS c_parent_channel_id,${WKDBConst.tableChannel}.parent_channel_type AS c_parent_channel_type,${WKDBConst.tableChannel}.version AS channel_version,${WKDBConst.tableChannel}.remote_extra AS channel_remote_extra,${WKDBConst.tableChannel}.extra AS channel_extra`

  queryAll() {
    if (WKDBHelper.shared.getDB() === undefined) {
      return
    }
    let list: WKConversation[] = []
    let resultSet: relationalStore.ResultSet | undefined
    try {
      let sql =
        `SELECT ${WKDBConst.tableConversation}.*,${this.channelCols},${this.extraCols} FROM ${WKDBConst.tableConversation} LEFT JOIN ${WKDBConst.tableChannel} ON ${WKDBConst.tableConversation}.channel_id = ${WKDBConst.tableChannel}.channel_id AND ${WKDBConst.tableConversation}.channel_type = ${WKDBConst.tableChannel}.channel_type LEFT JOIN ${WKDBConst.tableConversationExtra} ON ${WKDBConst.tableConversation}.channel_id=${WKDBConst.tableConversationExtra}.channel_id AND ${WKDBConst.tableConversation}.channel_type=${WKDBConst.tableConversationExtra}.channel_type where ${WKDBConst.tableConversation}.is_deleted=0 order by last_msg_timestamp desc`
      resultSet = WKDBHelper.shared.getDB()?.querySqlSync(sql)
      let channelIds: string[] = []
      while (resultSet?.goToNextRow()) {
        let m = this.serializeConvMsg(resultSet)
        let c = ChannelDB.shared.serializeChannel(resultSet)
        m.setChannel(c)
        channelIds.push(m.channelId)
        list.push(m)
      }
      if (channelIds.length > 0) {
        // 查询所有提醒项
        let reminders = ReminderDB.shared.queryWithChannelIds(channelIds)
        if (reminders.length > 0) {
          list.forEach((c) => {
            let reminderList: WKReminder[] = []
            reminders.forEach((r) => {
              if (c.channelId === r.channelId && c.channelType === r.channelType && r.done === 0) {
                reminderList.push(r)
              }
            })
            c.setReminders(reminderList)
          })
        }
      }
      return list
    } catch (e) {
      WKLogger.error('查询最近会话错误,', this.tag, ':queryAll', e)
      return list
    } finally {
      resultSet?.close()
    }
  }

  query(channelId: string, channelType: number): WKConversation | undefined {
    let resultSet: relationalStore.ResultSet | undefined
    let msg: WKConversation | undefined
    let sql =
      `SELECT ${WKDBConst.tableConversation}.*,${this.channelCols},${this.extraCols} FROM ${WKDBConst.tableConversation} LEFT JOIN ${WKDBConst.tableChannel} ON ${WKDBConst.tableConversation}.channel_id = ${WKDBConst.tableChannel}.channel_id AND ${WKDBConst.tableConversation}.channel_type = ${WKDBConst.tableChannel}.channel_type LEFT JOIN ${WKDBConst.tableConversationExtra} ON ${WKDBConst.tableConversation}.channel_id=${WKDBConst.tableConversationExtra}.channel_id AND ${WKDBConst.tableConversation}.channel_type=${WKDBConst.tableConversationExtra}.channel_type where ${WKDBConst.tableConversation}.is_deleted=0 and ${WKDBConst.tableConversation}.channel_id=? and ${WKDBConst.tableConversation}.channel_type=? order by last_msg_timestamp desc`
    try {
      resultSet = WKDBHelper.shared.getDB()?.querySqlSync(sql, [channelId, channelType])
      if (resultSet?.goToNextRow()) {
        msg = this.serializeConvMsg(resultSet)
        let c = ChannelDB.shared.serializeChannel(resultSet)
        msg.setChannel(c)
      }
      return msg
    } catch (e) {
      return msg
    } finally {
      resultSet?.close()
    }
  }

  queryLastMsgSeqs(): string {
    let lastMsgSeqs = ''
    let sql =
      `select GROUP_CONCAT(channel_id||':'||channel_type||':'|| last_seq,'|') synckey from (select *,(select max(message_seq) from ${WKDBConst.tableMessage} where ${WKDBConst.tableMessage}.channel_id=${WKDBConst.tableConversation}.channel_id and ${WKDBConst.tableMessage}.channel_type=${WKDBConst.tableConversation}.channel_type limit 1) last_seq from ${WKDBConst.tableConversation}) cn where channel_id<>'' AND is_deleted=0`
    let resultSet: relationalStore.ResultSet | undefined
    try {
      resultSet = WKDBHelper.shared.getDB()?.querySqlSync(sql)
      if (resultSet?.goToNextRow()) {
        lastMsgSeqs = WKDBConst.getString(resultSet, 'synckey')
      }
      return lastMsgSeqs
    } catch (e) {
      WKLogger.error(`查询错误,`, this.tag, 'queryLastMsgSeqs')
      return lastMsgSeqs
    } finally {
      resultSet?.close()
    }
  }

  clearAll(): boolean {
    try {
      let p = new relationalStore.RdbPredicates(WKDBConst.tableConversation)
      let row = WKDBHelper.shared.getDB()?.deleteSync(p)
      if (row === undefined) {
        return false
      }
      return true
    } catch (e) {
      WKLogger.error('清空所有最近会话错误', this.tag, 'clearAll')
      return false
    }
  }

  clearAllRedDot(): boolean {
    let vb: relationalStore.ValuesBucket = {
      'unread_count': 0
    }
    try {
      let p = new relationalStore.RdbPredicates(WKDBConst.tableConversation)
      let row = WKDBHelper.shared.getDB()?.updateSync(vb, p)
      if (row === undefined) {
        return true
      }
      return false
    } catch (e) {
      WKLogger.error(`清空所有红点错误,`, this.tag, 'clearAllRedDot')
      return false
    }
  }

  updateWithField(key: string, value: string | number, channelId: string, channelType: number): boolean {
    let vb: relationalStore.ValuesBucket = {}
    vb[key] = value
    try {
      let p = new relationalStore.RdbPredicates(WKDBConst.tableConversation)
      p.equalTo('channel_id', channelId).and().equalTo('channel_type', channelType)
      let row = WKDBHelper.shared.getDB()?.updateSync(vb, p)
      if (row === undefined) {
        return false
      }
      WKLogger.error(`修改字段返回行数：${row}`)
      return true
    } catch (e) {
      WKLogger.error(`修改最近会话字段错误,`, this.tag, '：clearAllRedDot', e.message)
      return false
    }
  }

  queryExtraMaxVersion(): number {
    let version = 0
    let sql = `select max(version) version from ${WKDBConst.tableConversationExtra}`
    let resultSet: relationalStore.ResultSet | undefined
    try {
      resultSet = WKDBHelper.shared.getDB()?.querySqlSync(sql)
      if (resultSet?.goToNextRow()) {
        version = WKDBConst.getNumber(resultSet, 'version')
      }
      return version
    } catch (e) {
      WKLogger.error('查询最近会话扩展最大编号错误', this.tag, 'queryExtraMaxVersion')
      return version
    } finally {
      resultSet?.close()
    }
  }

  insertWithWKMsg(msg: WKMsg,isSend:boolean): WKConversation {
    let convMsg = new WKConversation()
    if (msg.channelType == WKChannelType.communityTopic && CommonUtil.strIsUnEmpty(msg.channelId)) {
      if (msg.channelId.indexOf("@")) {
        let str = msg.channelId.split("@")
        convMsg.parentChannelId = str[0]
        convMsg.parentChannelType = WKChannelType.community
      }
    }
    convMsg.channelId = msg.channelId
    convMsg.channelType = msg.channelType
    convMsg.lastMsgTimestamp = msg.timestamp
    convMsg.lastClientMsgNo = msg.clientMsgNo
    convMsg.lastMsgSeq = msg.messageSeq
    if (!isSend) {
      convMsg.unreadCount = msg.header.redDot ? 1 : 0
    }

    let lastMsg = this.query(msg.channelId, msg.channelType)
    if (lastMsg !== undefined) {
      convMsg.localExtra = lastMsg.localExtra
      convMsg.remoteExtra = lastMsg.remoteExtra
      convMsg.version = lastMsg.version
      convMsg.unreadCount = lastMsg.unreadCount + convMsg.unreadCount
    }
    this.insertOrReplace(convMsg)
    return convMsg
  }

  insertOrReplace(msg: WKConversation): boolean {
    let vb = this.getVB(msg, false)
    try {
      let row = WKDBHelper.shared.getDB()?.insertSync(WKDBConst.tableConversation, vb,
        relationalStore.ConflictResolution.ON_CONFLICT_REPLACE)
      if (row === undefined) {
        return false
      }
      return row > 0
    } catch (e) {
      WKLogger.error('插入最近会话错误', this.tag, 'insertOrReplace', e)
      return false
    }
  }

  insertOrReplaces(list: WKConversation[]) {
    let vbs: relationalStore.ValuesBucket[] = []
    for (let i = 0; i < list.length; i++) {
      let vb = this.getVB(list[i], true)
      vbs.push(vb)
    }
    try {
      WKDBHelper.shared.getDB()?.beginTransaction()
      for (let i = 0; i < vbs.length; i++) {
        let vb = vbs[i]

        let row = WKDBHelper.shared.getDB()?.insertSync(WKDBConst.tableConversation, vb,
          relationalStore.ConflictResolution.ON_CONFLICT_REPLACE)
        WKLogger.error(`插入最近会话：${row}`)
      }
    } catch (e) {
      WKLogger.error('批量插入最近会话错误，', this.tag, '：insertOrReplaces', e)
    } finally {
      WKDBHelper.shared.getDB()?.commit()
    }
  }

  insertOrReplaceExtras(list: WKConversationExtra[]) {
    let vbs: relationalStore.ValuesBucket[] = []
    for (let i = 0; i < list.length; i++) {
      let vb = this.getExtraVB(list[i])
      vbs.push(vb)
    }
    try {
      WKDBHelper.shared.getDB()?.beginTransaction()
      for (let i = 0; i < vbs.length; i++) {
        let vb = vbs[i]
        WKDBHelper.shared.getDB()?.insertSync(WKDBConst.tableConversationExtra, vb,
          relationalStore.ConflictResolution.ON_CONFLICT_REPLACE)
      }
    } catch (e) {
      WKLogger.error('批量插入最近会话扩展错误', this.tag, 'insertOrReplaceExtras', e)
    } finally {
      WKDBHelper.shared.getDB()?.commit()
    }
  }

  serializeConvMsg(r: relationalStore.ResultSet) {
    let c = new WKConversation()
    c.channelId = WKDBConst.getString(r, 'channel_id')
    c.channelType = WKDBConst.getNumber(r, 'channel_type')
    c.lastClientMsgNo = WKDBConst.getString(r, 'last_client_msg_no')
    c.lastMsgTimestamp = WKDBConst.getNumber(r, 'last_msg_timestamp')
    c.lastMsgSeq = WKDBConst.getNumber(r, 'last_msg_seq')
    c.unreadCount = WKDBConst.getNumber(r, 'unread_count')
    c.parentChannelId = WKDBConst.getString(r, 'parent_channel_id')
    c.parentChannelType = WKDBConst.getNumber(r, 'parent_channel_type')
    c.isDeleted = WKDBConst.getNumber(r, 'is_deleted')
    c.version = WKDBConst.getNumber(r, 'version')
    let extra = WKDBConst.getString(r, 'extra')
    if (CommonUtil.strIsUnEmpty(extra)) {
      c.localExtra = CommonUtil.jsonToRecord(extra)
    }
    c.remoteExtra = this.serializeConvMsgExtra(r)
    return c
  }

  serializeConvMsgExtra(r: relationalStore.ResultSet) {
    let extra = new WKConversationExtra()
    extra.channelId = WKDBConst.getString(r, 'channel_id')
    extra.channelType = WKDBConst.getNumber(r, 'channel_type')
    extra.keepMessageSeq = WKDBConst.getNumber(r, 'keep_message_seq')
    extra.keepOffsetY = WKDBConst.getNumber(r, 'keep_offset_y')
    extra.draft = WKDBConst.getString(r, 'draft')
    extra.browseTo = WKDBConst.getNumber(r, 'browse_to')
    extra.draftUpdatedAt = WKDBConst.getNumber(r, 'draft_updated_at')
    extra.version = WKDBConst.getNumber(r, 'version')
    let v = WKDBConst.getNumber(r, 'extra_version')
    if (v > 0) {
      extra.version = v
    }
    return extra
  }

  private getVB(c: WKConversation, isSync: boolean) {
    let extra = ''
    if (c.localExtra !== undefined) {
      extra = JSON.stringify(c.localExtra)
    }
    let vb: relationalStore.ValuesBucket = {
      'channel_id': c.channelId,
      'channel_type': c.channelType,
      'last_client_msg_no': c.lastClientMsgNo,
      'last_msg_timestamp': c.lastMsgTimestamp,
      'last_msg_seq': c.lastMsgSeq,
      'unread_count': c.unreadCount,
      'parent_channel_id': c.parentChannelId,
      'parent_channel_type': c.parentChannelType,
      'is_deleted': c.isDeleted,
      'extra': extra
    }
    if (isSync) {
      vb['version'] = c.version
    }
    return vb
  }

  getExtraVB(e: WKConversationExtra) {
    let vb: relationalStore.ValuesBucket = {
      'channel_id': e.channelId,
      'channel_type': e.channelType,
      'keep_message_seq': e.keepMessageSeq,
      'keep_offset_y': e.keepOffsetY,
      'draft': e.draft,
      'browse_to': e.browseTo,
      'draft_updated_at': e.draftUpdatedAt,
      'version': e.version
    }
    return vb
  }
}