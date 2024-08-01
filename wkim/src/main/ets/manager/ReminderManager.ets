import { WKLogger } from '../common/WKLogger';
import { ReminderDB } from '../db/ReminderDB';
import { WKReminder } from '../entity/Bean';
import { WKIM } from '../WKIM';

export type RefreshListener = (list: WKReminder[]) => void

export class ReminderManager {
  static shared: ReminderManager = new ReminderManager();

  private constructor() {
    this.refreshListeners = []
  }

  private refreshListeners: RefreshListener[]

  get(channelId: string, channelType: number, done: number): WKReminder[] {
    return ReminderDB.shared.queryWithChannelAndDone(channelId, channelType, done)
  }

  sync() {
    if (WKIM.shared.config.provider.syncReminderCallback === undefined) {
      WKLogger.error('未提供syncReminderCallback')
      return
    }
    let version = this.getMaxVersion()
    WKIM.shared.config.provider.syncReminderCallback(version)
      .then((list) => {
        this.save(list)
      })
  }

  getMaxVersion(): number {
    return ReminderDB.shared.queryMaxVersion()
  }

  save(list: WKReminder[]) {
    if (list.length > 0) {
      ReminderDB.shared.insertOrReplaces(list)
      this.refresh(list)
    }
  }

  addRefreshListener(l: RefreshListener) {
    this.refreshListeners.push(l)
  }

  removeRefreshListener(l: RefreshListener) {
    for (let i = 0; i < this.refreshListeners.length; i++) {
      if (this.refreshListeners[i] === l) {
        this.refreshListeners.splice(i, 1)
        break
      }
    }
  }

  private refresh(list: WKReminder[]) {
    this.refreshListeners.forEach((b) => {
      b(list)
    })
  }
}