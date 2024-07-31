import { WKLogger } from '../common/WKLogger';
import { ReminderDB } from '../db/ReminderDB';
import { WKReminder } from '../entity/Bean';
import { WKIM } from '../WKIM';

export type NewReminder = (list: WKReminder[]) => void

export class ReminderManager {
  static shared: ReminderManager = new ReminderManager();

  private constructor() {
    this.newReminders = []
  }

  private newReminders: NewReminder[]

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
      this.setNewReminders(list)
    }
  }

  addNewReminderListener(l: NewReminder) {
    this.newReminders.push(l)
  }

  removeNewReminderListener(l: NewReminder) {
    for (let i = 0; i < this.newReminders.length; i++) {
      if (this.newReminders[i] === l) {
        this.newReminders.splice(i, 1)
        break
      }
    }
  }

  private setNewReminders(list: WKReminder[]) {
    this.newReminders.forEach((b) => {
      b(list)
    })
  }
}