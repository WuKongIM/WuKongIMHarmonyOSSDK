import { Context } from '@kit.AbilityKit'
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
import { OrderMessageContent } from '../msg/OrderMsg'
import { CommonUtil } from '@ohos/wkim/src/main/ets/common/CommonUtil'
import { util } from '@kit.ArkTS'

export class IMUtil {
  static uid: string

  static async init(_uid: string, _token: string, context?: Context) {
    IMUtil.uid = _uid
    await WKIM.shared.init(_uid, _token, undefined, context)
    IMUtil.initListener()
    // 获取连接地址
    WKIM.shared.config.provider.connectAddrCallback = (): Promise<string> => {
      let add = HttpUtil.geConnAddress()
      return add
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
      async (channelId: string, channelType: number): Promise<WKChannel | undefined> => {
        HttpUtil.getChannelInfo(channelId, channelType)
        return undefined
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

  static initListener() {
    WKIM.shared.cmdManager().addCmdListener(cmd => {
      if (cmd?.cmd == 'messageRevoke') {
        // 消息被撤回 同步扩展
        let channelId = CommonUtil.readString(cmd.paramJsonObject!!, 'channel_id')
        let channelType = CommonUtil.readNumber(cmd.paramJsonObject!!, 'channel_type')
        WKLogger.error(`区同步消息扩展了${channelId}`)
        if (channelId !== undefined) {
          let version = WKIM.shared.messageManager().getMaxExtraVersion(channelId, channelType)
          HttpUtil.syncMsgExtra(channelId, channelType, version)
        }
      } else if (cmd?.cmd == 'channelUpdate') {
        // 频道(群/个人)资料修改
        // sdk已处理该命令
        // let channelId = CommonUtil.readString(cmd.paramJsonObject!!, 'channel_id')
        // let channelType = CommonUtil.readNumber(cmd.paramJsonObject!!, 'channel_type')
        // if (CommonUtil.strIsUnEmpty(channelId)) {
        //   HttpUtil.getChannelInfo(channelId, channelType)
        // }
      } else if (cmd?.cmd == 'unreadClear') {
        // 清空红点
        // sdk已处理该命令
        // let channelId = CommonUtil.readString(cmd.paramJsonObject!!, 'channel_id')
        // let channelType = CommonUtil.readNumber(cmd.paramJsonObject!!, 'channel_type')
        // let unread = CommonUtil.readNumber(cmd.paramJsonObject!!, 'unread')
        // if (CommonUtil.strIsUnEmpty(channelId)) {
        //   WKIM.shared.conversationManager().updateRedDot(channelId, channelType, unread)
        // }
      }
    })
  }
}

let syncConversationCallback = async (lastMsgSeqs: string, msgCount: number,
  version: number): Promise<WKSyncConversation> => {
  return await HttpUtil.syncConversation(lastMsgSeqs, msgCount, version)
}

let syncMessageCallback = async (channel: WKChannel, options: SyncOptions): Promise<WKSyncChannelMsg> => {
  WKLogger.error('开始走网络了')
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
  } else if (msg.contentType === 56) {
    let orderMsgContent = msg.messageContent as OrderMessageContent
    orderMsgContent.imgUrl =
      "https://img0.baidu.com/it/u=188409901,3824570996&fm=253&fmt=auto&app=120&f=JPEG?w=889&h=500"
    msg.messageContent = orderMsgContent
    return [true, msg]
  }
  return [true, msg]
}