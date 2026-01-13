import {
  ChannelMsgOptions,
  WKChannel,
  WKChannelType,
  WKMsg,
  WKMsgExtra,
  WKMsgSetting,
  WKSyncChannelMsg
} from '../entity/Bean';
import { WKDBConst } from './WKDBConst';
import { WKDBHelper } from './WKDBHelper';
import { relationalStore } from '@kit.ArkData';
import { CommonUtil } from '../common/CommonUtil';
import { WKIM } from '../WKIM';
import { WKLogger } from '../common/WKLogger';
import { ChannelDB } from './ChannelDB';
import { ChannelMemberDB } from './ChannelMemberDB';
import { ReactionDB } from './ReactionDB';
import { HashMap, JSON } from '@kit.ArkTS';
import { WKSendAckPacket } from '../protocol/WKPacket';

export class MessageDB {
  static shared: MessageDB = new MessageDB();

  private constructor() {
  }

  private requestCount = 0
  // private readonly channelMinMsgSeqMap: HashMap<string, number> = new HashMap()
  readonly tag = 'MessageDB'
  readonly extraCols =
    `IFNULL(${WKDBConst.tableMessageExtra}.readed,0) as readed,IFNULL(${WKDBConst.tableMessageExtra}.readed_count,0) as readed_count,IFNULL(${WKDBConst.tableMessageExtra}.unread_count,0) as unread_count,IFNULL(${WKDBConst.tableMessageExtra}.revoke,0) as revoke,IFNULL(${WKDBConst.tableMessageExtra}.revoker,'') as revoker,IFNULL(${WKDBConst.tableMessageExtra}.extra_version,0) as extra_version,IFNULL(${WKDBConst.tableMessageExtra}.is_mutual_deleted,0) as is_mutual_deleted,IFNULL(${WKDBConst.tableMessageExtra}.need_upload,0) as need_upload,IFNULL(${WKDBConst.tableMessageExtra}.content_edit,'') as content_edit,IFNULL(${WKDBConst.tableMessageExtra}.edited_at,0) as edited_at,IFNULL(${WKDBConst.tableMessageExtra}.is_pinned,0) as is_pinned`;
  readonly messageCols =
    `${WKDBConst.tableMessage}.client_seq,${WKDBConst.tableMessage}.message_id,${WKDBConst.tableMessage}.message_seq,${WKDBConst.tableMessage}.channel_id,${WKDBConst.tableMessage}.channel_type,${WKDBConst.tableMessage}.timestamp,${WKDBConst.tableMessage}.topic_id,${WKDBConst.tableMessage}.from_uid,${WKDBConst.tableMessage}.type,${WKDBConst.tableMessage}.content,${WKDBConst.tableMessage}.status,${WKDBConst.tableMessage}.voice_status,${WKDBConst.tableMessage}.created_at,${WKDBConst.tableMessage}.updated_at,${WKDBConst.tableMessage}.searchable_word,${WKDBConst.tableMessage}.client_msg_no,${WKDBConst.tableMessage}.setting,${WKDBConst.tableMessage}.order_seq,${WKDBConst.tableMessage}.extra,${WKDBConst.tableMessage}.is_deleted,${WKDBConst.tableMessage}.flame,${WKDBConst.tableMessage}.flame_second,${WKDBConst.tableMessage}.viewed,${WKDBConst.tableMessage}.viewed_at,${WKDBConst.tableMessage}.expire_time,${WKDBConst.tableMessage}.expire_timestamp`;

