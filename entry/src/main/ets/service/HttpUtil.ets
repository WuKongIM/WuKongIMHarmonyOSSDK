import { JSON } from '@kit.ArkTS';
import { IMUtil } from './IMUtil';
import { rcp } from "@kit.RemoteCommunicationKit";

import { CommonUtil } from '@ohos/wkim/src/main/ets/common/CommonUtil';
import {
  WKChannel,
  WKChannelType,
  WKMsg,
  WKMsgExtra,
  WKMsgSetting,
  WKSendMsgResult,
  WKSyncChannelMsg,
  WKSyncConversation,
  WKSyncConvMsg
} from '@ohos/wkim/src/main/ets/entity/Bean';
import { WKLogger } from '@ohos/wkim/src/main/ets/common/WKLogger';
import { WKIM } from '@ohos/wkim';
import { BusinessError } from '@kit.BasicServicesKit';

let requestURL: string = ''

let session: rcp.Session | undefined = undefined

export class HttpUtil {
  constructor() {
  }

  private static getSession(): rcp.Session {
    if (session === undefined) {
      session = rcp.createSession({
        requestConfiguration: {
          security: {
            remoteValidation: 'skip'
          }
        }
      });
    }
    return session
  }

  static getURL(): string {
    return requestURL
  }

  static setURL(url: string): void {
    requestURL = url
  }

  static login(url: string, uid: string, token: string, back: (code: number) => void) {
    requestURL = url
    let session = HttpUtil.getSession()
    session.post(requestURL + "/user/login", {
      "uid": uid,
      "token": token,
      'device_flag': 0,
      'device_level': 1
    }).then((response) => {
      back(response.statusCode)
      if (response.statusCode !== 200) {
        console.error(`请求错误，code:${response.statusCode},message:${response.toString()}`)
      }
    }).catch((err: BusinessError) => {
      console.error(`请求异常，code:${err.code},message:${err.message}`)
    });
  }

  static async geConnAddress(): Promise<string> {
    let session = HttpUtil.getSession()
    let response = await session.get(`${requestURL}/users/${IMUtil.uid}/route`)
    if (response.statusCode === 200) {
      let maps = JSON.parse(response.toString()) as Map<string, Object>
      return maps['tcp_addr']
    }
    return ''
  }

  static async syncConversation(lastMsgSeqs: string, msgCount: number,
    version: number): Promise<WKSyncConversation> {
    console.error(`同步参数`, version, lastMsgSeqs, msgCount)
    let session = HttpUtil.getSession()
    let response = await session.post(`${requestURL}/conversation/sync`, {
      'login_uid': IMUtil.uid, // 当前登录用户uid
      'version': version, //  当前客户端的会话最大版本号(从保存的结果里取最大的version，如果本地没有数据则传0)，
      'last_msg_seqs': lastMsgSeqs, //   客户端所有频道会话的最后一条消息序列号拼接出来的同步串 格式： channelID:channelType:last_msg_seq|channelID:channelType:last_msg_seq  （此字段非必填，如果不填就获取全量数据，填写了获取增量数据，看你自己的需求。）
      'msg_count': msgCount, // 每个会话获取最大的消息数量，一般为app点进去第一屏的数据
      'device_uuid': IMUtil.uid,
    })
    let conv = new WKSyncConversation()
    if (response.statusCode !== 200) {
      console.log(`同步最近会话错误,code:${response.statusCode}`)
      return conv
    }
    let dataJson = CommonUtil.jsonToRecord(response.toString()!!)
    if (dataJson === undefined) {
      return conv
    }
    let arr = CommonUtil.readArr(dataJson, 'conversations')
    if (arr === undefined) {
      return conv
    }
    conv.uid = IMUtil.uid
    conv.conversations = []
    for (let i = 0; i < arr.length; i++) {
      const json = arr[i]
      let convMsg = new WKSyncConvMsg()
      convMsg.channelId = CommonUtil.readString(json, 'channel_id') ?? ''
      convMsg.channelType = CommonUtil.readNumber(json, 'channel_type')
      convMsg.unread = CommonUtil.readNumber(json, 'unread')
      convMsg.timestamp = CommonUtil.readNumber(json, 'timestamp')
      convMsg.lastMsgSeq = CommonUtil.readNumber(json, 'last_msg_seq')
      convMsg.lastClientMsgNo = CommonUtil.readString(json, 'last_client_msg_no') ?? ''
      convMsg.version = CommonUtil.readNumber(json, 'version')
      let msgArr = CommonUtil.readArr(json, 'recents')
      if (msgArr !== undefined) {
        convMsg.recents = []
        for (let i = 0; i < msgArr.length; i++) {
          let msgJson = msgArr[i]
          let msg = HttpUtil.jsonToWKMsg(msgJson)
          convMsg.recents.push(msg)
        }
      }
      conv.conversations.push(convMsg)
    }
    console.log(`同步的最近会话数据`, conv.conversations?.length)
    return conv
  }

