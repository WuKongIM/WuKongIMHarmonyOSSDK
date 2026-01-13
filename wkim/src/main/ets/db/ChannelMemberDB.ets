import { relationalStore } from '@kit.ArkData';
import { CommonUtil } from '../common/CommonUtil';
import { WKLogger } from '../common/WKLogger';
import { SyncChannelMemberOptions, WKChannelMember } from '../entity/Bean';
import { WKDBConst } from './WKDBConst';
import { WKDBHelper } from './WKDBHelper';

export class ChannelMemberDB {
  static shared: ChannelMemberDB = new ChannelMemberDB();

  private constructor() {
  }

  readonly tag = 'ChannelMemberDB'
  readonly channelCols =
    `${WKDBConst.tableChannel}.channel_remark,${WKDBConst.tableChannel}.channel_name,${WKDBConst.tableChannel}.avatar,${WKDBConst.tableChannel}.avatar_cache_key`

  inserts(list: WKChannelMember[]) {
    let vbs: relationalStore.ValuesBucket[] = []
    list.forEach((m) => {
      let vb = this.getVB(m)
      vbs.push(vb)
    })
    const db = WKDBHelper.shared.getDB()
    if (!db) {
      return
    }
    try {
      db.beginTransaction()
      vbs.forEach((vb) => {
        db.insertSync(WKDBConst.tableChannelMember, vb,
          relationalStore.ConflictResolution.ON_CONFLICT_REPLACE)
      })
      db.commit()
    } catch (e) {
      WKLogger.error('批量插入错误', this.tag, 'inserts', e)
      WKDBHelper.shared.safeRollBack()
    }
  }

  queryMaxVersion(channelId: string, channelType: number): number {
    let v = 0
    let resultSet: relationalStore.ResultSet | undefined
    let sql =
      `select max(version) version from ${WKDBConst.tableChannelMember} where channel_id =? and channel_type=? limit 0, 1`
    try {
      resultSet = WKDBHelper.shared.getDB()?.querySqlSync(sql, [channelId, channelType])
      if (resultSet?.goToNextRow()) {
        v = WKDBConst.getNumber(resultSet, 'version')
      }
      return v
    } catch (e) {
      WKLogger.error('查询成员最大版本号错误,', this.tag, 'queryMaxVersion', e)
      return v
    } finally {
      WKDBHelper.shared.safeClose(resultSet)
    }
  }

  queryWithUID(channelId: string, channelType: number, uid: string): WKChannelMember | undefined {
    let resultSet: relationalStore.ResultSet | undefined
    let member: WKChannelMember | undefined
    try {
      let sql = `select * from ${WKDBConst.tableChannelMember} where channel_id=? and channel_type=? and member_uid=?`
      resultSet = WKDBHelper.shared.getDB()?.querySqlSync(sql, [channelId, channelType, uid])
      while (resultSet?.goToNextRow()) {
        member = this.serializeMember(resultSet)
      }
      return member
    } catch (e) {
      WKLogger.error('查询错误,', this.tag, 'queryWithUID')
      return member
    } finally {
      WKDBHelper.shared.safeClose(resultSet)
    }
  }

  query(channelId: string, channelType: number) {
    let resultSet: relationalStore.ResultSet | undefined
    let members: WKChannelMember[] = []
    try {
      let sql =
        `select * from ${WKDBConst.tableChannelMember} where channel_id=? and channel_type=? and is_deleted=0`
      resultSet = WKDBHelper.shared.getDB()?.querySqlSync(sql, [channelId, channelType])
      while (resultSet?.goToNextRow()) {
        members.push(this.serializeMember(resultSet))
      }
      return members
    } catch (e) {
      WKLogger.error(`查询错误,${this.tag}:query`)
      return members
    } finally {
      WKDBHelper.shared.safeClose(resultSet)
    }
  }

  queryWithUIDs(channelId: string, channelType: number, memberUIDs: string[]) {
    let resultSet: relationalStore.ResultSet | undefined
    let members: WKChannelMember[] = []
    try {
      let sql =
        `select * from ${WKDBConst.tableChannelMember} where channel_id=? and channel_type=? and member_uid in (${WKDBConst.getPlaceholders(memberUIDs.length)})`
      resultSet = WKDBHelper.shared.getDB()?.querySqlSync(sql, [channelId, channelType, ...memberUIDs])
      while (resultSet?.goToNextRow()) {
        members.push(this.serializeMember(resultSet))
      }
      return members
    } catch (e) {
      WKLogger.error(`查询错误,${this.tag}:queryWithUIDs`)
      return members
    } finally {
      WKDBHelper.shared.safeClose(resultSet)
    }
  }