  queryMessages(channelId: string, channelType: number, oldestOrderSeq: number, contain: boolean, pullMode: number,
    limit: number): WKMsg[] {
    let sql = ''
    let args: Array<relationalStore.ValueType> = []
    if (oldestOrderSeq <= 0) {
      sql =
        `SELECT * FROM (SELECT ${this.messageCols},${this.extraCols} FROM ${WKDBConst.tableMessage} LEFT JOIN ${WKDBConst.tableMessageExtra} on ${WKDBConst.tableMessage}.message_id=${WKDBConst.tableMessageExtra}.message_id WHERE ${WKDBConst.tableMessage}.channel_id=? and ${WKDBConst.tableMessage}.channel_type=? and ${WKDBConst.tableMessage}.type<>0 and ${WKDBConst.tableMessage}.type<>99) where is_deleted=0 and is_mutual_deleted=0 order by order_seq desc limit 0,${limit}`
      args.push(channelId)
      args.push(channelType)
    } else {
      if (pullMode === 0) {
        if (contain) {
          sql =
            `SELECT * FROM (SELECT ${this.messageCols},${this.extraCols} FROM ${WKDBConst.tableMessage} LEFT JOIN ${WKDBConst.tableMessageExtra} on ${WKDBConst.tableMessage}.message_id=${WKDBConst.tableMessageExtra}.message_id WHERE ${WKDBConst.tableMessage}.channel_id=? and ${WKDBConst.tableMessage}.channel_type=? and ${WKDBConst.tableMessage}.type<>0 and ${WKDBConst.tableMessage}.type<>99 AND ${WKDBConst.tableMessage}.order_seq<=?) where is_deleted=0 and is_mutual_deleted=0 order by order_seq desc limit 0,${limit}`
        } else {
          sql =
            `SELECT * FROM (SELECT ${this.messageCols},${this.extraCols} FROM ${WKDBConst.tableMessage} LEFT JOIN ${WKDBConst.tableMessageExtra} on ${WKDBConst.tableMessage}.message_id=${WKDBConst.tableMessageExtra}.message_id WHERE ${WKDBConst.tableMessage}.channel_id=? and ${WKDBConst.tableMessage}.channel_type=? and ${WKDBConst.tableMessage}.type<>0 and ${WKDBConst.tableMessage}.type<>99 AND ${WKDBConst.tableMessage}.order_seq<?) where is_deleted=0 and is_mutual_deleted=0 order by order_seq desc limit 0,${limit}`
        }
      } else {
        if (contain) {
          sql =
            `SELECT * FROM (SELECT ${this.messageCols},${this.extraCols} FROM ${WKDBConst.tableMessage} LEFT JOIN ${WKDBConst.tableMessageExtra} on ${WKDBConst.tableMessage}.message_id=${WKDBConst.tableMessageExtra}.message_id WHERE ${WKDBConst.tableMessage}.channel_id=? and ${WKDBConst.tableMessage}.channel_type=? and ${WKDBConst.tableMessage}.type<>0 and ${WKDBConst.tableMessage}.type<>99 AND ${WKDBConst.tableMessage}.order_seq>=?) where is_deleted=0 and is_mutual_deleted=0 order by order_seq desc limit 0,${limit}`
        } else {
          sql =
            `SELECT * FROM (SELECT ${this.messageCols},${this.extraCols} FROM ${WKDBConst.tableMessage} LEFT JOIN ${WKDBConst.tableMessageExtra} on ${WKDBConst.tableMessage}.message_id=${WKDBConst.tableMessageExtra}.message_id WHERE ${WKDBConst.tableMessage}.channel_id=? and ${WKDBConst.tableMessage}.channel_type=? and ${WKDBConst.tableMessage}.type<>0 and ${WKDBConst.tableMessage}.type<>99 AND ${WKDBConst.tableMessage}.order_seq>?) where is_deleted=0 and is_mutual_deleted=0 order by order_seq desc limit 0,${limit}`
        }
      }
      args.push(channelId)
      args.push(channelType)
      args.push(oldestOrderSeq)
    }
    let resultSet: relationalStore.ResultSet | undefined
    let msgList: WKMsg[] = []
    let messageIds: string[] = []
    let replyMsgIds: string[] = []
    let fromUIDs: string[] = []
    let channel = WKIM.shared.channelManager().getChannel(channelId, channelType)
    try {
      resultSet = WKDBHelper.shared.getDB()?.querySqlSync(sql, args)
      while (resultSet?.goToNextRow()) {
        let msg = this.serializeWKMsg(resultSet)
        if (channel !== undefined) {
          msg.setChannelInfo(channel)
        }
        if (CommonUtil.strIsUnEmpty(msg.messageId)) {
          messageIds.push(msg.messageId)
        }
        if (CommonUtil.strIsUnEmpty(msg.fromUID)) {
          fromUIDs.push(msg.fromUID)
        }
        if (msg.messageContent !== undefined && msg.messageContent?.reply !== undefined &&
        CommonUtil.strIsUnEmpty(msg.messageContent?.reply?.messageId)) {
          replyMsgIds.push(msg.messageContent?.reply?.messageId)
        }
        if (pullMode === 0) {
          msgList.unshift(msg)
        } else {
          msgList.push(msg)
        }
      }
      let realFromUIDs = CommonUtil.removeDuplicates(fromUIDs)
      if (realFromUIDs.length > 0) {
        let channels = ChannelDB.shared.queryWithChannelIds(realFromUIDs)
        if (channels.length > 0) {
          channels.forEach((channel: WKChannel) => {
            for (let i = 0; i < msgList.length; i++) {
              if (channel.channelType === WKChannelType.personal && CommonUtil.strIsUnEmpty(msgList[i].fromUID) &&
                msgList[i].fromUID === channel.channelId) {
                msgList[i].setFrom(channel)
              }
            }
          })
        }

        if (channelType === WKChannelType.group) {
          let members = ChannelMemberDB.shared.queryWithUIDs(channelId, channelType, realFromUIDs)
          if (members.length > 0) {
            members.forEach((member) => {
              for (let i = 0; i < msgList.length; i++) {
                if (CommonUtil.strIsUnEmpty(msgList[i].fromUID) && member.memberUID === msgList[i].fromUID) {
                  msgList[i].setMemberOfFrom(member)
                }
              }
            })
          }
        }
      }

      if (messageIds.length > 0) {
        let rs = ReactionDB.shared.queryWithMsgIds(messageIds)
        if (rs.length > 0) {
          rs.forEach((r) => {
            msgList.forEach((m) => {
              if (m.messageId === r.messageId) {
                if (m.reactionList === undefined) {
                  m.reactionList = []
                }
                m.reactionList.push(r)
              }
            })
          })
        }
      }

      if (replyMsgIds.length > 0) {
        let realReplyMsgIds = CommonUtil.removeDuplicates(replyMsgIds)
        if (realReplyMsgIds.length > 0) {
          let extraMsgs = this.queryExtrasWithMsgIds(replyMsgIds)
          if (extraMsgs.length > 0) {
            extraMsgs.forEach((extraMsg) => {
              for (let i = 0; i < msgList.length; i++) {
                if (msgList[i].messageContent !== undefined && msgList[i].messageContent?.reply !== undefined &&
                  extraMsg.messageId === msgList[i].messageContent?.reply?.messageId) {
                  msgList[i].messageContent!.reply!.revoke = extraMsg.revoke

                  if (CommonUtil.strIsUnEmpty(extraMsg.contentEdit)) {
                    msgList[i].messageContent!.reply!.contentEdit = extraMsg.contentEdit
                    msgList[i].messageContent!.reply!.editAt = extraMsg.editedAt
                    msgList[i].messageContent!.reply!.contentEditMsgModel =
                      WKIM.shared.messageManager().getMessageModel(extraMsg.contentEdit)
                  }
                }
              }
            })
          }
        }
      }
      return msgList
    } catch (e) {
      WKLogger.error(`查询错误,${this.tag}:queryMessages`)
      return msgList
    } finally {
      WKDBHelper.shared.safeClose(resultSet)
    }
  }

