import HashMap from '@ohos.util.HashMap';
import { WKLogger } from '../common/WKLogger';
import { ChannelDB } from '../db/ChannelDB';
import { WKChannel } from '../entity/Bean';
import { WKIM } from '../WKIM';

export type RefreshListener = (channel: WKChannel) => void

export type AvatarUpdatedListener = (channelId: string, channelType: number) => void

export class ChannelManager {
  static shared: ChannelManager = new ChannelManager();

  private constructor() {
    this.cacheMap = new HashMap()
    this.refreshListeners = []
    this.avatarUpdatedListeners = []
  }

  private cacheMap: HashMap<string, WKChannel>
  private refreshListeners: RefreshListener[]
  private avatarUpdatedListeners: AvatarUpdatedListener[]

  public getChannel(channelId: string, channelType: number): WKChannel | undefined {
    let key = this.getCacheKey(channelId, channelType)
    if (this.cacheMap.hasKey(key)) {
      return this.cacheMap.get(key)
    }
    let channel = ChannelDB.shared.query(channelId, channelType)
    if (channel !== undefined) {
      this.cacheMap.set(key, channel)
    }
    return channel
  }

  updateName(channelId: string, channelType: number, channelName: string) {
    let channel = this.getChannel(channelId, channelType)
    if (channel !== undefined) {
      channel.channelName = channelName
      this.addOrUpdate(channel)
    }
  }

  updateRemark(channelId: string, channelType: number, channelRemark: string) {
    let channel = this.getChannel(channelId, channelType)
    if (channel !== undefined) {
      channel.channelRemark = channelRemark
      this.addOrUpdate(channel)
    }
  }

  updateLocalExtra(channelId: string, channelType: number, extra: Record<string, Object> | undefined) {
    let channel = this.getChannel(channelId, channelType)
    if (channel !== undefined) {
      channel.localExtra = extra
      this.addOrUpdate(channel)
    }
  }

  updateAvatarCacheKey(channelId: string, channelType: number, key: string) {
    let channel = this.getChannel(channelId, channelType)
    if (channel !== undefined) {
      channel.avatarCacheKey = key
      this.addOrUpdate(channel)
    }
  }

  fetchChannelInfo(channelId: string, channelType: number) {
    if (WKIM.shared.config.provider.channelInfoCallback === undefined) {
      WKLogger.debug('未注册.channelInfoCallback')
      return
    }
    WKIM.shared.config.provider.channelInfoCallback(channelId, channelType)
      .then((channel: WKChannel) => {
        this.addOrUpdate(channel)
      })
  }

  addOrUpdate(channel: WKChannel) {
    this.update(channel);
    this.setRefresh(channel);
    ChannelDB.shared.insertOrUpdate(channel)
  }

  private update(channel: WKChannel) {
    let isAdd = true;
    this.cacheMap.forEach((tempChannel: WKChannel, _) => {
      if (tempChannel.channelId == channel.channelId && tempChannel.channelType == channel.channelType) {
        isAdd = false
        tempChannel.forbidden = channel.forbidden;
        tempChannel.channelName = channel.channelName;
        tempChannel.avatar = channel.avatar;
        tempChannel.category = channel.category;
        tempChannel.lastOffline = channel.lastOffline;
        tempChannel.online = channel.online;
        tempChannel.follow = channel.follow;
        tempChannel.top = channel.top;
        tempChannel.channelRemark = channel.channelRemark;
        tempChannel.status = channel.status;
        tempChannel.version = channel.version;
        tempChannel.invite = channel.invite;
        tempChannel.localExtra = channel.localExtra;
        tempChannel.mute = channel.mute;
        tempChannel.save = channel.save;
        tempChannel.showNick = channel.showNick;
        tempChannel.isDeleted = channel.isDeleted;
        tempChannel.receipt = channel.receipt;
        tempChannel.robot = channel.robot;
        tempChannel.deviceFlag = channel.deviceFlag;
        tempChannel.parentChannelId = channel.parentChannelId;
        tempChannel.parentChannelType = channel.parentChannelType;
        tempChannel.avatarCacheKey = channel.avatarCacheKey;
        tempChannel.remoteExtra = channel.remoteExtra;
      }
    })
    if (isAdd) {
      this.cacheMap.set(this.getCacheKey(channel.channelId, channel.channelType), channel)
    }
  }

  private setRefresh(channel: WKChannel) {
    this.refreshListeners.forEach((iRefresh) => {
      iRefresh(channel)
    })
  }

  addRefreshListener(iRefresh: RefreshListener) {
    this.refreshListeners.push(iRefresh)
  }

  removeRefreshListener(iRefresh: RefreshListener) {
    for (let i = 0; i < this.refreshListeners.length; i++) {
      if (this.refreshListeners[i] === iRefresh) {
        this.refreshListeners.splice(i, 1)
        break
      }
    }
  }

  addAvatarUpdatedListener(l: AvatarUpdatedListener) {
    this.avatarUpdatedListeners.push(l)
  }

  removeAvatarUpdatedListener(l: AvatarUpdatedListener) {
    for (let i = 0; i < this.avatarUpdatedListeners.length; i++) {
      if (this.avatarUpdatedListeners[i] === l) {
        this.avatarUpdatedListeners.splice(i, 1)
        break
      }
    }
  }

  setAvatarUpdated(channelId: string, channelType: number) {
    this.avatarUpdatedListeners.forEach((b)=>{
      b(channelId,channelType)
    })
  }

  private getCacheKey(channelId: string, channelType: number): string {
    return `${channelId}_${channelType}`
  }
}