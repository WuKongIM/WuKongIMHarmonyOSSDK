import hilog from '@ohos.hilog'

const LOGGER_DOMAIN: number = 0x0000
const LOGGER_TAG: string = 'HarmonyWKLogger'

export class WKLogger {
  private static domain: number = LOGGER_DOMAIN
  private static tag: string = LOGGER_TAG //日志Tag
  private static format: string = '%{public}s'
  private static showLog: boolean = true //是否显示打印日志


  /**
   * 初始化日志参数（该方法建议在Ability里调用）
   * @param domain
   * @param tag
   * @param showLog
   */
  static init(domain: number = LOGGER_DOMAIN, tag: string = LOGGER_TAG, showLog: boolean = true) {
    WKLogger.domain = domain
    WKLogger.tag = tag
    WKLogger.showLog = showLog
  }

  /**
   * 设置日志对应的领域标识，范围是0x0~0xFFFF。（该方法建议在Ability里调用）
   * @param domain
   */
  static setDomain(domain: number = LOGGER_DOMAIN) {
    WKLogger.domain = domain
  }

  /**
   * 设置日志标识（该方法建议在Ability里调用）
   * @param tag
   */
  static setTag(tag: string = LOGGER_TAG) {
    WKLogger.tag = tag
  }

  /**
   * 是否打印日志（该方法建议在Ability里调用）
   * @param showLog
   */
  static setShowLog(showLog: boolean = true) {
    WKLogger.showLog = showLog
  }

  /**
   * 打印DEBUG级别日志
   * @param args
   */
  static debug(...args: string[]): void {
    if (WKLogger.showLog) {
      hilog.debug(WKLogger.domain, WKLogger.tag, WKLogger.format.repeat(args.length), args)
    }
  }

  /**
   * 打印INFO级别日志
   * @param args
   */
  static info(...args: string[]): void {
    if (WKLogger.showLog) {
      hilog.info(WKLogger.domain, WKLogger.tag, WKLogger.format.repeat(args.length), args)
    }
  }

  /**
   * 打印WARN级别日志
   * @param args
   */
  static warn(...args: string[]): void {
    if (WKLogger.showLog) {
      hilog.warn(WKLogger.domain, WKLogger.tag, WKLogger.format.repeat(args.length), args)
    }
  }

  /**
   * 打印ERROR级别日志
   * @param args
   */
  static error(...args: string[]): void {
    if (WKLogger.showLog) {
      hilog.error(WKLogger.domain, WKLogger.tag, WKLogger.format.repeat(args.length), args)
    }
  }

  /**
   * 打印FATAL级别日志
   * @param args
   */
  static fatal(...args: string[]): void {
    if (WKLogger.showLog) {
      hilog.fatal(WKLogger.domain, WKLogger.tag, WKLogger.format.repeat(args.length), args)
    }
  }


  /**
   * 打印JSON对象和JSON字符串
   * @param obj
   */
  static print(obj: object | string) {
    try {
      if (typeof obj === 'object') {
        let str = JSON.stringify(obj, null, 2)
        let arr: string[] = str.split('\n')
        for (let index = 0; index < arr.length; index++) {
          console.debug(arr[index])
        }
      } else {
        obj = JSON.parse(obj)
        let str = JSON.stringify(obj, null, 2)
        let arr = str.split('\n')
        for (let index = 0; index < arr.length; index++) {
          console.debug(arr[index])
        }
      }
    } catch (err) {
      WKLogger.error(`WKLogger-print-异常`);
    }
  }
}