  static async syncChannelMsg(channelID: string,
    channelType: number,
    startMsgSeq: number,
    endMsgSeq: number,
    limit: number,
    pullMode: number): Promise<WKSyncChannelMsg> {
    let request = HttpUtil.getSession()
    WKLogger.error('网络开始了')
    let response = await request.post(`${requestURL}/message/channel/sync`, {
      'login_uid': IMUtil.uid, // 当前登录用户uid
      'channel_id': channelID,
      'channel_type': channelType,
      'start_message_seq': startMsgSeq, // 开始消息列号（结果包含start_message_seq的消息）
      'end_message_seq': endMsgSeq, // 结束消息列号（结果不包含end_message_seq的消息）
      'limit': limit, // 消息数量限制
      'pull_mode': pullMode // 拉取模式 0:向下拉取 1:向上拉取
    })
    let syncMsg = new WKSyncChannelMsg()
    WKLogger.error(response.toString()!!)
    if (response.statusCode !== 200) {
      console.log(`同步channel消息错误，code:${response.statusCode}}`)
      return syncMsg
    }
    let json = CommonUtil.jsonToRecord(response.toString()!!)
    if (json === undefined) {
      return syncMsg
    }
    syncMsg.more = CommonUtil.readNumber(json, 'more')
    syncMsg.startMessageSeq = CommonUtil.readNumber(json, 'start_message_seq')
    syncMsg.endMessageSeq = CommonUtil.readNumber(json, 'end_message_seq')
    let arr = CommonUtil.readArr(json, 'messages')
    if (arr === undefined) {
      return syncMsg
    }
    let list: WKMsg[] = []
    for (let i = 0; i < arr.length; i++) {
      let msgJson = arr[i]
      list.push(HttpUtil.jsonToWKMsg(msgJson))
    }
    syncMsg.msgs = list
    return syncMsg
  }

  static jsonToWKMsg(json: Record<string, Object>) {
    let msg = new WKMsg()
    let headerJson = CommonUtil.readJson(json, 'header')
    if (headerJson !== undefined) {
      msg.header.noPersist = CommonUtil.readNumber(headerJson, 'no_persist') > 0
      msg.header.redDot = CommonUtil.readNumber(headerJson, 'red_dot') > 0
      msg.header.syncOnce = CommonUtil.readNumber(headerJson, 'sync_once') > 0
    }
    let setting = CommonUtil.readNumber(json, 'setting')
    msg.setting = new WKMsgSetting().decode(setting)
    msg.status = WKSendMsgResult.success
    msg.messageId = CommonUtil.readString(json, 'message_idstr') ?? ''
    msg.channelId = CommonUtil.readString(json, 'channel_id') ?? ''
    msg.channelType = CommonUtil.readNumber(json, 'channel_type')
    msg.clientMsgNo = CommonUtil.readString(json, 'client_msg_no') ?? ''
    msg.messageSeq = CommonUtil.readNumber(json, 'message_seq')
    msg.fromUID = CommonUtil.readString(json, 'from_uid') ?? ''
    msg.timestamp = CommonUtil.readNumber(json, 'timestamp')
    msg.isDeleted = CommonUtil.readNumber(json, 'is_deleted')
    let payload = CommonUtil.readJson(json, 'payload')
    if (payload !== undefined) {
      let content = JSON.stringify(payload)
      msg.content = content
    }
    // if (payload !== '') {
    //   msg.content = CommonUtil.uint8ArrayToString(new util.Base64Helper().decodeSync(payload))
    // }

    //  WKLogger.error(`同步消息数据${msg.toString()}`)
    let extraJson = CommonUtil.readJson(json, 'message_extra')
    if (extraJson !== undefined) {
      msg.remoteExtra = HttpUtil.getExtra(extraJson)
    }
    return msg
  }