  queryOrSyncHistoryMessages(channel: WKChannel, option: ChannelMsgOptions) {
    let list =
      this.queryMessages(channel.channelId, channel.channelType, option.oldestOrderSeq, option.contain, option.pullMode,
        option.limit)
    let tempList: WKMsg[] = []
    tempList.push(...list)
    tempList.sort((a: WKMsg, b: WKMsg): number => {
      return a.messageSeq - b.messageSeq
    })

    let minMessageSeq = 0
    let maxMessageSeq = 0
    for (let i = 0, size = tempList.length; i < size; i++) {
      if (tempList[i].messageSeq != 0) {
        if (minMessageSeq == 0) {
          minMessageSeq = tempList[i].messageSeq
        }
        if (tempList[i].messageSeq > maxMessageSeq) {
          maxMessageSeq = tempList[i].messageSeq
        }
        if (tempList[i].messageSeq < minMessageSeq) {
          minMessageSeq = tempList[i].messageSeq
        }
      }
    }

    let isSyncMsg = false
    let startMsgSeq = 0
    let endMsgSeq = 0
    let oldestMsgSeq = 0
    if (option.oldestOrderSeq % 1000 != 0) {
      oldestMsgSeq = this.queryMsgSeq(channel.channelId, channel.channelType, option.oldestOrderSeq,
        option.pullMode)
    } else {
      oldestMsgSeq = option.oldestOrderSeq / 1000
    }
    if (option.pullMode === 0) {
      if (oldestMsgSeq === 1) {
        option.iResult(list)
        return
      }
      //下拉获取消息 大->小
      if (maxMessageSeq != 0 && oldestMsgSeq != 0 && oldestMsgSeq - maxMessageSeq > 1) {
        isSyncMsg = true;
        if (option.contain) {
          startMsgSeq = oldestMsgSeq;
        } else {
          startMsgSeq = oldestMsgSeq - 1;
        }
        endMsgSeq = maxMessageSeq;
      }
    } else {
      //上拉获取消息 小->大
      if (minMessageSeq != 0 && oldestMsgSeq != 0 && minMessageSeq - oldestMsgSeq > 1) {
        isSyncMsg = true;
        if (option.contain) {
          startMsgSeq = oldestMsgSeq;
        } else {
          startMsgSeq = oldestMsgSeq + 1;
        }
        endMsgSeq = minMessageSeq;
      }
    }

    if (!isSyncMsg) {
      //判断当前页是否连续
      for (let i = 0, size = tempList.length; i < size; i++) {
        let nextIndex = i + 1;
        if (nextIndex < tempList.length) {
          if (tempList[nextIndex].messageSeq != 0 && tempList[i].messageSeq != 0 &&
            tempList[nextIndex].messageSeq - tempList[i].messageSeq > 1) {
            //判断该条消息是否被删除
            let num = this.queryDeletedCount(tempList[i].messageSeq, tempList[nextIndex].messageSeq, channel.channelId,
              channel.channelType)
            if (num < (tempList[nextIndex].messageSeq - tempList[i].messageSeq) - 1) {
              isSyncMsg = true
              let max = tempList[nextIndex].messageSeq
              let min = tempList[i].messageSeq
              if (tempList[nextIndex].messageSeq < tempList[i].messageSeq) {
                max = tempList[i].messageSeq
                min = tempList[nextIndex].messageSeq
              }
              if (option.pullMode == 0) {
                // 下拉
                if (max > startMsgSeq) {
                  startMsgSeq = max
                }
                if (endMsgSeq == 0 || min < endMsgSeq) {
                  endMsgSeq = min
                }
              } else {
                if (startMsgSeq == 0 || min < startMsgSeq) {
                  startMsgSeq = min
                }
                if (max > endMsgSeq) {
                  endMsgSeq = max
                }
              }
            }
          }
        }
      }
    }
    if (option.oldestOrderSeq == 0) {
      isSyncMsg = true
      startMsgSeq = 0
      endMsgSeq = 0
    }
    // let key = `${channel.channelId}_${channel.channelType}`
    if (!isSyncMsg) {
      let minSeq = 1;
      // if (this.channelMinMsgSeqMap.hasKey(key)) {
      //   minSeq = this.channelMinMsgSeqMap.get(key)
      // }
      if (minMessageSeq == minSeq) {
        this.requestCount = 0
        //                more = 1
        option.iResult(list)
        return;
      }
    }

    //计算最后一页后是否还存在消息
    if (!isSyncMsg && tempList.length < option.limit) {
      isSyncMsg = true
      if (option.contain) {
        startMsgSeq = oldestMsgSeq;
      } else {
        if (option.pullMode == 0) {
          startMsgSeq = oldestMsgSeq - 1
        } else {
          startMsgSeq = oldestMsgSeq + 1
        }
      }
      endMsgSeq = 0
    }
    if (startMsgSeq == 0 && endMsgSeq == 0 && tempList.length < option.limit) {
      isSyncMsg = true;
      endMsgSeq = oldestMsgSeq;
      startMsgSeq = 0;
    }
    if (isSyncMsg && this.requestCount < 5) {
      if (this.requestCount == 0) {
        option.iSyncing()
      }
      //同步消息
      this.requestCount++
      WKIM.shared.messageManager()
        .syncChannelMsgs(channel, startMsgSeq, endMsgSeq, option.pullMode, option.limit)
        .then((msg) => {
          if (msg !== undefined) {
            if (oldestMsgSeq === 0 || msg.msgs === undefined || msg.msgs.length < option.limit) {
              this.requestCount = 5
            }
            this.queryOrSyncHistoryMessages(channel, option)
          } else {
            this.requestCount = 0
            option.iResult(list)
          }
        })
    } else {
      this.requestCount = 0;
      //            more = 1;
      option.iResult(list)
    }
  }

