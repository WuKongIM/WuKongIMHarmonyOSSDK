import { Context } from '@kit.AbilityKit';
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

  /**
   * 初始化 SDK
   * @param uid 用户ID
   * @param token 用户Token
   * @param address 服务器地址（可选）
   * @param context 应用上下文（可选，推荐传入以避免 getContext() 弃用警告）
   */
  async init(uid: string, token: string, address?: string, context?: Context): Promise<void> {
    this.config.uid = uid
    this.config.token = token
    this.config.address = address
    if (context) {
      this.config.context = context
    }
    // await CryptoUtils.shared.init()
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