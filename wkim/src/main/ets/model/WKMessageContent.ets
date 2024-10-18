import { CommonUtil } from '../common/CommonUtil';
import { ArrayList } from '@kit.ArkTS';
import { WKMsgEntity, WKReply, WKMentionInfo } from '../entity/Bean';

export class WKMessageContent {
  // 消息类型
  contentType: number = 0
  // 消息内容
  content: string = ""
  // 渲染消息内容 如@某人时需要渲染@xxx这段文字
  entities?: ArrayList<WKMsgEntity>
  // 消息回复
  reply?: WKReply
  // 提醒信息
  mentionInfo?: WKMentionInfo

  displayText(): string {
    return this.content;
  }

  searchableWord(): string {
    return this.content;
  }

  decodeJson(jsonStr: string): WKMessageContent {
    if (CommonUtil.isJSONStr(jsonStr)) {
      let map = CommonUtil.jsonToRecord(jsonStr)
      if (map !== undefined) {
        this.content = map['content'] as string
      }

    }
    return this
  }

  encodeJson(): Record<string, Object> {
    let jsonObject: Record<string, Object> = {}
    jsonObject['content'] = this.content
    return jsonObject
  }
}