  private queryDeletedCount(minMessageSeq: number, maxMessageSeq: number, channelId: string, channelType: number) {
    let sql =
      `select count(*) num from ${WKDBConst.tableMessage} where channel_id=? and channel_type=? and message_seq >? and message_seq <? and is_deleted=1`
    let num = 0
    let resultSet: relationalStore.ResultSet | undefined
    try {
      resultSet = WKDBHelper.shared.getDB()?.querySqlSync(sql, [channelId, channelType, minMessageSeq, maxMessageSeq])
      if (resultSet?.goToNextRow()) {
        num = WKDBConst.getNumber(resultSet, 'num')
      }
      return num
    } catch (e) {
      WKLogger.error('查询错误', this.tag, 'queryDeletedCount', e)
      return num
    } finally {
      WKDBHelper.shared.safeClose(resultSet)
    }
  }

  private getMinSeq(syncChannelMsg: WKSyncChannelMsg, tempList: WKMsg[]) {
    let minSeq = 0
    if (syncChannelMsg.msgs !== undefined && syncChannelMsg.msgs.length > 0) {
      syncChannelMsg.msgs.forEach((msg) => {
        if (minSeq == 0) {
          minSeq = msg.messageSeq
        } else {
          minSeq = Math.min(minSeq, msg.messageSeq)
        }
      })

    } else {
      if (tempList.length > 0) {
        tempList.forEach((msg) => {
          if (minSeq == 0) {
            minSeq = msg.messageSeq
          } else {
            minSeq = Math.min(minSeq, msg.messageSeq)
          }
        })
      }
    }
    return minSeq
  }

  private queryMsgSeq(channelId: string, channelType: number, oldestOrderSeq: number, pullModel: number) {
    let sql = ''
    let seq = 0
    if (pullModel === 1) {
      sql =
        `select * from ${WKDBConst.tableMessage} where channel_id=? and channel_type=? and  order_seq>? and message_seq<>0 order by message_seq desc limit 1`
    } else {
      sql =
        `select * from ${WKDBConst.tableMessage} where channel_id=? and channel_type=? and  order_seq<? and message_seq<>0 order by message_seq asc limit 1`
    }
    let resultSet: relationalStore.ResultSet | undefined
    try {
      resultSet = WKDBHelper.shared.getDB()?.querySqlSync(sql, [channelId, channelType, oldestOrderSeq])
      if (resultSet?.goToNextRow()) {
        seq = WKDBConst.getNumber(resultSet, 'message_seq')
      }
      return seq
    } catch (e) {
      WKLogger.error('查询错误', this.tag, 'queryMsgSeq', e)
      return seq
    } finally {
      WKDBHelper.shared.safeClose(resultSet)
    }
  }

  queryWithClientMsgNos(ids: string[]) {
    let resultSet: relationalStore.ResultSet | undefined
    let msgs: WKMsg[] = []
    try {
      let sql =
        `select * from ${WKDBConst.tableMessage} where client_msg_no in (${WKDBConst.getPlaceholders(ids.length)})`
      resultSet = WKDBHelper.shared.getDB()?.querySqlSync(sql, ids)
      while (resultSet?.goToNextRow()) {
        let msg = this.serializeWKMsg(resultSet)
        msgs.push(msg)
      }
      return msgs
    } catch (e) {
      WKLogger.error('查询错误', this.tag, 'queryWithClientMsgNos', e)
      return msgs
    } finally {
      WKDBHelper.shared.safeClose(resultSet)
    }
  }

  queryExtraWithNeddUpload(needUpload: number) {
    let resultSet: relationalStore.ResultSet | undefined
    let sql = `select * from ${WKDBConst.tableMessageExtra}  where need_upload=?`
    let list: WKMsgExtra[] = []
    try {
      resultSet = WKDBHelper.shared.getDB()?.querySqlSync(sql, [needUpload])
      while (resultSet?.goToNextRow()) {
        let msg = this.serializeMsgExtra(resultSet)
        list.push(msg)
      }
      return list
    } catch (e) {
      WKLogger.error('查询失败', this.tag, 'queryExtraWithNeddUpload', e.message)
      return list
    } finally {
      WKDBHelper.shared.safeClose(resultSet)
    }
  }

  queryExtraWithMsgId(messageId: string): WKMsgExtra | undefined {
    let resultSet: relationalStore.ResultSet | undefined
    let sql = `select * from ${WKDBConst.tableMessageExtra} where message_id=?`
    try {
      resultSet = WKDBHelper.shared.getDB()?.querySqlSync(sql, [messageId])
      if (resultSet?.goToNextRow()) {
        let msg = this.serializeMsgExtra(resultSet)
        return msg
      }
      return undefined
    } catch (e) {
      WKLogger.error('查询失败', this.tag, 'queryExtraWithMsgId', `参数：{messageId:${messageId}`, e.message)
      return undefined
    } finally {
      WKDBHelper.shared.safeClose(resultSet)
    }
  }

