import { WKChannel } from '../entity/Bean';
import { relationalStore } from '@kit.ArkData';
import { WKDBHelper } from './WKDBHelper';
import { WKDBConst } from './WKDBConst';
import { WKLogger } from '../common/WKLogger';
import { CommonUtil } from '../common/CommonUtil';

export class ChannelDB {
  static shared: ChannelDB = new ChannelDB();

  private constructor() {
  }

  readonly tag = 'ChannelDB'

  query(channelId: string, channelType: number): WKChannel | undefined {
    let resultSet: relationalStore.ResultSet | undefined
    let channel: WKChannel | undefined
    try {
      let p = new relationalStore.RdbPredicates(WKDBConst.tableChannel)
      p.equalTo('channel_id', channelId).and().equalTo('channel_type', channelType)
      resultSet = WKDBHelper.shared.getDB()?.querySync(p)
      if (resultSet?.goToNextRow()) {
        channel = this.serializeChannel(resultSet)
      }
      return channel
    } catch (e) {
      WKLogger.error('查询错误', this.tag, 'query', e)
      return channel
    } finally {
      resultSet?.close()
    }
  }

  inserts(list: WKChannel[]) {
    let vbs: relationalStore.ValuesBucket[] = []
    list.forEach((c) => {
      let vb = this.getVB(c)
      vbs.push(vb)
    })
    try {
      WKDBHelper.shared.getDB()?.beginTransaction()
      vbs.forEach((vb) => {
        WKDBHelper.shared.getDB()?.insertSync(WKDBConst.tableChannel, vb,
          relationalStore.ConflictResolution.ON_CONFLICT_REPLACE)
      })
    } catch (e) {
      WKLogger.error('批量插入channel错误', this.tag, 'inserts', e)
    } finally {
      WKDBHelper.shared.getDB()?.commit()
    }
  }

  insertOrUpdate(channel: WKChannel): boolean {
    let vb = this.getVB(channel)
    try {
      let row = WKDBHelper.shared.getDB()?.insertSync(WKDBConst.tableChannel, vb,
        relationalStore.ConflictResolution.ON_CONFLICT_REPLACE)
      if (row === undefined) {
        return false
      }
      return row > 0
    } catch (e) {
      WKLogger.error('新增或修改channel错误', this.tag, 'insertOrUpdate', e)
      return false
    }
  }

  queryWithChannelIds(channelIds: string[]): WKChannel[] {
    let resultSet: relationalStore.ResultSet | undefined
    let channels: WKChannel[] = []
    try {
      let sql =
        `select * from ${WKDBConst.tableChannel} where channel_id in(${WKDBConst.getPlaceholders(channelIds.length)})`
      resultSet = WKDBHelper.shared.getDB()?.querySqlSync(sql, channelIds)
      while (resultSet?.goToNextRow()) {
        channels.push(this.serializeChannel(resultSet))
      }
      return channels
    } catch (e) {
      WKLogger.error(`查询错误,${this.tag}:queryWithChannelIds`)
      return channels
    } finally {
      resultSet?.close()
    }
  }

  searchWithChannelTypeAndFollow(searchKey: string, channelType: number, follow: number) {
    let key = `%${searchKey}%`
    let sql =
      `select * from ${WKDBConst.tableChannel} where (channel_name like ? or channel_remark like ? ) and channel_type=? and follow=?`
    let resultSet: relationalStore.ResultSet | undefined
    let channels: WKChannel[] = []
    try {
      resultSet = WKDBHelper.shared.getDB()?.querySqlSync(sql, [key, key, channelType, follow])
      while (resultSet?.goToNextRow()) {
        channels.push(this.serializeChannel(resultSet))
      }
      return channels
    } catch (e) {
      WKLogger.error(`查询错误,${this.tag}:searchWithChannelTypeAndFollow`, e)
      return channels
    } finally {
      resultSet?.close()
    }
  }

