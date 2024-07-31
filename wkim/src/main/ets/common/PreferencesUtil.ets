import preferences from '@ohos.data.preferences'
import util from '@ohos.util'
import { WKIM } from '../WKIM'

let preName = 'wkSharePreferences'
let sqlVersionKey = 'wk_sql_max_version'

export class PreferencesUtil {
  static getDeviceId(): string {
    let context = getContext()
    let key = WKIM.shared.config.uid + "_device_id"
    let options: preferences.Options = { name: preName };
    let shared = preferences.getPreferencesSync(context, options)
    let deviceId = shared.getSync(key, "")
    if (deviceId == "") {
      deviceId = `${util.generateRandomUUID().replaceAll("-", "")}H`
      shared.putSync(key, deviceId)
      shared.flush()
    }
    return deviceId.toString()
  }

  static getSqlMaxVersion(): number {
    let context = getContext()
    let options: preferences.Options = { name: preName };
    let shared = preferences.getPreferencesSync(context, options)
    let version = shared.getSync(sqlVersionKey, 0) as number
    return version
  }

  static setSqlMaxVersion(v: number) {
    let context = getContext()
    let options: preferences.Options = { name: preName };
    let shared = preferences.getPreferencesSync(context, options)
    shared.putSync(sqlVersionKey, v)
  }
}