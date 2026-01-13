import { Context } from '@kit.AbilityKit'
import preferences from '@ohos.data.preferences'
import util from '@ohos.util'
import { WKIM } from '../WKIM'
import { WKLogger } from './WKLogger'

let preName = 'wkSharePreferences'
let sqlVersionKey = 'wk_sql_max_version'

export class PreferencesUtil {
  private static getAppContext(): Context {
    return WKIM.shared.config.context ?? getContext()
  }

  static getDeviceId(): string {
    let context = PreferencesUtil.getAppContext()
    let key = WKIM.shared.config.uid + "_device_id"
    let options: preferences.Options = { name: preName };
    try {
      let shared = preferences.getPreferencesSync(context, options)
      let deviceId = shared.getSync(key, "")
      if (deviceId == "") {
        deviceId = `${util.generateRandomUUID().replaceAll("-", "")}H`
        shared.putSync(key, deviceId)
        shared.flushSync()
      }
      return deviceId.toString()
    } catch (error) {
      WKLogger.error(`获取设备错误,error:${error}`)
      return `${util.generateRandomUUID().replaceAll("-", "")}H`
    }
  }

  static getSqlMaxVersion(): number {
    let context = PreferencesUtil.getAppContext()
    let options: preferences.Options = { name: preName };
    try {
      let shared = preferences.getPreferencesSync(context, options)
      let version = shared.getSync(sqlVersionKey, 0) as number
      return version
    } catch (error) {
      WKLogger.error(`获取sqlite最大版本号错误,error:${error}`)
      return 0
    }

  }

  static setSqlMaxVersion(v: number) {
    let context = PreferencesUtil.getAppContext()
    let options: preferences.Options = { name: preName };
    try {
      let shared = preferences.getPreferencesSync(context, options)
      shared.putSync(sqlVersionKey, v)
    } catch (error) {
      WKLogger.error(`保存sqlite最大版本号错误,error:${error}`)
    }

  }
}