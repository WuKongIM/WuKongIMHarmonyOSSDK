import { WKMsgContentType } from '../entity/Bean';
import { WKMessageContent } from './WKMessageContent';

export class WKFormatErrorContent extends WKMessageContent{
  constructor() {
    super();
    this.contentType = WKMsgContentType.ContentFormatError
  }

  displayText(): string {
    return '[内容格式错误，无法查看]'
  }
}