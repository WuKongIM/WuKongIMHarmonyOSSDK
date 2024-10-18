import { relationalStore } from '@kit.ArkData';
import { CommonUtil } from '../common/CommonUtil';
import { PreferencesUtil } from '../common/PreferencesUtil';
import { WKLogger } from '../common/WKLogger';
import { WKIM } from '../WKIM';
export class WKDBHelper {
  static shared: WKDBHelper = new WKDBHelper();

  private constructor() {
  }

  private db?: relationalStore.RdbStore

  async init() {
    let uid = WKIM.shared.config.uid
    let name = `${uid}.db`
    const STORE_CONFIG: relationalStore.StoreConfig = {
      name: name, // 数据库文件名
      securityLevel: relationalStore.SecurityLevel.S1, // 数据库安全级别
      encrypt: false // 可选参数，指定数据库是否加密，默认不加密
    };
    this.db = await relationalStore.getRdbStore(getContext(), STORE_CONFIG)
    this.onUpgrade()
  }

  getDB(): relationalStore.RdbStore | undefined {
    return this.db
  }

  closeDB() {
    if (this.db !== undefined) {
      this.db.close()
      this.db = undefined
    }
  }

  private onUpgrade() {
    let data = getContext().resourceManager.getRawFileContentSync('sql.txt')
    let names = CommonUtil.uint8ArrayToString(data)
    let fileNames = names.split(',')
    let tempMaxV = 0
    fileNames.forEach((name: string) => {
      let version: string = name.replaceAll('\n', '')
      let v: number = new Number(version).valueOf()
      let maxV = PreferencesUtil.getSqlMaxVersion()
      tempMaxV = maxV
      if (v > maxV) {
        let list = this.getSqlList(name.replaceAll('\n', ''))
        list.forEach((sql) => {
          try {
            WKLogger.error(sql)
             this.getDB()?.executeSync(sql)
            if (v > tempMaxV) {
              tempMaxV = v
            }
          } catch (e) {
            WKLogger.error(`执行sql错误,code:${e.code},message:${e.message}`)
          }
        })
      }
    })
    if (tempMaxV > 0) {
      PreferencesUtil.setSqlMaxVersion(tempMaxV)
    }
  }

  private getSqlList(fileName: string) {
    let list: string[] = []
    let data = getContext().resourceManager.getRawFileContentSync(`${fileName}.sql`)
    let names = CommonUtil.uint8ArrayToString(data)
    if (names.indexOf(';') > 0) {
      let sqls = names.split(';')
      sqls.forEach((sql: string) => {
        if (sql.replaceAll('\n', '').replaceAll(' ', '') !== '') {
          list.push(sql)
        }
      })
    } else {
      list.push(names)
    }
    return list
  }
}