  async queryWithPageOrSearch(channelId: string, channelType: number,
    option: SyncChannelMemberOptions): Promise<WKChannelMember[]> {
    let resultSet: relationalStore.ResultSet | undefined
    let members: WKChannelMember[] = []
    let key = `%${option.searchKey}%`
    let sql =
      `select ${WKDBConst.tableChannelMember}.*,${this.channelCols} from ${WKDBConst.tableChannelMember} LEFT JOIN ${WKDBConst.tableChannel} on ${WKDBConst.tableChannelMember}.member_uid=${WKDBConst.tableChannel}.channel_id and ${WKDBConst.tableChannel}.channel_type=1 where ${WKDBConst.tableChannelMember}.channel_id=? and  ${WKDBConst.tableChannelMember}.channel_type=? and ${WKDBConst.tableChannelMember}.is_deleted=0 and ${WKDBConst.tableChannelMember}.status=1 and (member_name like ? or member_remark like ? or channel_name like ? or channel_remark like ?) order by ${WKDBConst.tableChannel}.role=1 desc,${WKDBConst.tableChannel}.role=2 desc,${WKDBConst.tableChannel}.created_at asc limit ${option.page},${option.limit}`
    try {
      resultSet = await WKDBHelper.shared.getDB()?.querySql(sql, [channelId, channelType, key, key, key, key])
      while (resultSet?.goToNextRow()) {
        members.push(this.serializeMember(resultSet))
      }
      return members
    } catch (e) {
      WKLogger.error(`分页查询错误,${this.tag}:queryWithUIDs`)
      return members
    } finally {
      WKDBHelper.shared.safeClose(resultSet)
    }
  }

  updateWithField(fieldName: string, v: relationalStore.ValueType, channelId: string, channelType: number,
    uid: string): boolean {
    let vb: relationalStore.ValuesBucket = {}
    vb[fieldName] = v
    try {
      let p = new relationalStore.RdbPredicates(WKDBConst.tableChannelMember)
      p.equalTo('channel_id', channelId)
        .and()
        .equalTo('channel_type', channelType)
        .and()
        .equalTo('member_uid', uid)
      let row = WKDBHelper.shared.getDB()?.updateSync(vb, p)
      if (row === undefined) {
        return false
      }
      return true
    } catch (e) {
      WKLogger.error('修改channel member错误', this.tag, 'updateWithField', e)
      return false
    }
  }

  private serializeMember(r: relationalStore.ResultSet) {
    let member = new WKChannelMember()
    member.channelId = WKDBConst.getString(r, 'channel_id')
    member.channelType = WKDBConst.getNumber(r, 'channel_type')
    member.memberInviteUID = WKDBConst.getString(r, 'member_invite_uid')
    member.memberUID = WKDBConst.getString(r, 'member_uid')
    member.memberName = WKDBConst.getString(r, 'member_name')
    member.memberRemark = WKDBConst.getString(r, 'member_remark')
    member.memberAvatar = WKDBConst.getString(r, 'member_avatar')
    member.memberAvatarCacheKey = WKDBConst.getString(r, 'member_avatar_cache_key')
    member.role = WKDBConst.getNumber(r, 'role')
    member.isDeleted = WKDBConst.getNumber(r, 'is_deleted')
    member.version = WKDBConst.getNumber(r, 'version')
    member.status = WKDBConst.getNumber(r, 'status')
    member.robot = WKDBConst.getNumber(r, 'robot')
    member.forbiddenExpirationTime = WKDBConst.getNumber(r, 'forbidden_expiration_time')
    member.createdAt = WKDBConst.getString(r, 'created_at')
    member.updatedAt = WKDBConst.getString(r, 'updated_at')
    let extra = WKDBConst.getString(r, 'extra')
    if (CommonUtil.strIsUnEmpty(extra)) {
      member.extra = CommonUtil.jsonToRecord(extra)
    }
    return member
  }

  private getVB(m: WKChannelMember) {
    let extra = ''
    if (m.extra !== undefined) {
      extra = JSON.stringify(m.extra)
    }
    const vb: relationalStore.ValuesBucket = {
      'channel_id': m.channelId,
      'channel_type': m.channelType,
      'status': m.status,
      'member_invite_uid': m.memberInviteUID,
      'member_uid': m.memberUID,
      'member_name': m.memberName,
      'member_avatar': m.memberAvatar,
      'member_remark': m.memberRemark,
      'role': m.role,
      'is_deleted': m.isDeleted,
      'created_at': m.createdAt,
      'updated_at': m.updatedAt,
      'version': m.version,
      'robot': m.robot,
      'forbidden_expiration_time': m.forbiddenExpirationTime,
      'member_avatar_cache_key': m.memberAvatarCacheKey,
      'extra': extra,
    }
    return vb
  }
}