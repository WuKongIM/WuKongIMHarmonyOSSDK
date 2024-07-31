import { relationalStore } from '@kit.ArkData';
import { WKLogger } from '../common/WKLogger';
import { WKMsgReaction } from '../entity/Bean';
import { WKDBConst } from './WKDBConst';
import { WKDBHelper } from './WKDBHelper';

export class ReactionDB {
  static shared: ReactionDB = new ReactionDB();

  private constructor() {
  }

  readonly tag = 'ReactionDB'

  queryMaxSeqWithChannel(channelId: string, channelType: number) {
    let v = 0
    let sql =
      `select max(seq) seq from ${WKDBConst.tableMessageReaction} where channel_id=? and channel_type=? limit 0, 1`
    let resultSet: relationalStore.ResultSet | undefined
    try {
      resultSet = WKDBHelper.shared.getDB()?.querySqlSync(sql, [channelId, channelType])
      if (resultSet?.goToNextRow()) {
        v = WKDBConst.getNumber(resultSet, 'seq')
      }
      return v
    } catch (e) {
      WKLogger.error('查询频道最大回应seq错误', this.tag, 'queryMaxSeqWithChannel', e)
      return v
    } finally {
      resultSet?.close()
    }
  }

  queryWithMsgIds(msgIds: string[]) {
    let resultSet: relationalStore.ResultSet | undefined
    let list: WKMsgReaction[] = []
    try {
      let sql =
        `select * from ${WKDBConst.tableMessageReaction} where message_id in (${WKDBConst.getPlaceholders(msgIds.length)}) and is_deleted=0 ORDER BY created_at desc`
      resultSet = WKDBHelper.shared.getDB()?.querySqlSync(sql, msgIds)
      while (resultSet?.goToNextRow()) {
        let r = this.serializeReaction(resultSet)
        list.push(r)
      }
      return list
    } catch (e) {
      WKLogger.error('查询错误', this.tag, '：queryWithMsgIds，', e.message)
      return list
    } finally {
      resultSet?.close()
    }
  }

  queryWithMsgId(msgId: string): WKMsgReaction[] {
    let resultSet: relationalStore.ResultSet | undefined
    let list: WKMsgReaction[] = []
    try {
      let sql =
        `select * from ${WKDBConst.tableMessageReaction} where message_id=? and is_deleted=0 ORDER BY created_at desc`
      resultSet = WKDBHelper.shared.getDB()?.querySqlSync(sql, [msgId])
      while (resultSet?.goToNextRow()) {
        let r = this.serializeReaction(resultSet)
        list.push(r)
      }
      return list
    } catch (e) {
      WKLogger.error('查询错误', this.tag, 'queryWithMsgId', e)
      return list
    } finally {
      resultSet?.close()
    }
  }

  inserts(list: WKMsgReaction[]) {
    let vbs: relationalStore.ValuesBucket[] = []
    list.forEach((r) => {
      let vb = this.getVB(r)
      vbs.push(vb)
    })
    try {
      WKDBHelper.shared.getDB()?.beginTransaction()
      vbs.forEach((vb) => {
        WKDBHelper.shared.getDB()?.insertSync(WKDBConst.tableMessageReaction, vb,
          relationalStore.ConflictResolution.ON_CONFLICT_REPLACE)
      })
    } catch (e) {
      WKLogger.error('批量插入回应错误', this.tag, 'inserts', e)
    } finally {
      WKDBHelper.shared.getDB()?.commit()
    }
  }

  private serializeReaction(rs: relationalStore.ResultSet): WKMsgReaction {
    let r = new WKMsgReaction()
    r.messageId = WKDBConst.getString(rs, 'message_id')
    r.channelId = WKDBConst.getString(rs, 'channel_id')
    r.channelType = WKDBConst.getNumber(rs, 'channel_type')
    r.uid = WKDBConst.getString(rs, 'uid')
    r.name = WKDBConst.getString(rs, 'name')
    r.createdAt = WKDBConst.getString(rs, 'created_at')
    r.seq = WKDBConst.getNumber(rs, 'seq')
    r.isDeleted = WKDBConst.getNumber(rs, 'is_deleted')
    r.emoji = WKDBConst.getString(rs, 'emoji')
    return r
  }

  private getVB(r: WKMsgReaction) {
    let vb: relationalStore.ValuesBucket = {
      'message_id': r.messageId,
      'channel_id': r.channelId,
      'channel_type': r.channelType,
      'uid': r.uid,
      'name': r.name,
      'created_at': r.createdAt,
      'seq': r.seq,
      'is_deleted': r.isDeleted,
      'emoji': r.emoji
    }
    return vb
  }
}