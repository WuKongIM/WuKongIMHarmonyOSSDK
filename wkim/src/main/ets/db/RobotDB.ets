import { relationalStore } from '@kit.ArkData';
import { WKLogger } from '../common/WKLogger';
import { WKRobotMenu } from '../entity/Bean';
import { WKDBConst } from './WKDBConst';
import { WKDBHelper } from './WKDBHelper';

export class RobotDB {
  static shared: RobotDB = new RobotDB();

  private constructor() {
  }

  readonly tag = 'RobotDB'

  isExistMenu(robotId: string, cmd: string): boolean {
    let resultSet: relationalStore.ResultSet | undefined
    try {
      resultSet = WKDBHelper.shared.getDB()?.querySqlSync(
        `select 1 from ${WKDBConst.tableRobotMenu} where robot_id=? and cmd=? limit 1`, [robotId, cmd])
      return resultSet?.goToNextRow() ?? false
    } catch (e) {
      WKLogger.error('查询机器人菜单是否存在错误', this.tag, 'isExistMenu', e)
      return false
    } finally {
      WKDBHelper.shared.safeClose(resultSet)
    }
  }

  // 支持单个或多个机器人；与 Android 一致，不指定菜单排序。
  queryRobotMenus(robotIds: string | string[]): WKRobotMenu[] {
    const ids: string[] = typeof robotIds === 'string' ? [robotIds] : robotIds
    const list: WKRobotMenu[] = []
    if (ids.length === 0) {
      return list
    }
    let resultSet: relationalStore.ResultSet | undefined
    try {
      resultSet = WKDBHelper.shared.getDB()?.querySqlSync(
        `select * from ${WKDBConst.tableRobotMenu} where robot_id in (${WKDBConst.getPlaceholders(ids.length)})`, ids)
      while (resultSet?.goToNextRow()) {
        list.push(this.serializeMenu(resultSet))
      }
      return list
    } catch (e) {
      WKLogger.error('查询机器人菜单错误', this.tag, 'queryRobotMenus', e)
      return []
    } finally {
      WKDBHelper.shared.safeClose(resultSet)
    }
  }

  // 按 robot_id + cmd 增量更新，保留创建时间及列表之外的旧菜单。
  insertOrUpdateMenus(list: WKRobotMenu[]): boolean {
    return this.saveMenus(list, true)
  }

  // 纯批量插入，与 Android 一致，不按 robot_id + cmd 去重。
  insertMenus(list: WKRobotMenu[]): boolean {
    return this.saveMenus(list, false)
  }

  private saveMenus(list: WKRobotMenu[], updateExisting: boolean): boolean {
    if (list.length === 0) {
      return true
    }
    const db = WKDBHelper.shared.getDB()
    if (db === undefined) {
      return false
    }
    let transactionStarted = false
    try {
      db.beginTransaction()
      transactionStarted = true
      for (const menu of list) {
        if (updateExisting) {
          const predicates = new relationalStore.RdbPredicates(WKDBConst.tableRobotMenu)
          predicates.equalTo('robot_id', menu.robotId).and().equalTo('cmd', menu.cmd)
          const values: relationalStore.ValuesBucket = {
            'type': menu.type,
            'remark': menu.remark,
            'updated_at': menu.updatedAt
          }
          if (db.updateSync(values, predicates) > 0) {
            continue
          }
        }
        const rowId = db.insertSync(WKDBConst.tableRobotMenu, this.getVB(menu))
        if (rowId <= 0) {
          throw new Error('插入机器人菜单失败')
        }
      }
      db.commit()
      return true
    } catch (e) {
      WKLogger.error('保存机器人菜单错误', this.tag, 'saveMenus', e)
      if (transactionStarted) {
        WKDBHelper.shared.safeRollBack()
      }
      return false
    }
  }

  private getVB(menu: WKRobotMenu): relationalStore.ValuesBucket {
    const values: relationalStore.ValuesBucket = {
      'robot_id': menu.robotId,
      'cmd': menu.cmd,
      'remark': menu.remark,
      'type': menu.type,
      'created_at': menu.createdAt,
      'updated_at': menu.updatedAt
    }
    return values
  }

  private serializeMenu(resultSet: relationalStore.ResultSet): WKRobotMenu {
    const menu = new WKRobotMenu()
    menu.robotId = WKDBConst.getString(resultSet, 'robot_id')
    menu.cmd = WKDBConst.getString(resultSet, 'cmd')
    menu.remark = WKDBConst.getString(resultSet, 'remark')
    menu.type = WKDBConst.getString(resultSet, 'type')
    menu.createdAt = WKDBConst.getString(resultSet, 'created_at')
    menu.updatedAt = WKDBConst.getString(resultSet, 'updated_at')
    return menu
  }
}
