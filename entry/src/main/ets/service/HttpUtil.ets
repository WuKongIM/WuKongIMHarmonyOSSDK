import { http } from '@kit.NetworkKit';
import { JSON, util } from '@kit.ArkTS';
import { IMUtil } from './IMUtil';
import { CommonUtil } from '@ohos/wkim/src/main/ets/common/CommonUtil';
import {
  WKMsg,
  WKMsgSetting,
  WKSendMsgResult,
  WKSyncChannelMsg,
  WKSyncConversation,
  WKSyncConvMsg
} from '@ohos/wkim/src/main/ets/entity/Bean';
import { WKLogger } from '@ohos/wkim/src/main/ets/common/WKLogger';

let requestURL: string = ''

export class HttpUtil {
  constructor() {
  }

  static login(url: string, uid: string, token: string, back: (code: number) => void) {
    requestURL = url
    let httpRequest = http.createHttp()
    httpRequest.request(requestURL + "/user/token", {
      method: http.RequestMethod.POST,
      extraData: {
        "uid": uid,
        "token": token,
        'device_flag': 0,
        'device_level': 1
      }
    }, (err, data) => {
      if (err != null) {
        back(err.code)
        console.error(`请求错误，code:${err.code},message:${err.message}`)
        return
      }
      if (data.responseCode != 200) {
        console.error(`请求失败,data:${data.result}`)
      }
      back(data.responseCode)
    })
  }

  static async getIP(): Promise<string> {
    let httpRequest = http.createHttp()
    let data = await httpRequest.request(requestURL + "/route", {
      method: http.RequestMethod.GET
    })
    if (data.responseCode == 200) {
      let maps = JSON.parse(data.result.toString()) as Map<string, Object>
      return maps['tcp_addr']
    } else {
      return ''
    }
  }

  static async syncConversation(lastMsgSeqs: string, msgCount: number,
    version: number): Promise<WKSyncConversation> {
    console.error(`同步参数`, version, lastMsgSeqs, msgCount)
    let httpRequest = http.createHttp()
    let response = await httpRequest.request(requestURL + '/conversation/sync', {
      method: http.RequestMethod.POST,
      extraData: {
        'uid': IMUtil.uid, // 当前登录用户uid
        'version': version, //  当前客户端的会话最大版本号(从保存的结果里取最大的version，如果本地没有数据则传0)，
        'last_msg_seqs': lastMsgSeqs, //   客户端所有频道会话的最后一条消息序列号拼接出来的同步串 格式： channelID:channelType:last_msg_seq|channelID:channelType:last_msg_seq  （此字段非必填，如果不填就获取全量数据，填写了获取增量数据，看你自己的需求。）
        'msg_count': msgCount // 每个会话获取最大的消息数量，一般为app点进去第一屏的数据
      }
    })
    let conv = new WKSyncConversation()
    if (response.responseCode !== 200) {
      console.log(`同步最近会话错误,code:${response.responseCode}`)
      return conv
    }

    let arr = CommonUtil.jsonToRecordArray(response.result.toString())
    if (arr === undefined) {
      return conv
    }
    conv.uid = IMUtil.uid
    conv.conversations = []
    for (let i = 0; i < arr.length; i++) {
      const json = arr[i]
      let convMsg = new WKSyncConvMsg()
      convMsg.channelId = CommonUtil.readString(json, 'channel_id')
      convMsg.channelType = CommonUtil.readNumber(json, 'channel_type')
      convMsg.unread = CommonUtil.readNumber(json, 'unread')
      convMsg.timestamp = CommonUtil.readNumber(json, 'timestamp')
      convMsg.lastMsgSeq = CommonUtil.readNumber(json, 'last_msg_seq')
      convMsg.lastClientMsgNo = CommonUtil.readString(json, 'last_client_msg_no')
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
    WKLogger.error(`同步channel消息：startSeq:`, startMsgSeq + "", "endSeq:",
      endMsgSeq + ",limit:" + limit + ",pullMode:" + pullMode)
    let httpRequest = http.createHttp()
    let response = await httpRequest.request(requestURL + '/channel/messagesync', {
      method: http.RequestMethod.POST,
      extraData: {
        'login_uid': IMUtil.uid, // 当前登录用户uid
        'channel_id': channelID,
        'channel_type': channelType,
        'start_message_seq': startMsgSeq, // 开始消息列号（结果包含start_message_seq的消息）
        'end_message_seq': endMsgSeq, // 结束消息列号（结果不包含end_message_seq的消息）
        'limit': limit, // 消息数量限制
        'pull_mode': pullMode // 拉取模式 0:向下拉取 1:向上拉取
      }
    })
    let syncMsg = new WKSyncChannelMsg()

    if (response.responseCode !== 200) {
      console.log(`同步channel消息错误，code:${response.responseCode}}`)
      return syncMsg
    }
    let json = CommonUtil.jsonToRecord(response.result.toString())
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
      const msgJson = arr[i]
      list.push(HttpUtil.jsonToWKMsg(msgJson))
    }
    WKLogger.error(`同步数量：${list.length}`)
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
    msg.messageId = CommonUtil.readString(json, 'message_idstr')
    msg.channelId = CommonUtil.readString(json, 'channel_id')
    msg.channelType = CommonUtil.readNumber(json, 'channel_type')
    msg.clientMsgNo = CommonUtil.readString(json, 'client_msg_no')
    msg.messageSeq = CommonUtil.readNumber(json, 'message_seq')
    msg.fromUID = CommonUtil.readString(json, 'from_uid')
    msg.timestamp = CommonUtil.readNumber(json, 'timestamp')
    let payload = CommonUtil.readString(json, 'payload')
    if (payload !== '') {
      msg.content = CommonUtil.uint8ArrayToString(new util.Base64Helper().decodeSync(payload))
    }
    //  WKLogger.error(`同步消息数据${msg.toString()}`)
    return msg
  }
}