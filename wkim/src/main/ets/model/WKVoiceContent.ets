import { CommonUtil } from '../common/CommonUtil';
import { WKMsgContentType } from '../entity/Bean';
import { WKMediaMessageContent } from './WKMediaMessageContent';
import { WKMessageContent } from './WKMessageContent';

export class WKVoiceContent extends WKMediaMessageContent {
  timeTrad: number = 0
  waveform: string = ''

  constructor() {
    super();
    this.contentType = WKMsgContentType.Voice
  }

  encodeJson(): Record<string, Object> {
    let json: Record<string, Object> = {}
    json['timeTrad'] = this.timeTrad
    json['waveform'] = this.waveform
    json['url'] = this.url
    json['localPath'] = this.localPath
    return json
  }

  decodeJson(jsonStr: string): WKMessageContent {
    let json = CommonUtil.jsonToRecord(jsonStr)
    if (json !== undefined) {
      this.timeTrad = CommonUtil.readNumber(json, 'timeTrad')
      this.waveform = CommonUtil.readString(json, 'waveform') ?? ''
      this.url = CommonUtil.readString(json, 'url') ?? ''
      this.localPath = CommonUtil.readString(json, 'localPath') ?? ''
    }
    return this
  }

  displayText(): string {
    return '[语音]'
  }

  searchableWord(): string {
    return '语音'
  }
}