  queryExtrasWithMsgIds(messageIds: string[]) {
    let resultSet: relationalStore.ResultSet | undefined
    let msgs: WKMsgExtra[] = []
    try {
      let sql =
        `select * from ${WKDBConst.tableMessageExtra} where message_id in (${WKDBConst.getPlaceholders(messageIds.length)})`
      resultSet = WKDBHelper.shared.getDB()?.querySqlSync(sql, messageIds)
      while (resultSet?.goToNextRow()) {
        let msg = this.serializeMsgExtra(resultSet)
        msgs.push(msg)
      }
      return msgs
    } catch (e) {
      WKLogger.error(`查询错误,${this.tag}:queryMsgExtrasWithMsgIds`)
      return msgs
    } finally {
      WKDBHelper.shared.safeClose(resultSet)
    }
  }

  queryWithMessageId(messageId: string): WKMsg | null {
    let resultSet: relationalStore.ResultSet | undefined
    try {
      let sql =
        `select ${this.messageCols},${this.extraCols} from ${WKDBConst.tableMessage} left join ${WKDBConst.tableMessageExtra} on ${WKDBConst.tableMessage}.message_id=${WKDBConst.tableMessageExtra}.message_id where ${WKDBConst.tableMessage}.message_id=?`
      resultSet = WKDBHelper.shared.getDB()?.querySqlSync(sql, [messageId])
      if (resultSet?.goToNextRow()) {
        return this.serializeWKMsg(resultSet)
      }
      return null
    } catch (e) {
      WKLogger.error(`查询报错,${this.tag}:queryWithMessageId`)
      return null
    } finally {
      WKDBHelper.shared.safeClose(resultSet)
    }
  }

  queryWithClientMsgSeq(clientSeq: number): WKMsg | undefined {
    let resultSet: relationalStore.ResultSet | undefined
    try {
      let sql =
        `select ${this.messageCols},${this.extraCols} from ${WKDBConst.tableMessage} left join ${WKDBConst.tableMessageExtra} on ${WKDBConst.tableMessage}.message_id=${WKDBConst.tableMessageExtra}.message_id where ${WKDBConst.tableMessage}.client_seq=?`
      resultSet = WKDBHelper.shared.getDB()?.querySqlSync(sql, [clientSeq])
      while (resultSet?.goToNextRow()) {
        return this.serializeWKMsg(resultSet)
      }
      return undefined
    } catch (e) {
      WKLogger.error(`查询报错,${this.tag}:queryWithClientMsgNo`)
      return undefined
    } finally {
      WKDBHelper.shared.safeClose(resultSet)
    }

  }

  queryWithClientMsgNo(clientMsgNo: string): WKMsg | undefined {
    let resultSet: relationalStore.ResultSet | undefined
    try {
      let sql =
        `select ${this.messageCols},${this.extraCols} from ${WKDBConst.tableMessage} left join ${WKDBConst.tableMessageExtra} on ${WKDBConst.tableMessage}.message_id=${WKDBConst.tableMessageExtra}.message_id where ${WKDBConst.tableMessage}.client_msg_no=?`
      resultSet = WKDBHelper.shared.getDB()?.querySqlSync(sql, [clientMsgNo])
      if (resultSet?.goToNextRow()) {
        let msg = this.serializeWKMsg(resultSet)
        return msg
      }
      return undefined
    } catch (e) {
      WKLogger.error(`查询报错,${this.tag}:queryWithClientMsgNo`)
      return undefined
    } finally {
      WKDBHelper.shared.safeClose(resultSet)
    }

  }

  queryMaxExtraVersion(channelId: string, channelType: number): number {
    let resultSet: relationalStore.ResultSet | undefined
    let sql =
      `select max(extra_version) extra_version from ${WKDBConst.tableMessageExtra} where channel_id=? and channel_type =?`
    try {
      resultSet = WKDBHelper.shared.getDB()?.querySqlSync(sql, [channelId, channelType])
      while (resultSet?.goToNextRow()) {
        return WKDBConst.getNumber(resultSet, 'extra_version')
      }
      return 0
    } catch (e) {
      WKLogger.error(`查询报错,${this.tag}:queryMaxExtraVersion`, e.message)
      return 0
    } finally {
      WKDBHelper.shared.safeClose(resultSet)
    }
  }

  queryMaxOrderSeq(channelId: string, channelType: number): number {
    let resultSet: relationalStore.ResultSet | undefined
    let sql =
      `select max(order_seq) order_seq from ${WKDBConst.tableMessage} where channel_id=? and channel_type =? and type<>99 and type<>0 and is_deleted=0`
    try {
      resultSet = WKDBHelper.shared.getDB()?.querySqlSync(sql, [channelId, channelType])
      while (resultSet?.goToNextRow()) {
        return WKDBConst.getNumber(resultSet, 'order_seq')
      }
      return 0
    } catch (e) {
      WKLogger.error(`查询报错,${this.tag}:queryMaxOrderSeq`)
      return 0
    } finally {
      WKDBHelper.shared.safeClose(resultSet)
    }
  }

  deleteWithChannel(channelId: string, channelType: number): boolean {
    const vb: relationalStore.ValuesBucket = {
      "is_deleted": 1,
      'content': ''
    }

    try {
      let p = new relationalStore.RdbPredicates(WKDBConst.tableMessage)
      p.equalTo('channel_id', channelId).and().equalTo('channel_type', channelType)
      let row = WKDBHelper.shared.getDB()?.updateSync(vb, p)
      if (row === undefined) {
        return false
      }
      return row > 0
    } catch (e) {
      WKLogger.error(`删除错误,${this.tag}:deleteWithChannel`, `channel_id:${channelId},channel_type:${channelType}`,
        e.message)
      return false
    }
  }

