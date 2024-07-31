import { CommonUtil } from '../common/CommonUtil';
import { ArrayList } from '@kit.ArkTS';
import { WKMsgEntity, WKReply, WKMentionInfo } from '../entity/Bean';

export class WKMessageContent {
  contentType: number = 0
  content: string = ""
  entities?: ArrayList<WKMsgEntity>
  reply?: WKReply
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