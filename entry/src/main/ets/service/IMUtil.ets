import { WKIM } from '@ohos/wkim'
import { WKLogger } from '@ohos/wkim/src/main/ets/common/WKLogger'
import {
  SyncChannelMemberOptions,
  SyncOptions,
  WKChannel,
  WKChannelMember,
  WKChannelType,
  WKConversationExtra,
  WKMsg,
  WKMsgContentType,
  WKMsgExtra,
  WKReminder,
  WKSyncChannelMsg,
  WKSyncConversation
} from '@ohos/wkim/src/main/ets/entity/Bean'
import { WKImageContent } from '@ohos/wkim/src/main/ets/model/WKImageContent'
import { WKVoiceContent } from '@ohos/wkim/src/main/ets/model/WKVoiceContent'
import { WKVideoContent } from '@ohos/wkim/src/main/ets/model/WKVideoContent'
import { HttpUtil } from './HttpUtil'
import { LocationMessageContent } from '../msg/CustomerMsg'

export class IMUtil {
  static uid: string

  static async init(_uid: string, _token: string) {
    IMUtil.uid = _uid
    await WKIM.shared.init(_uid, _token)
    // 获取连接地址
    WKIM.shared.config.provider.connectAddrCallback = (): Promise<string> => {
      let add = HttpUtil.getIP()
      return add
    }
    // 消息扩展
    WKIM.shared.config.provider.syncMessageExtraCallback = async (channel: WKChannel, extraVersion: number,
      limit: number): Promise<WKMsgExtra[]> => {
      let list: WKMsgExtra[] = []
      return list
    }
    // 频道成员
    WKIM.shared.config.provider.channelMemberCallback = async (channelId: string, channelType: number,
      maxVersion: number): Promise<WKChannelMember[]> => {
      let list: WKChannelMember[] = []
      return list
    }
    // 频道成员分页数据
    WKIM.shared.config.provider.channelMemberWithPageCallback = async (channel: WKChannel,
      option: SyncChannelMemberOptions): Promise<WKChannelMember[]> => {
      let list: WKChannelMember[] = []
      return list
    }
    // 获取频道资料
    WKIM.shared.config.provider.channelInfoCallback =
      async (channelId: string, channelType: number): Promise<WKChannel> => {
        // 测试数据，实际可通过接口返回
        WKLogger.error('获取channel资料', channelId, channelType + "")
        let channel = new WKChannel(channelId, channelType)
        if (channel.channelType === WKChannelType.personal) {
          channel.channelName = `单聊${channelId}`
          channel.channelRemark = `备注${channel.channelName}`
        } else if (channel.channelType === WKChannelType.group) {
          channel.channelName = `群${channelId}`
        }

        channel.avatar = `https://api.multiavatar.com/${channel.channelId}.png`
        return channel
      }
    WKIM.shared.config.provider.syncReminderCallback = async (version: number): Promise<WKReminder[]> => {
      let list: WKReminder[] = []
      return list
    }
    WKIM.shared.config.provider.syncConversationExtraCallback =
      async (version: number): Promise<WKConversationExtra[]> => {
        let list: WKConversationExtra[] = []
        return list
      }
    WKIM.shared.config.provider.uploadMessageExtraCallback = (extra: WKMsgExtra) => {
      //上传到业务服务器
    }
    // 同步最近会话
    WKIM.shared.config.provider.syncConversationCallback = syncConversationCallback
    // 同步channel消息
    WKIM.shared.config.provider.syncMessageCallback = syncMessageCallback
    // 上传附件
    WKIM.shared.config.provider.uploadAttachmentCallback = uploadAttachmentCallback
    // 连接
    WKIM.shared.connectionManager().connection()

  }
}

let syncConversationCallback = async (lastMsgSeqs: string, msgCount: number,
  version: number): Promise<WKSyncConversation> => {
  WKLogger.error('同步最近会话')
  return await HttpUtil.syncConversation(lastMsgSeqs, msgCount, version)
}

let syncMessageCallback = async (channel: WKChannel, options: SyncOptions): Promise<WKSyncChannelMsg> => {
  return await HttpUtil.syncChannelMsg(channel.channelId, channel.channelType, options.startMessageSeq,
    options.endMessageSeq, options.limit, options.pullMode)
}

let uploadAttachmentCallback = async (msg: WKMsg): Promise<[boolean, WKMsg]> => {
  if (msg.contentType === WKMsgContentType.Image) {
    // 上传图片
    let imageContent = msg.messageContent as WKImageContent
    imageContent.url = 'xxxx'
    msg.messageContent = imageContent
    return [true, msg]
  } else if (msg.contentType === WKMsgContentType.Voice) {
    // 上传语音
    let voiceContent = msg.messageContent as WKVoiceContent
    voiceContent.url = 'xxxx'
    msg.messageContent = voiceContent
    return [true, msg]
  } else if (msg.contentType === WKMsgContentType.Video) {
    // 上传视频
    let videoContent = msg.messageContent as WKVideoContent
    videoContent.url = 'xxxx'
    msg.messageContent = videoContent
    return [true, msg]
  } else if (msg.contentType === 17) {
    // 上传自定义附件消息
    let customerMsg = msg.messageContent as LocationMessageContent
    customerMsg.url = 'https://img1.baidu.com/it/u=3362698628,1928330748&fm=253&fmt=auto&app=138&f=JPEG?w=390&h=308'
    msg.messageContent = customerMsg
    return [true, msg]
  }
  return [true, msg]
}