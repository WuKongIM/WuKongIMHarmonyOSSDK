import { WKMsgContentType } from '../entity/Bean';
import { WKMessageContent } from './WKMessageContent';

export class WKUnknownContent extends WKMessageContent {
  constructor() {
    super();
    this.contentType = WKMsgContentType.Unknown
  }

  displayText(): string {
    return '[未知消息]'
  }
}