  deleteWithClientMsgNo(clientMsgNo: string): boolean {
    const vb: relationalStore.ValuesBucket = {
      'is_deleted': 1,
      'content': ''
    }
    try {
      let p = new relationalStore.RdbPredicates(WKDBConst.tableMessage)
      p.equalTo("client_msg_no", clientMsgNo)
      let row = WKDBHelper.shared.getDB()?.updateSync(vb, p)
      if (row === undefined) {
        return false
      }
      return row > 0
    } catch (e) {
      WKLogger.error(`删除错误,${this.tag}:deleteWithClientMsgNo`)
      return false
    }
  }

  insertExtras(list: WKMsgExtra[]) {
    let vbs: relationalStore.ValuesBucket[] = []
    list.forEach((m) => {
      let vb = this.getExtraVB(m)
      vbs.push(vb)
    })
    const db = WKDBHelper.shared.getDB()
    if (!db) {
      return
    }
    try {
      db.beginTransaction()
      vbs.forEach((vb) => {
        db.insertSync(WKDBConst.tableMessageExtra, vb,
          relationalStore.ConflictResolution.ON_CONFLICT_REPLACE)
      })
      db.commit()
    } catch (e) {
      WKLogger.error(`批量插入消息扩展错误，error:${e}`)
      WKDBHelper.shared.safeRollBack()
    }
  }

  inserts(list: WKMsg[]) {
    if (list.length === 1) {
      this.insert(list[0])
      return
    }
    let saveList: WKMsg[] = []
    for (let i = 0, size = list.length; i < size; i++) {
      let isAdd = true
      for (let j = 0, len = saveList.length; j < len; j++) {
        if (saveList[j].clientMsgNo === list[i].clientMsgNo) {
          isAdd = false
          break
        }
      }
      if (isAdd) {
        saveList.push(list[i])
      }
    }
    let tempClientMsgNos: string[] = []
    let existList: WKMsg[] = []
    for (let i = 0, size = saveList.length; i < size; i++) {
      if (tempClientMsgNos.length === 200) {
        let tempList = this.queryWithClientMsgNos(tempClientMsgNos)
        if (tempList.length > 0) {
          existList.push(...tempList)
        }
        tempClientMsgNos = []
      }
      tempClientMsgNos.push(saveList[i].clientMsgNo)
    }
    if (tempClientMsgNos.length > 0) {
      let tempList = this.queryWithClientMsgNos(tempClientMsgNos)
      if (tempList.length > 0) {
        existList.push(...tempList)
      }
      tempClientMsgNos = []
    }
    let realSaveList: WKMsg[] = []
    if (existList.length > 0) {
      for (let i = 0, size = saveList.length; i < size; i++) {
        let isSave = true
        for (let j = 0, len = existList.length; j < len; j++) {
          if (existList[j].clientMsgNo === saveList[i].clientMsgNo) {
            isSave = false
          }
        }
        if (isSave) {
          realSaveList.push(saveList[i])
        }
      }
    } else {
      realSaveList.push(...saveList)
    }

    if (realSaveList.length === 0) {
      return
    }
    let vbs: relationalStore.ValuesBucket[] = []
    for (let i = 0; i < realSaveList.length; i++) {
      let vb = this.getVB(realSaveList[i])
      vbs.push(vb)
    }
    const db = WKDBHelper.shared.getDB()
    if (!db) {
      return
    }
    try {
      db.beginTransaction()
      vbs.forEach((vb) => {
        db.insertSync(WKDBConst.tableMessage, vb,
          relationalStore.ConflictResolution.ON_CONFLICT_REPLACE)
      })
      db.commit()
    } catch (e) {
      WKLogger.error('批量插入消息错误 ', this.tag, ' inserts', e)
      WKDBHelper.shared.safeRollBack()
    }
  }

  insert(msg: WKMsg): number {
    if (msg.clientSeq !== 0) {
      return this.update(msg)
    }
    let tempMsg = this.queryWithClientMsgNo(msg.clientMsgNo)
    if (tempMsg !== undefined) {
      msg.clientMsgNo = WKIM.shared.messageManager().generateClientMsgNo()
      msg.isDeleted = 1
    }
    let cv = this.getVB(msg)
    try {
      let row = WKDBHelper.shared.getDB()?.insertSync(WKDBConst.tableMessage, cv)
      if (row !== undefined) {
        return row
      }
      return 0
    } catch (e) {
      WKLogger.error('插入消息错误：', this.tag, '：insert', e.message)
      return 0
    }
  }

  private update(msg: WKMsg): number {
    let cv = this.getVB(msg)
    try {
      let p = new relationalStore.RdbPredicates(WKDBConst.tableMessage)
      p.equalTo('client_seq', msg.clientSeq)
      let row = WKDBHelper.shared.getDB()?.updateSync(cv, p)
      if (row === undefined) {
        return 0
      }
      return row
    } catch (e) {
      WKLogger.error('修改消息错误', this.tag, 'update', e)
      return 0
    }
  }

  updateSendingToFail() {
    if (WKDBHelper.shared.getDB() === undefined) {
      return
    }
    let cv: relationalStore.ValuesBucket = {
      'status': 2
    }
    try {
      let p = new relationalStore.RdbPredicates(WKDBConst.tableMessage)
      p.equalTo('status', 0)
      WKDBHelper.shared.getDB()?.updateSync(cv, p)
    } catch (e) {
      WKLogger.error('标记发送中消息为失败错误', this.tag, 'updateSendingToFail', e)
    }
  }

