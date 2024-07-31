import { WKLogger } from '../common/WKLogger';
import { WKChannel, WKChannelType, WKCMD } from '../entity/Bean';
import { CommonUtil } from '../common/CommonUtil';
import { WKIM } from '../WKIM';
import { DateUtil } from '../common/DateUtil';

export type CmdListener = (cmd: WKCMD) => void

export class CMDManager {
  static shared: CMDManager = new CMDManager();

  private constructor() {
    this.cmdListeners = new Array()
  }

  private cmdListeners: CmdListener[]

  handle(json: Record<string, Object>) {
    let channelId = json['channel_id']
    let channelType = json['channel_type']
    if (channelId instanceof String && channelType instanceof Number) {
      this.handleWithChannel(json, channelId.toString(), channelType.valueOf())
    } else {
      WKLogger.error(`解析cmd错误,cmd数据：${json}`)
    }
  }

  async handleWithChannel(json: Record<string, Object>, channelId: string, channelType: number) {
    if (this.cmdListeners.length === 0) {
      WKLogger.error('未注册cmd事件')
      return
    }
    let key = json['cmd']
    if (CommonUtil.strIsEmpty(key)) {
      WKLogger.error(`处理cmd参数错误，cmd结构：${json}`)
      return
    }
    let param = json['param']
    let paramJson: Record<string, Object> = {}
    if (param !== undefined && param !== null) {
      paramJson = param as Record<string, Object>
      let tempChannelId = paramJson['channel_id']
      if (CommonUtil.strIsUnEmpty(channelId) && CommonUtil.strIsEmpty(tempChannelId)) {
        paramJson['channel_id'] = channelId
        paramJson['channel_type'] = channelType
      }
    }
    let cmd = new WKCMD(key.toString(), paramJson)
    switch (cmd.cmd) {
      case 'syncMessageExtra': {
        let channelId = paramJson['channel_id'] as string
        let channelType = paramJson['channel_type'] as number
        WKIM.shared.messageManager().syncExtra(new WKChannel(channelId, channelType))
      }
      case 'syncConversationExtra': {
        WKIM.shared.conversationManager().syncExtra()
      }
      case 'channelUpdate': {
        let channelId = paramJson['channel_id'] as string
        let channelType = paramJson['channel_type'] as number
        WKIM.shared.channelManager().fetchChannelInfo(channelId, channelType)
      }
      case 'syncReminders': {
        WKIM.shared.reminderManager().sync()
      }
      case 'memberUpdate': {
        let groupNo = CommonUtil.readString(paramJson, 'group_no')
        if (groupNo !== '') {
          WKIM.shared.channelMemberManager().sync(groupNo, WKChannelType.group)
        }
      }
      case 'unreadClear': {
        let channelId = CommonUtil.readString(paramJson, 'channel_id')
        let channelType = CommonUtil.readNumber(paramJson, 'channel_type')
        let unread = CommonUtil.readNumber(paramJson, 'unread')
        if (channelId !== '') {
          WKIM.shared.conversationManager().updateRedDot(channelId, channelType, unread)
        }
      }
      case 'onlineStatus': {
        let uid = CommonUtil.readString(paramJson, 'uid')
        let mainDeviceFlag = CommonUtil.readNumber(paramJson, 'main_device_flag')
        let allOffline = CommonUtil.readNumber(paramJson, 'all_offline')
        let online = allOffline == 1 ? 0 : 1
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
      case 'conversationDelete': {
        let channelId = CommonUtil.readString(paramJson, 'channel_id')
        let channelType = CommonUtil.readNumber(paramJson, 'channel_type')
        if (channelId !== '') {
          WKIM.shared.conversationManager().delete(channelId, channelType)
        }
      }
      case 'userAvatarUpdate': {
        let uid = CommonUtil.readString(paramJson, 'uid')
        if (uid !== '') {
          WKIM.shared.channelManager().setAvatarUpdated(uid, WKChannelType.personal)
        }
      }
      case 'groupAvatarUpdate': {
        let groupNo = CommonUtil.readString(paramJson, 'group_no')
        if (groupNo !== '') {
          WKIM.shared.channelManager().setAvatarUpdated(groupNo, WKChannelType.group)
        }
      }
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