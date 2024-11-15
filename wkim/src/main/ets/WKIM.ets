import { CryptoUtils } from './common/CryptoUtils';
import { WKLogger } from './common/WKLogger';
import { WKDBHelper } from './db/WKDBHelper';
import { WKConfig } from './entity/WKConfig';
import { ChannelManager } from './manager/ChannelManager';
import { ChannelMemberManager } from './manager/ChannelMemberManager';
import { CMDManager } from './manager/CMDManager';
import { ConnectionManager } from './manager/ConnectionManager';
import { ConversationManager } from './manager/ConversationManager';
import { MessageManager } from './manager/MessageManager';
import { ReminderManager } from './manager/ReminderManager';

export class WKIM {
  static shared = new WKIM();

  private constructor() {
    this.config = new WKConfig()
  }

  config: WKConfig

  async init(uid: string, token: string, address?: string): Promise<void> {
    this.config.uid = uid
    this.config.token = token
    this.config.address = address
    CryptoUtils.init()
    await WKDBHelper.shared.init()
  }

  // channel 管理
  channelManager(): ChannelManager {
    return ChannelManager.shared;
  }

  // channel 成员管理
  channelMemberManager(): ChannelMemberManager {
    return ChannelMemberManager.shared;
  }

  // message 消息管理
  messageManager(): MessageManager {
    return MessageManager.shared;
  }

  // cmd 命令管理
  cmdManager(): CMDManager {
    return CMDManager.shared;
  }

  // connection 连接管理
  connectionManager(): ConnectionManager {
    return ConnectionManager.shared;
  }

  // Conversation 最近会话管理
  conversationManager(): ConversationManager {
    return ConversationManager.shared;
  }

  // Reminder 提醒管理
  reminderManager(): ReminderManager {
    return ReminderManager.shared;
  }
}