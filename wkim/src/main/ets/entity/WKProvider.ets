import {
  SyncChannelMemberOptions,
  SyncOptions,
  WKChannel,
  WKChannelMember,
  WKConversationExtra,
  WKMsg,
  WKMsgExtra,
  WKReminder,
  WKSyncChannelMsg,
  WKSyncConversation
} from './Bean'

export type ConnectAddrCallback = () => Promise<string>

export type ChannelInfoCallback = (channelId: string, channelType: number) => Promise<WKChannel | undefined>

export type ChannelMemberCallback = (channelId: string, channelType: number,
  maxVersion: number) => Promise<WKChannelMember[]>

export type ChannelMemberWithPageCallback = (channel: WKChannel,
  option: SyncChannelMemberOptions) => Promise<WKChannelMember[]>

export type SyncConversationsCallback = (lastMsgSeqs: string, msgCount: number,
  version: number) => Promise<WKSyncConversation>

export type SyncConversationExtraCallback = (version: number) => Promise<WKConversationExtra[]>

export type SyncMessageCallback = (channel: WKChannel, options: SyncOptions) => Promise<WKSyncChannelMsg>

export type SyncRemindersCallback = (version: number) => Promise<WKReminder[]>

export type UploadAttachmentCallBack = (msg: WKMsg) => Promise<[boolean, WKMsg]>

export type UploadMessageExtraCallback = (extra: WKMsgExtra) => void

export class WKProvider {
  connectAddrCallback?: ConnectAddrCallback
  channelInfoCallback?: ChannelInfoCallback
  syncConversationCallback?: SyncConversationsCallback
  syncMessageCallback?: SyncMessageCallback
  channelMemberCallback?: ChannelMemberCallback
  channelMemberWithPageCallback?: ChannelMemberWithPageCallback
  syncConversationExtraCallback?: SyncConversationExtraCallback
  syncReminderCallback?: SyncRemindersCallback
  uploadAttachmentCallback?: UploadAttachmentCallBack
  uploadMessageExtraCallback?: UploadMessageExtraCallback
}