  queryMaxMessageSeqNotDeletedWithChannel(channelId: string, channelType: number) {
    let sql =
      `SELECT max(message_seq) message_seq FROM ${WKDBConst.tableMessage} WHERE channel_id=? AND channel_type=? AND is_deleted=0`;
    let messageSeq = 0;
    let resultSet: relationalStore.ResultSet | undefined
    try {
      resultSet = WKDBHelper.shared.getDB()?.querySqlSync(sql, [channelId, channelType])
      if (resultSet?.goToNextRow()) {
        messageSeq = WKDBConst.getNumber(resultSet, 'message_seq')
      }
      return messageSeq
    } catch (e) {
      WKLogger.error(`查询最大序号错误，`, this.tag, 'queryMaxMessageSeqNotDeletedWithChannel', e.message)
      return messageSeq
    } finally {
      WKDBHelper.shared.safeClose(resultSet)
    }
  }

  queryMaxMessageOrderSeqWithChannel(channelId: string, channelType: number) {
    let sql = `SELECT max(order_seq) order_seq FROM ${WKDBConst.tableMessage} WHERE channel_id=? AND channel_type=?`
    let orderSeq = 0
    let resultSet: relationalStore.ResultSet | undefined
    try {
      resultSet = WKDBHelper.shared.getDB()?.querySqlSync(sql, [channelId, channelType])
      if (resultSet?.goToNextRow()) {
        orderSeq = WKDBConst.getNumber(resultSet, 'order_seq')
      }
      return orderSeq
    } catch (e) {
      WKLogger.error(`查询最大orderSeq错误，`, this.tag, 'queryMaxMessageOrderSeqWithChannel', e.message)
      return orderSeq
    } finally {
      WKDBHelper.shared.safeClose(resultSet)
    }
  }

  queryMaxMessageSeqWithChannel(channelId: string, channelType: number) {
    let sql = `SELECT max(message_seq) message_seq FROM ${WKDBConst.tableMessage} WHERE channel_id=? AND channel_type=?`
    let messageSeq = 0
    let resultSet: relationalStore.ResultSet | undefined
    try {
      resultSet = WKDBHelper.shared.getDB()?.querySqlSync(sql, [channelId, channelType])
      if (resultSet?.goToNextRow()) {
        messageSeq = WKDBConst.getNumber(resultSet, 'message_seq')
      }
      return messageSeq
    } catch (e) {
      WKLogger.error(`查询最大messageSeq错误，`, this.tag, ' queryMaxMessageSeqWithChannel', e.message)
      return messageSeq
    } finally {
      WKDBHelper.shared.safeClose(resultSet)
    }
  }

  queryOrderSeq(channelId: string, channelType: number, maxOrderSeq: number, limit: number) {
    let minOrderSeq = 0;
    let sql =
      `select order_seq from ${WKDBConst.tableMessage} where channel_id=? and channel_type=? and type<>99 and order_seq <=? order by order_seq desc limit ${limit}`

    let resultSet: relationalStore.ResultSet | undefined
    try {
      resultSet = WKDBHelper.shared.getDB()?.querySqlSync(sql, [channelId, channelType, maxOrderSeq])
      if (resultSet?.goToNextRow()) {
        minOrderSeq = WKDBConst.getNumber(resultSet, 'order_seq')
      }
      return minOrderSeq
    } catch (e) {
      WKLogger.error(`查询最大orderSeq错误，`, this.tag, 'queryOrderSeq', e.message)
      return minOrderSeq
    } finally {
      WKDBHelper.shared.safeClose(resultSet)
    }
  }

  queryMaxOrderSeqNotDeletedWithChannel(channelId: string, channelType: number) {
    let resultSet: relationalStore.ResultSet | undefined
    try {
      let sql =
        `select * from ${WKDBConst.tableMessage} where channel_id=? and channel_type=? and is_deleted=0 and type<>0 and type<>99 order by order_seq desc limit 1`
      resultSet = WKDBHelper.shared.getDB()?.querySqlSync(sql, [channelId, channelType])
      if (resultSet?.goToNextRow()) {
        let msg = this.serializeWKMsg(resultSet)
        return msg
      }
      return undefined
    } catch (e) {
      WKLogger.error(`查询报错,${this.tag}:queryMaxOrderSeqNotDeletedWithChannel`, e.message)
      return undefined
    } finally {
      WKDBHelper.shared.safeClose(resultSet)
    }

  }

  updateMsgFieldWithClientMsgNo(clientMsgNo: string, cv: relationalStore.ValuesBucket): boolean {
    try {
      let p = new relationalStore.RdbPredicates(WKDBConst.tableMessage)
      p.equalTo('client_msg_no', clientMsgNo)
      let row = WKDBHelper.shared.getDB()?.updateSync(cv, p)
      if (row !== undefined && row > 0) {
        return true
      }
      return false
    } catch (e) {
      WKLogger.error('修改消息字段错误', this.tag, 'updateMsgWithFieldAndClientMsgNo', JSON.stringify(cv), e.message)
      return false
    }
  }


  updateMsgSendStatus(sendAck: WKSendAckPacket) {
    let orderSeq = WKIM.shared.messageManager().getOrderSeq(sendAck.messageSeq)
    let cv: relationalStore.ValuesBucket = {
      'message_id': sendAck.messageId,
      "message_seq": sendAck.messageSeq,
      "status": sendAck.reasonCode,
      "order_seq": orderSeq
    }
    try {
      let p = new relationalStore.RdbPredicates(WKDBConst.tableMessage)
      p.equalTo('client_seq', sendAck.clientSeq)
      let row = WKDBHelper.shared.getDB()?.updateSync(cv, p)
      if (row !== undefined && row > 0) {
        return true
      }
      return false
    } catch (e) {
      WKLogger.error('修改发送消息回执错误', this.tag, 'updateWithSendAck', JSON.stringify(cv), e.message)
      return false
    }
  }


