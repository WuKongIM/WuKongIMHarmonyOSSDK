import { CommonUtil } from '../common/CommonUtil';
import { WKMsgContentType } from '../entity/Bean';
import { WKMediaMessageContent } from './WKMediaMessageContent';
import { WKMessageContent } from './WKMessageContent';

export class WKVideoContent extends WKMediaMessageContent {
  cover: string = ''
  coverLocalPath: string = ''
  second: number = 0
  size: number = 0
  width: number = 0
  height: number = 0

  constructor() {
    super();
    this.contentType = WKMsgContentType.Video
  }

  encodeJson(): Record<string, Object> {
    let json: Record<string, Object> = {}
    json['cover'] = this.cover
    json['coverLocalPath'] = this.coverLocalPath
    json['second'] = this.second
    json['size'] = this.size
    json['width'] = this.width
    json['height'] = this.height
    json['localPath'] = this.localPath
    json['url'] = this.url
    return json
  }

  decodeJson(jsonStr: string): WKMessageContent {
    let json = CommonUtil.jsonToRecord(jsonStr)
    if (json !== undefined) {
      this.cover = CommonUtil.readString(json, 'cover')
      this.coverLocalPath = CommonUtil.readString(json, 'coverLocalPath')
      this.second = CommonUtil.readNumber(json, 'second')
      this.size = CommonUtil.readNumber(json, 'size')
      this.width = CommonUtil.readNumber(json, 'width')
      this.height = CommonUtil.readNumber(json, 'height')
      this.localPath = CommonUtil.readString(json, 'localPath')
      this.url = CommonUtil.readString(json, 'url')
    }
    return this
  }

  displayText(): string {
    return '[视频]'
  }

  searchableWord(): string {
    return '视频'
  }
}