  serializeChannel(r: relationalStore.ResultSet): WKChannel {
    let channel = new WKChannel('', 0)
    channel.channelId = WKDBConst.getString(r, 'channel_id')
    channel.channelType = WKDBConst.getNumber(r, 'channel_type')
    channel.channelName = WKDBConst.getString(r, 'channel_name')
    channel.channelRemark = WKDBConst.getString(r, 'channel_remark')
    channel.avatar = WKDBConst.getString(r, 'avatar')
    channel.top = WKDBConst.getNumber(r, 'top')
    channel.save = WKDBConst.getNumber(r, 'save')
    channel.mute = WKDBConst.getNumber(r, 'mute')
    channel.forbidden = WKDBConst.getNumber(r, 'forbidden')
    channel.invite = WKDBConst.getNumber(r, 'invite')
    channel.status = WKDBConst.getNumber(r, 'status')
    channel.isDeleted = WKDBConst.getNumber(r, 'is_deleted')
    channel.follow = WKDBConst.getNumber(r, 'follow')
    channel.version = WKDBConst.getNumber(r, 'version')
    channel.showNick = WKDBConst.getNumber(r, 'show_nick')
    channel.createdAt = WKDBConst.getString(r, 'created_at')
    channel.updatedAt = WKDBConst.getString(r, 'updated_at')
    channel.online = WKDBConst.getNumber(r, 'online')
    channel.lastOffline = WKDBConst.getNumber(r, 'last_offline')
    channel.receipt = WKDBConst.getNumber(r, 'receipt')
    channel.robot = WKDBConst.getNumber(r, 'robot')
    channel.category = WKDBConst.getString(r, 'category')
    channel.username = WKDBConst.getString(r, 'username')
    channel.avatarCacheKey = WKDBConst.getString(r, 'avatar_cache_key')
    channel.deviceFlag = WKDBConst.getNumber(r, 'device_flag')
    channel.parentChannelId = WKDBConst.getString(r, 'parent_channel_id')
    channel.parentChannelType = WKDBConst.getNumber(r, 'parent_channel_type')
    let remoteExtra = WKDBConst.getString(r, 'remote_extra')
    if (CommonUtil.strIsUnEmpty(remoteExtra)) {
      channel.remoteExtra = CommonUtil.jsonToRecord(remoteExtra)
    }
    let extra = WKDBConst.getString(r, 'extra')
    if (CommonUtil.strIsUnEmpty(extra)) {
      channel.localExtra = CommonUtil.jsonToRecord(extra)
    }
    let cExtra = WKDBConst.getString(r, 'channel_extra')
    if (CommonUtil.strIsUnEmpty(cExtra)) {
      channel.localExtra = CommonUtil.jsonToRecord(cExtra)
    }
    let cRemoteExtra = WKDBConst.getString(r, 'channel_remote_extra')
    if (CommonUtil.strIsUnEmpty(cRemoteExtra)) {
      channel.remoteExtra = CommonUtil.jsonToRecord(cRemoteExtra)
    }
    let cParentChannelId = WKDBConst.getString(r, 'c_parent_channel_id')
    if (CommonUtil.strIsUnEmpty(cParentChannelId)) {
      channel.parentChannelId = cParentChannelId
    }
    let cParentChannelType = WKDBConst.getNumber(r, 'c_parent_channel_type')
    if (cParentChannelType !== 0) {
      channel.parentChannelType = cParentChannelType
    }
    let cVersion = WKDBConst.getNumber(r, 'channel_version')
    if (cVersion !== 0) {
      channel.version = cVersion
    }
    return channel
  }

  getVB(c: WKChannel) {
    let remoteExtra = ''
    let localExtra = ''
    if (c.remoteExtra !== undefined) {
      remoteExtra = JSON.stringify(c.remoteExtra)
    }
    if (c.localExtra !== undefined) {
      localExtra = JSON.stringify(c.localExtra)
    }
    const vb: relationalStore.ValuesBucket = {
      'channel_id': c.channelId,
      'channel_type': c.channelType,
      'channel_name': c.channelName,
      'channel_remark': c.channelRemark,
      'avatar': c.avatar,
      'top': c.top,
      'save': c.save,
      'mute': c.mute,
      'forbidden': c.forbidden,
      'invite': c.invite,
      'status': c.status,
      'is_deleted': c.isDeleted,
      'follow': c.follow,
      'version': c.version,
      'show_nick': c.showNick,
      'created_at': c.createdAt,
      'updated_at': c.updatedAt,
      'online': c.online,
      'last_offline': c.lastOffline,
      'receipt': c.receipt,
      'robot': c.robot,
      'category': c.category,
      'username': c.username,
      'avatar_cache_key': c.avatarCacheKey,
      'device_flag': c.deviceFlag,
      'parent_channel_id': c.parentChannelId,
      'parent_channel_type': c.parentChannelType,
      'remote_extra': remoteExtra,
      'extra': localExtra,
    }
    return vb
  }
}