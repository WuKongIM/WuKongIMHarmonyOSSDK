import { WKDBConst } from './WKDBConst';
import { relationalStore } from '@kit.ArkData';
import { WKLogger } from '../common/WKLogger';
import { WKDBHelper } from './WKDBHelper';
import { WKReminder } from '../entity/Bean';
import { CommonUtil } from '../common/CommonUtil';
import { JSON } from '@kit.ArkTS';

export class ReminderDB {
  static shared: ReminderDB = new ReminderDB();

  private constructor() {
  }

  readonly tag = 'ReminderDB'

  queryMaxVersion(): number {
    let version = 0
    let sql = `select * from ${WKDBConst.tableReminders} order by version desc limit 1`
    let resultSet: relationalStore.ResultSet | undefined
    try {
      resultSet = WKDBHelper.shared.getDB()?.querySqlSync(sql)
      if (resultSet?.goToNextRow()) {
        version = WKDBConst.getNumber(resultSet, 'version')
      }
      return version
    } catch (e) {
      WKLogger.error('查询提醒项最大编号错误,', this.tag, 'queryMaxVersion', e)
      return version
    } finally {
      WKDBHelper.shared.safeClose(resultSet)
    }
  }

  queryWithChannelAndDone(channelId: string, channelType: number, done: number): WKReminder[] {
    let sql =
      `select * from ${WKDBConst.tableReminders} where channel_id=? and channel_type=? and done=? order by message_seq desc`
    let resultSet: relationalStore.ResultSet | undefined
    let list: WKReminder[] = []
    try {
      resultSet = WKDBHelper.shared.getDB()?.querySqlSync(sql, [channelId, channelType, done])
      while (resultSet?.goToNextRow()) {
        let r = this.serializeReminder(resultSet)
        list.push(r)
      }
      return list
    } catch (e) {
      WKLogger.error('查询channel提醒项错误', this.tag, ':queryWithChannel', e.message)
      return list
    } finally {
      WKDBHelper.shared.safeClose(resultSet)
    }
  }

  insertOrReplaces(list: WKReminder[]) {
    let vbs: relationalStore.ValuesBucket[] = []
    for (let i = 0; i < list.length; i++) {
      let vb = this.getVB(list[i])
      vbs.push(vb)
    }
    const db = WKDBHelper.shared.getDB()
    if (!db) {
      return
    }
    try {
      db.beginTransaction()
      for (let i = 0; i < vbs.length; i++) {
        db.insertSync(WKDBConst.tableReminders, vbs[i],
          relationalStore.ConflictResolution.ON_CONFLICT_REPLACE)
      }
      db.commit()
    } catch (e) {
      WKLogger.error('批量插入提醒项错误', this.tag, 'insertOrReplaces', e)
      WKDBHelper.shared.safeRollBack()
    }
  }

  queryWithChannelIds(channelIds: string[]): WKReminder[] {
    let sql =
      `select * from ${WKDBConst.tableReminders} where channel_id in (${WKDBConst.getPlaceholders(channelIds.length)})`
    let resultSet: relationalStore.ResultSet | undefined
    let list: WKReminder[] = []
    try {
      resultSet = WKDBHelper.shared.getDB()?.querySqlSync(sql, channelIds)
      while (resultSet?.goToNextRow()) {
        let r = this.serializeReminder(resultSet)
        list.push(r)
      }
      return list
    } catch (e) {
      WKLogger.error('批量查询提醒项错误', this.tag, 'queryWithChannelIds', e)
      return list
    } finally {
      WKDBHelper.shared.safeClose(resultSet)
    }
  }

  queryWithReminderIds(reminderIds: string[]): WKReminder[] {
    let sql =
      `select * from ${WKDBConst.tableReminders} where reminder_id in (${WKDBConst.getPlaceholders(reminderIds.length)})`
    let resultSet: relationalStore.ResultSet | undefined
    let list: WKReminder[] = []
    try {
      resultSet = WKDBHelper.shared.getDB()?.querySqlSync(sql, reminderIds)
      while (resultSet?.goToNextRow()) {
        let r = this.serializeReminder(resultSet)
        list.push(r)
      }
      return list
    } catch (e) {
      WKLogger.error('批量查询提醒项错误', this.tag, 'queryWithReminderIds', e)
      return list
    } finally {
      WKDBHelper.shared.safeClose(resultSet)
    }
  }


  private getVB(r: WKReminder) {
    let data = ''
    if (r.data !== undefined) {
      data = JSON.stringify(r.data)
    }
    let vb: relationalStore.ValuesBucket = {
      'type': r.type,
      'reminder_id': r.reminderId,
      'message_id': r.messageId,
      'message_seq': r.messageSeq,
      'is_locate': r.isLocate,
      'channel_id': r.channelId,
      'channel_type': r.channelType,
      'text': r.text,
      'version': r.version,
      'done': r.done,
      'need_upload': r.needUpload,
      'publisher': r.publisher,
      'data': data
    }
    return vb
  }

  private serializeReminder(r:
    relationalStore.ResultSet
  ) {
    let reminder = new WKReminder()
    reminder.type = WKDBConst.getNumber(r, 'type')
    reminder.reminderId = WKDBConst.getNumber(r, 'reminder_id')
    reminder.messageId = WKDBConst.getString(r, 'message_id')
    reminder.messageSeq = WKDBConst.getNumber(r, 'message_seq')
    reminder.isLocate = WKDBConst.getNumber(r, 'is_locate')
    reminder.channelId = WKDBConst.getString(r, 'channel_id')
    reminder.channelType = WKDBConst.getNumber(r, 'channel_type')
    reminder.text = WKDBConst.getString(r, 'text')
    reminder.version = WKDBConst.getNumber(r, 'version')
    reminder.done = WKDBConst.getNumber(r, 'done')
    reminder.needUpload = WKDBConst.getNumber(r, 'need_upload')
    reminder.publisher = WKDBConst.getString(r, 'publisher')
    let data = WKDBConst.getString(r, 'data')
    if (CommonUtil.strIsUnEmpty(data)) {
      reminder.data = CommonUtil.jsonToRecord(data)
    }
    return reminder
  }
}