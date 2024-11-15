import { WKLogger } from '../common/WKLogger';
import { WKChannelType, WKCMD } from '../entity/Bean';
import { CommonUtil } from '../common/CommonUtil';
import { WKIM } from '../WKIM';
import { DateUtil } from '../common/DateUtil';
import { JSON } from '@kit.ArkTS';

export type CmdListener = (cmd: WKCMD) => void

export class CMDManager {
  static shared: CMDManager = new CMDManager();

  private constructor() {
    this.cmdListeners = new Array()
  }

  private cmdListeners: CmdListener[]

  handle(json: Record<string, Object>) {
    let channelId = CommonUtil.readString(json, 'channel_id')
    let channelType = CommonUtil.readNumber(json, 'channel_type')
    if (channelId !== undefined) {
      this.handleWithChannel(json, channelId.toString(), channelType.valueOf())
    } else {
      WKLogger.error(`解析cmd错误,cmd数据：${JSON.stringify(json)}`)
    }
  }

  async handleWithChannel(json: Record<string, Object>, channelId: string, channelType: number) {

    let key = CommonUtil.readString(json, 'cmd')
    if (key === undefined) {
      WKLogger.error(`处理cmd参数错误，cmd结构：${json}`)
      return
    }
    let param = CommonUtil.readJson(json, 'param')
    let paramJson: Record<string, Object> = {}
    if (param !== undefined) {
      paramJson = param as Record<string, Object>
      let tempChannelId = CommonUtil.readString(paramJson, 'channel_id')
      if (CommonUtil.strIsUnEmpty(channelId) && tempChannelId === undefined) {
        paramJson['channel_id'] = channelId
        paramJson['channel_type'] = channelType
      }
    }else {
      WKLogger.error('cmd的参数解析错误')
    }
    let cmd = new WKCMD(key.toString(), paramJson)
    switch (cmd.cmd) {
      case 'syncConversationExtra': {
        WKIM.shared.conversationManager().syncExtra()
        break
      }
      case 'channelUpdate': {
        let channelId = CommonUtil.readString(paramJson, 'channel_id')
        let channelType = CommonUtil.readNumber(paramJson, 'channel_type')
        if (channelId !== undefined) {
          WKIM.shared.channelManager().fetchChannelInfo(channelId, channelType)
        }
        break
      }
      case 'syncReminders': {
        WKIM.shared.reminderManager().sync()
        break
      }
      case 'memberUpdate': {
        let groupNo = CommonUtil.readString(paramJson, 'group_no')
        if (groupNo !== undefined) {
          WKIM.shared.channelMemberManager().sync(groupNo, WKChannelType.group)
        }
        break
      }
      case 'unreadClear': {
        let channelId = CommonUtil.readString(paramJson, 'channel_id')
        let channelType = CommonUtil.readNumber(paramJson, 'channel_type')
        let unread = CommonUtil.readNumber(paramJson, 'unread')
        if (channelId !== undefined) {
          WKIM.shared.conversationManager().updateRedDot(channelId, channelType, unread)
        }
        break
      }
      case 'onlineStatus': {
        let uid = CommonUtil.readString(paramJson, 'uid')
        let mainDeviceFlag = CommonUtil.readNumber(paramJson, 'main_device_flag')
        let allOffline = CommonUtil.readNumber(paramJson, 'all_offline')
        let online = allOffline == 1 ? 0 : 1
        if (uid !== undefined) {
          let channel = WKIM.shared.channelManager().getChannel(uid, WKChannelType.personal)
          if (channel !== undefined) {
            channel.online = online;
            if (channel.online == 0) {
              channel.lastOffline = DateUtil.getCurrentSeconds()
            }
            channel.deviceFlag = mainDeviceFlag
            WKIM.shared.channelManager().addOrUpdate(channel)
          }
        }
        break
      }
      case 'conversationDelete': {
        let channelId = CommonUtil.readString(paramJson, 'channel_id')
        let channelType = CommonUtil.readNumber(paramJson, 'channel_type')
        if (channelId !== undefined) {
          WKIM.shared.conversationManager().delete(channelId, channelType)
        }
        break
      }
      case 'userAvatarUpdate': {
        let uid = CommonUtil.readString(paramJson, 'uid')
        if (uid !== undefined) {
          WKIM.shared.channelManager().setAvatarUpdated(uid, WKChannelType.personal)
        }
        break
      }
      case 'groupAvatarUpdate': {
        let groupNo = CommonUtil.readString(paramJson, 'group_no')
        if (groupNo !== undefined) {
          WKIM.shared.channelManager().setAvatarUpdated(groupNo, WKChannelType.group)
        }
        break
      }
    }

    if (this.cmdListeners.length === 0) {
      WKLogger.error('未注册cmd事件')
      return
    }
    this.cmdListeners.forEach((back) => {
      back(cmd)
    })
  }

  addCmdListener(l: CmdListener) {
    this.cmdListeners.push(l)
  }

  removeCmdListener(l: CmdListener) {
    for (let i = 0; i < this.cmdListeners.length; i++) {
      if (this.cmdListeners[i] === l) {
        this.cmdListeners.splice(i, 1)
        break
      }
    }
  }
}