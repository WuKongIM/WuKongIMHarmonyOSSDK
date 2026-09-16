import { application, Context } from '@kit.AbilityKit';
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

  private getAppContext(): Context {
    if (WKIM.shared.config.context !== undefined) {
      return WKIM.shared.config.context
    }
    try {
      return application.getApplicationContext()
    } catch (error) {
      WKLogger.error(`获取应用上下文失败,error:${error}`)
      throw new Error('未能获取应用上下文，请在 WKIM.init() 时传入 context')
    }
  }

  async init() {
    let uid = WKIM.shared.config.uid
    let name = `${uid}.db`
    const STORE_CONFIG: relationalStore.StoreConfig = {
      name: name, // 数据库文件名
      securityLevel: relationalStore.SecurityLevel.S1, // 数据库安全级别
      encrypt: false // 可选参数，指定数据库是否加密，默认不加密
    };
    try {
      this.db = await relationalStore.getRdbStore(this.getAppContext(), STORE_CONFIG)
      this.onUpgrade()
    } catch (e) {
      WKLogger.error(`数据库初始化失败,code:${e.code},message:${e.message}`)
    }
  }

  getDB(): relationalStore.RdbStore | undefined {
    return this.db
  }

  async closeDB() {
    if (this.db !== undefined) {
      const db = this.db
      // Make a concurrent/repeated init observe the closed state immediately.
      this.db = undefined
      try {
        await db.close()
      } catch (e) {
        WKLogger.error(`关闭数据库失败,code:${e.code},message:${e.message}`)
      }
    }
  }

  private onUpgrade() {
    let data: Uint8Array
    try {
      data = this.getAppContext().resourceManager.getRawFileContentSync('sql.txt')
    } catch (e) {
      WKLogger.error(`读取sql.txt失败,code:${e.code},message:${e.message}`)
      return
    }
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
    let data: Uint8Array
    try {
      data = this.getAppContext().resourceManager.getRawFileContentSync(`${fileName}.sql`)
    } catch (e) {
      WKLogger.error(`读取${fileName}.sql失败,code:${e.code},message:${e.message}`)
      return list
    }
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

  // 安全关闭 ResultSet，避免 finally 中的异常处理
  safeClose(resultSet?: relationalStore.ResultSet) {
    try {
      resultSet?.close()
    } catch (e) {
      WKLogger.error('关闭ResultSet错误', 'safeClose', e)
    }
  }

  // 安全提交事务
  safeCommit() {
    try {
      this.db?.commit()
    } catch (e) {
      WKLogger.error('事务提交错误', 'safeCommit', e)
    }
  }

  // 安全回滚事务
  safeRollBack() {
    try {
      this.db?.rollBack()
    } catch (e) {
      WKLogger.error('事务回滚错误', 'safeRollBack', e)
    }
  }
}
