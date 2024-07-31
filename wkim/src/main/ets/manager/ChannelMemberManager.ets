import { WKLogger } from '../common/WKLogger';
import { ChannelMemberDB } from '../db/ChannelMemberDB';
import { SyncChannelMemberOptions, WKChannel, WKChannelMember } from '../entity/Bean';
import { WKIM } from '../WKIM';

export type RefreshListener = (member: WKChannelMember[]) => void

export type NewListener = (list: WKChannelMember[]) => void

export type DeletedListener = (list: WKChannelMember[]) => void

export class ChannelMemberManager {
  static shared: ChannelMemberManager = new ChannelMemberManager();

  private constructor() {
    this.refreshListeners = []
    this.deletedListeners = []
    this.newListeners = []
  }

  readonly tag = 'ChannelMemberManager'
  private refreshListeners: RefreshListener[]
  private deletedListeners: DeletedListener[]
  private newListeners: NewListener[]

  sync(channelId: string, channelType: number) {
    if (WKIM.shared.config.provider.channelMemberCallback === undefined) {
      WKLogger.error('未提供channelMemberCallback')
      return
    }
    let v = ChannelMemberDB.shared.queryMaxVersion(channelId,channelType)
    WKIM.shared.config.provider.channelMemberCallback(channelId, channelType,v)
      .then((list) => {
        this.addOrUpdates(list)
      })
  }

  getMember(channelId: string, channelType: number, memberUID: string): WKChannelMember | undefined {
    return ChannelMemberDB.shared.queryWithUID(channelId, channelType, memberUID)
  }

  getMembers(channelId: string, channelType: number): WKChannelMember[] {
    return ChannelMemberDB.shared.query(channelId, channelType)
  }

  getWithPageOrSearch(channelId: string, channelType: number,
    option: SyncChannelMemberOptions): Promise<WKChannelMember[] | undefined> {
    if (WKIM.shared.config.provider.channelMemberWithPageCallback !== undefined) {
      let data =
        WKIM.shared.config.provider.channelMemberWithPageCallback(new WKChannel(channelId, channelType), option)
      if (data !== undefined) {
        data.then((list) => {
          ChannelMemberDB.shared.inserts(list)
        })
      }
      return data
    } else {
      WKLogger.error('未提供channelMemberWithPageCallback')
    }
    let list = ChannelMemberDB.shared.queryWithPageOrSearch(channelId, channelType, option)
    return list
  }

  delete(channelId: string, channelType: number, memberUID: string): boolean {
    let b = ChannelMemberDB.shared.updateWithField('is_deleted', 1, channelId, channelType, memberUID)
    if (b) {
      let m = this.getMember(channelId, channelType, memberUID)
      if (m !== undefined) {
        this.setDeleted([m])
      }
    }
    return b
  }

  addOrUpdate(m: WKChannelMember) {
    this.addOrUpdates([m])
  }

  addOrUpdates(list: WKChannelMember[]) {
    if (list.length === 0) {
      return
    }
    let channelId = list[0].channelId
    let channelType = list[0].channelType
    let tempUIDs: string[] = []
    let existMembers: WKChannelMember[] = []
    list.forEach((m) => {
      if (tempUIDs.length === 200) {
        let ms = ChannelMemberDB.shared.queryWithUIDs(channelId, channelType, tempUIDs)
        if (ms.length > 0) {
          existMembers.push(...ms)
        }
        tempUIDs = []
      }
      tempUIDs.push(m.memberUID)
    })
    if (tempUIDs.length > 0) {
      let ms = ChannelMemberDB.shared.queryWithUIDs(channelId, channelType, tempUIDs)
      if (ms.length > 0) {
        existMembers.push(...ms)
      }
      tempUIDs = []
    }
    let newMembers: WKChannelMember[] = []
    let deletedMembers: WKChannelMember[] = []
    let updateMembers: WKChannelMember[] = []

    list.forEach((m) => {
      let isNewMember = true
      if (existMembers.length > 0) {
        existMembers.forEach((m1) => {
          if (m1.memberUID === m.memberUID) {
            isNewMember = false
            if (m.isDeleted == 1) {
              deletedMembers.push(m)
            } else {
              if (m1.isDeleted == 1) {
                isNewMember = true
              } else {
                updateMembers.push(m)
              }
            }
          }
        })
      }
      if (isNewMember) {
        newMembers.push(m)
      }
    })

    ChannelMemberDB.shared.inserts(list)
    if (newMembers.length > 0) {
      this.setNew(newMembers)
    }
    if (updateMembers.length > 0) {
      this.setRefresh(updateMembers)
    }
    if (deletedMembers.length > 0) {
      this.setDeleted(deletedMembers)
    }
  }


  private setRefresh(list: WKChannelMember[]) {
    this.refreshListeners.forEach((iRefresh) => {
      iRefresh(list)
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

  private setNew(list: WKChannelMember[]) {
    this.newListeners.forEach((iRefresh) => {
      iRefresh(list)
    })
  }

  addNewListener(iRefresh: RefreshListener) {
    this.newListeners.push(iRefresh)
  }

  removeNewListener(iRefresh: RefreshListener) {
    for (let i = 0; i < this.newListeners.length; i++) {
      if (this.newListeners[i] === iRefresh) {
        this.newListeners.splice(i, 1)
        break
      }
    }
  }

  private setDeleted(list: WKChannelMember[]) {
    this.deletedListeners.forEach((iRefresh) => {
      iRefresh(list)
    })
  }

  addDeletedListener(iRefresh: RefreshListener) {
    this.deletedListeners.push(iRefresh)
  }

  removeDeletedListener(iRefresh: RefreshListener) {
    for (let i = 0; i < this.deletedListeners.length; i++) {
      if (this.deletedListeners[i] === iRefresh) {
        this.deletedListeners.splice(i, 1)
        break
      }
    }
  }
}