import { relationalStore } from '@kit.ArkData';
import { StringBuilder } from '../common/StringBuilder';
import { WKLogger } from '../common/WKLogger';

export class WKDBConst {
  static readonly tableMessage = 'message';
  static readonly tableMessageReaction = 'message_reaction';
  static readonly tableMessageExtra = 'message_extra';
  static readonly tableConversation = 'conversation';
  static readonly tableConversationExtra = 'conversation_extra';
  static readonly tableChannel = 'channel';
  static readonly tableChannelMember = 'channel_members';
  static readonly tableReminders = 'reminders';
  static readonly tableRobot = 'robot';
  static readonly tableRobotMenu = 'robot_menu';

  static getString(resultSet: relationalStore.ResultSet, key: string): string {
    try {
      let index = resultSet.getColumnIndex(key)
      if (index >= 0) {
        return resultSet.getString(index)
      }
    } catch (e) {
      return ''
    }
    return ''
  }

  static getNumber(resultSet: relationalStore.ResultSet, key: string): number {
    try {
      let index = resultSet.getColumnIndex(key)
      if (index >= 0) {
        return resultSet.getLong(index)
      }
    } catch (e) {
      return 0
    }
    return 0
  }


  static getPlaceholders(count: number): string {
    let sb = new StringBuilder()
    for (let i = 0; i < count; i++) {
      if (i != 0) {
        sb.append(", ")
      }
      sb.append("?")
    }
    return sb.toString()
  }
}