  private static getExtra(extraJson: Record<string, Object>): WKMsgExtra {
    let extra = new WKMsgExtra()
    extra.messageId = CommonUtil.readString(extraJson, 'message_id_str') ?? ''
    extra.revoke = CommonUtil.readNumber(extraJson, 'revoke')
    extra.revoker = CommonUtil.readString(extraJson, 'revoker') ?? ''
    extra.readed = CommonUtil.readNumber(extraJson, 'readed')
    extra.readedCount = CommonUtil.readNumber(extraJson, 'readed_count')
    extra.isMutualDeleted = CommonUtil.readNumber(extraJson, 'is_mutual_deleted')
    return extra
  }

  static async getChannelInfo(channelId: string, channelType: number) {
    let url = `${requestURL}/groups/${channelId}`
    if (channelType == WKChannelType.personal) {
      url = `${requestURL}/users/${channelId}`
    }
    let response = await HttpUtil.getSession().get(url)

    if (response.statusCode !== 200) {
      console.log(`获取频道资料错误，code:${response.statusCode}}`)
      return
    }
    let json = CommonUtil.jsonToRecord(response.toString()!!)
    if (json === undefined) {
      return
    }

    let channel = new WKChannel(channelId, channelType)
    channel.channelName = CommonUtil.readString(json, 'name') ?? ''
    channel.avatar = CommonUtil.readString(json, 'avatar') ?? ''
    WKIM.shared.channelManager().addOrUpdate(channel)
  }

  static async deleteMsg(channelId: string, channelType: number, clientMsgNo: string, messageSeq: number,
    messageId: string) {
    let response = await HttpUtil.getSession().post(`${requestURL}/message/delete`, {
      'login_uid': IMUtil.uid,
      'channel_id': channelId,
      'channel_type': channelType,
      'message_id': messageId,
      'message_seq': messageSeq,
    })
    console.log(`删除消息结果，code:${response.statusCode}}`)
    if (response.statusCode === 200) {
      WKIM.shared.messageManager().deleteWithClientMsgNo(clientMsgNo)
    }
  }

  static async revokeMsg(channelId: string, channelType: number, clientMsgNo: string, messageSeq: number,
    messageId: string) {
    HttpUtil.getSession().delete(`${requestURL}/message/revoke`)
    let response = await HttpUtil.getSession().post(`${requestURL}/message/revoke`, {
      'login_uid': IMUtil.uid,
      'channel_id': channelId,
      'channel_type': channelType,
      'message_id': messageId,
      'message_seq': messageSeq,
      'client_msg_no': clientMsgNo,
    })
    console.log(`撤回消息结果，code:${response.statusCode}}`)
  }

  static async syncMsgExtra(channelId: string, channelType: number, version: number) {
    let response = await HttpUtil.getSession().post(`${requestURL}/message/extra/sync`, {
      'login_uid': IMUtil.uid,
      'channel_id': channelId,
      'channel_type': channelType,
      'extra_version': version,
      'limit': 100,
      'source': IMUtil.uid,
    })
    console.log(`同步消息扩展，code:${response.statusCode}}`)
    if (response.statusCode !== 200) {
      return
    }

    let arr = CommonUtil.jsonToRecordArray(response.toString()!!)
    if (arr === undefined) {
      return
    }
    let list: WKMsgExtra[] = []
    for (let i = 0; i < arr.length; i++) {
      let json = arr[i]
      let extra = HttpUtil.getExtra(json)
      list.push(extra)
    }
    WKIM.shared.messageManager().saveRemoteExtras(list)
  }

  static async clearChannelMsg(channelId: string, channelType: number) {
    let messageSeq = WKIM.shared.messageManager().getMaxMessageSeqWithChannel(channelId, channelType)
    let response = await HttpUtil.getSession().post(`${requestURL}/message/offset`, {
      'login_uid': IMUtil.uid,
      'channel_id': channelId,
      'channel_type': channelType,
      'message_seq': messageSeq,
    })
    console.log(`清空频道聊天记录，code:${response.statusCode}}`)
    if (response.statusCode === 200) {
      WKIM.shared.messageManager().clearWithChannel(channelId, channelType)
    }
  }

  static async updateGroupName(groupNo: string, name: string) {
    let response = await HttpUtil.getSession().put(`${requestURL}/groups/${groupNo}`, {
      'login_uid': IMUtil.uid,
      'name': name,
    })
    console.log(`修改群名称，code:${response.statusCode}}`)
  }
}