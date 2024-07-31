import { WKProtocol } from '../protocol/WKProtocol'
import { WKProvider } from './WKProvider'

export class WKConfig {
  constructor() {
    this.provider = new WKProvider()
  }

  uid?: string = ''
  token?: string = ''
  address?: string = ''
  debug: boolean = true
  deviceFlagApp = 0 // 0.app 1.web 2.pc
  protoVersion: number = 4
  protocol: WKProtocol = new WKProtocol()
  heartbeatInterval: number = 10000
  requestIPTimeout = 10000
  provider: WKProvider
}