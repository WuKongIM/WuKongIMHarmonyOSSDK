import { CommonUtil } from '@ohos/wkim/src/main/ets/common/CommonUtil';
import { WKMediaMessageContent } from '@ohos/wkim/src/main/ets/model/WKMediaMessageContent';
import { WKMessageContent } from '@ohos/wkim/src/main/ets/model/WKMessageContent';
import { util } from '@kit.ArkTS';

// 自定义普通消息
export class OrderMessageContent extends WKMediaMessageContent {
  orderNo: string = ''
  title: string = ''
  imgUrl: string = ''
  price: number = 0
  num: number = 0

  constructor() {
    super();
    this.contentType = 56 // 指定类型
    this.localPath = util.generateRandomUUID().replaceAll("-", "")
  }

  // 编码发送内容
  encodeJson(): Record<string, Object> {
    let json: Record<string, Object> = {}
    json['price'] = this.price
    json['num'] = this.num
    json['imgUrl'] = this.imgUrl
    json['title'] = this.title
    json['orderNo'] = this.orderNo
    json['localPath'] = this.localPath
    return json
  }

  // 解码内容
  decodeJson(jsonStr: string): WKMessageContent {
    let json = CommonUtil.jsonToRecord(jsonStr)
    if (json !== undefined) {
      this.orderNo = CommonUtil.readString(json, 'orderNo') ?? ''
      this.imgUrl = CommonUtil.readString(json, 'imgUrl') ?? ''
      this.title = CommonUtil.readString(json, 'title') ?? ''
      this.num = CommonUtil.readNumber(json, 'num')
      this.price = CommonUtil.readNumber(json, 'price')
      this.localPath = CommonUtil.readString(json, 'localPath') ?? ''
    }
    return this
  }

  // 最近会话显示内容
  displayText(): string {
    return '[订单消息]'
  }
}
