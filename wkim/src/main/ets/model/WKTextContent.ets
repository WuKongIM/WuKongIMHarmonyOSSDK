import { CommonUtil } from '../common/CommonUtil';
import { WKMsgContentType } from '../entity/Bean';
import { WKMessageContent } from './WKMessageContent'

export class WKTextContent extends WKMessageContent {
  constructor(content: string) {
    super();
    this.content = content
    this.contentType = WKMsgContentType.Text;
  }

  decodeJson(jsonStr: string): WKMessageContent {
    let json = CommonUtil.jsonToRecord(jsonStr)
    if (json !== undefined) {
      this.content = json['content'] as string
    }
    return this
  }

  encodeJson(): Record<string, Object> {
    let jsonObject: Record<string, Object> = {}
    jsonObject['content'] = this.content
    return jsonObject
  }

  displayText(): string {
    return this.content
  }

  searchableWord(): string {
    return this.content
  }
}