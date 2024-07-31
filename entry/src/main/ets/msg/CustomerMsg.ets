import { CommonUtil } from '@ohos/wkim/src/main/ets/common/CommonUtil';
import { WKMediaMessageContent } from '@ohos/wkim/src/main/ets/model/WKMediaMessageContent';
import { WKMessageContent } from '@ohos/wkim/src/main/ets/model/WKMessageContent';

// 自定义普通消息
export class CardMessageContent extends WKMessageContent {
  uid: string = ''
  name: string = ''

  constructor() {
    super();
    this.contentType = 16 // 指定类型
  }

  // 编码发送内容
  encodeJson(): Record<string, Object> {
    let json: Record<string, Object> = {}
    json['uid'] = this.uid
    json['name'] = this.name
    return json
  }

  // 解码内容
  decodeJson(jsonStr: string): WKMessageContent {
    let json = CommonUtil.jsonToRecord(jsonStr)
    if (json !== undefined) {
      this.uid = CommonUtil.readString(json, 'uid')
      this.name = CommonUtil.readString(json, 'name')
    }
    return this
  }

  // 最近会话显示内容
  displayText(): string {
    return '[名片]'
  }
}

// 自定义附件消息
export class LocationMessageContent extends WKMediaMessageContent {
  address: string = ''

  constructor() {
    super();
    this.contentType = 17 // 指定类型
  }

  // 编码
  encodeJson(): Record<string, Object> {
    let json: Record<string, Object> = {}
    json['url'] = this.url
    json['address'] = this.address
    return json
  }

  // 解码
  decodeJson(jsonStr: string): WKMessageContent {
    let json = CommonUtil.jsonToRecord(jsonStr)
    if (json !== undefined) {
      this.address = CommonUtil.readString(json, 'address')
      this.url = CommonUtil.readString(json, 'url')
    }
    return this
  }

  // 最近会话显示内容
  displayText(): string {
    return '[位置]'
  }
}
