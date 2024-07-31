import { CommonUtil } from '../common/CommonUtil';
import { WKMsgContentType } from '../entity/Bean';
import { WKMediaMessageContent } from './WKMediaMessageContent';
import { WKMessageContent } from './WKMessageContent';

export class WKImageContent extends WKMediaMessageContent {
  width: number = 0
  height: number = 0

  constructor(localPath: string) {
    super()
    this.localPath = localPath
    this.contentType = WKMsgContentType.Image
  }

  encodeJson(): Record<string, Object> {
    let jsonObject: Record<string, Object> = {}
    jsonObject['width'] = this.width
    jsonObject['height'] = this.height
    jsonObject['url'] = this.url
    jsonObject['localPath'] = this.localPath
    return jsonObject
  }

  decodeJson(jsonStr: string): WKMessageContent {
    let json = CommonUtil.jsonToRecord(jsonStr)
    if (json!==undefined){
      this.url = CommonUtil.readString(json,'url')
      this.width = CommonUtil.readNumber(json,'width')
      this.height = CommonUtil.readNumber(json,'height')
      this.localPath = CommonUtil.readString(json,'localPath')
    }
    return this
  }

  displayText(): string {
    return "[图片]"
  }

  searchableWord(): string {
    return "图片"
  }
}