  serializeWKMsg(resultSet: relationalStore.ResultSet): WKMsg {
    let message = new WKMsg()
    message.messageId = WKDBConst.getString(resultSet, 'message_id')
    message.messageSeq = WKDBConst.getNumber(resultSet, 'message_seq')
    message.clientSeq = WKDBConst.getNumber(resultSet, 'client_seq')
    message.timestamp = WKDBConst.getNumber(resultSet, 'timestamp')
    message.fromUID = WKDBConst.getString(resultSet, 'from_uid')
    message.channelId = WKDBConst.getString(resultSet, 'channel_id')
    message.channelType = WKDBConst.getNumber(resultSet, 'channel_type')
    message.contentType = WKDBConst.getNumber(resultSet, 'type')
    message.content = WKDBConst.getString(resultSet, 'content')
    message.status = WKDBConst.getNumber(resultSet, 'status')
    message.voiceStatus = WKDBConst.getNumber(resultSet, 'voice_status')
    message.searchableWord = WKDBConst.getString(resultSet, 'searchable_word')
    message.clientMsgNo = WKDBConst.getString(resultSet, 'client_msg_no')
    message.isDeleted = WKDBConst.getNumber(resultSet, 'is_deleted')
    message.orderSeq = WKDBConst.getNumber(resultSet, 'order_seq')
    message.viewed = WKDBConst.getNumber(resultSet, 'viewed')
    message.viewedAt = WKDBConst.getNumber(resultSet, 'viewed_at')
    message.topicId = WKDBConst.getString(resultSet, 'topic_id')
    message.expireTime = WKDBConst.getNumber(resultSet, 'expire_time')
    message.expireTimestamp = WKDBConst.getNumber(resultSet, 'expire_timestamp')

    let setting = WKDBConst.getNumber(resultSet, 'setting')
    message.setting = new WKMsgSetting().decode(setting)

    let extra = WKDBConst.getString(resultSet, 'extra')
    if (extra !== '') {
      message.localExtraMap = CommonUtil.jsonToRecord(extra)
    }
    message.remoteExtra = this.serializeMsgExtra(resultSet)
    if (CommonUtil.strIsUnEmpty(message.content)) {
      message.messageContent = WKIM.shared.messageManager().getMessageModel(message.content)
    }
    return message
  }

  serializeMsgExtra(result: relationalStore.ResultSet): WKMsgExtra {

    let extra = new WKMsgExtra()
    extra.messageId = WKDBConst.getString(result, 'message_id')
    extra.channelId = WKDBConst.getString(result, 'channel_id')
    extra.channelType = WKDBConst.getNumber(result, 'channel_type')
    extra.readed = WKDBConst.getNumber(result, 'readed')
    extra.readedCount = WKDBConst.getNumber(result, 'readed_count')
    extra.unreadCount = WKDBConst.getNumber(result, 'unread_count')
    extra.revoke = WKDBConst.getNumber(result, 'revoke')
    extra.revoker = WKDBConst.getString(result, 'revoker')
    extra.isMutualDeleted = WKDBConst.getNumber(result, 'is_mutual_deleted')
    extra.extraVersion = WKDBConst.getNumber(result, 'extra_version')
    extra.editedAt = WKDBConst.getNumber(result, 'edited_at')
    extra.contentEdit = WKDBConst.getString(result, 'content_edit')
    extra.needUpload = WKDBConst.getNumber(result, 'need_upload')
    extra.isPinned = WKDBConst.getNumber(result, 'is_pinned')
    if (CommonUtil.strIsUnEmpty(extra.contentEdit)) {
      extra.contentEditMsgModel = WKIM.shared.messageManager().getMessageModel(extra.contentEdit)
    }
    return extra
  }

  private getVB(m: WKMsg) {
    let extra = ''
    if (m.localExtraMap !== undefined) {
      extra = JSON.stringify(m.localExtraMap)
    }
    const vb: relationalStore.ValuesBucket = {
      "message_id": m.messageId,
      "message_seq": m.messageSeq,
      "timestamp": m.timestamp,
      "from_uid": m.fromUID,
      "channel_id": m.channelId,
      "channel_type": m.channelType,
      "type": m.contentType,
      "content": m.content,
      "status": m.status,
      "voice_status": m.voiceStatus,
      "searchable_word": m.searchableWord,
      "client_msg_no": m.clientMsgNo,
      "is_deleted": m.isDeleted,
      "order_seq": m.orderSeq,
      "viewed": m.viewed,
      "viewed_at": m.viewedAt,
      "topic_id": m.topicId,
      "expire_time": m.expireTime,
      "expire_timestamp": m.expireTimestamp,
      "setting": m.setting.encode(),
      'extra': extra
    }
    return vb
  }

  getExtraVB(m: WKMsgExtra) {
    const vb: relationalStore.ValuesBucket = {
      'message_id': m.messageId,
      'channel_id': m.channelId,
      'channel_type': m.channelType,
      'readed': m.readed,
      'readed_count': m.readedCount,
      'unread_count': m.unreadCount,
      'revoke': m.revoke,
      'revoker': m.revoker,
      'is_mutual_deleted': m.isMutualDeleted,
      'extra_version': m.extraVersion,
      'edited_at': m.editedAt,
      'content_edit': m.contentEdit,
      'need_upload': m.needUpload,
      'is_pinned': m.isPinned,
    }
    return vb
  }
}