import preferences from '@ohos.data.preferences'
import { Context } from '@kit.AbilityKit'

const PREF_NAME = 'loginPreferences'
const KEY_UID = 'login_uid'
const KEY_TOKEN = 'login_token'
const KEY_API_URL = 'login_api_url'

export interface LoginInfo {
  uid: string
  token: string
  apiURL: string
}

export class LoginCacheUtil {
  /**
   * 保存登录信息到本地
   */
  static saveLoginInfo(context: Context | undefined, uid: string, token: string, apiURL: string): void {
    if (context === undefined) {
      console.error('保存登录信息失败: context 为空')
      return
    }
    try {
      let options: preferences.Options = { name: PREF_NAME }
      let shared = preferences.getPreferencesSync(context, options)
      shared.putSync(KEY_UID, uid)
      shared.putSync(KEY_TOKEN, token)
      shared.putSync(KEY_API_URL, apiURL)
      shared.flushSync()
    } catch (error) {
      console.error(`保存登录信息错误: ${error}`)
    }
  }

  /**
   * 获取缓存的登录信息
   * @returns 登录信息，如果没有缓存返回 undefined
   */
  static getLoginInfo(context: Context | undefined): LoginInfo | undefined {
    if (context === undefined) {
      console.error('获取登录信息失败: context 为空')
      return undefined
    }
    try {
      let options: preferences.Options = { name: PREF_NAME }
      let shared = preferences.getPreferencesSync(context, options)
      let uid = shared.getSync(KEY_UID, '') as string
      let token = shared.getSync(KEY_TOKEN, '') as string
      let apiURL = shared.getSync(KEY_API_URL, '') as string

      if (uid !== '' && token !== '' && apiURL !== '') {
        return { uid, token, apiURL }
      }
      return undefined
    } catch (error) {
      console.error(`获取登录信息错误: ${error}`)
      return undefined
    }
  }

  /**
   * 清除登录信息（退出登录时使用）
   */
  static clearLoginInfo(context: Context | undefined): void {
    if (context === undefined) {
      console.error('清除登录信息失败: context 为空')
      return
    }
    try {
      let options: preferences.Options = { name: PREF_NAME }
      let shared = preferences.getPreferencesSync(context, options)
      shared.deleteSync(KEY_UID)
      shared.deleteSync(KEY_TOKEN)
      shared.deleteSync(KEY_API_URL)
      shared.flushSync()
    } catch (error) {
      console.error(`清除登录信息错误: ${error}`)
    }
  }
}
