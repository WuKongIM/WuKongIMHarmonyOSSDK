import { CommonUtil } from '@ohos/wkim/src/main/ets/common/CommonUtil';
import { WKMediaMessageContent } from '@ohos/wkim/src/main/ets/model/WKMediaMessageContent';
import { WKMessageContent } from '@ohos/wkim/src/main/ets/model/WKMessageContent';

// 自定义普通消息
export class CardMessageContent extends WKMessageContent {
  uid: string = ''
  name: string = ''
  avatar: string = ''

  constructor() {
    super();
    this.contentType = 16 // 指定类型
  }

  // 编码发送内容
  encodeJson(): Record<string, Object> {
    let json: Record<string, Object> = {}
    json['uid'] = this.uid
    json['name'] = this.name
    json['avatar'] = this.avatar
    return json
  }

  // 解码内容
  decodeJson(jsonStr: string): WKMessageContent {
    let json = CommonUtil.jsonToRecord(jsonStr)
    if (json !== undefined) {
      this.uid = CommonUtil.readString(json, 'uid')
      this.name = CommonUtil.readString(json, 'name')
      this.avatar = CommonUtil.readString(json, 'avatar')
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
  longitude: number = 0.0
  latitude: number = 0.0

  constructor() {
    super();
    this.contentType = 17 // 指定类型
  }

  // 编码
  encodeJson(): Record<string, Object> {
    let json: Record<string, Object> = {}
    json['url'] = this.url
    json['longitude'] = this.longitude
    json['latitude'] = this.latitude
    return json
  }

  // 解码
  decodeJson(jsonStr: string): WKMessageContent {
    let json = CommonUtil.jsonToRecord(jsonStr)
    if (json !== undefined) {
      this.address = CommonUtil.readString(json, 'address')
      this.url = CommonUtil.readString(json, 'url')
      this.longitude = CommonUtil.readNumber(json, 'longitude')
      this.latitude = CommonUtil.readNumber(json, 'latitude')
    }
    return this
  }

  // 最近会话显示内容
  displayText(): string {
    return '[位置]'
  }
}
