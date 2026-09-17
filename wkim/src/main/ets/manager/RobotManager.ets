import { WKLogger } from '../common/WKLogger';
import { RobotDB } from '../db/RobotDB';
import { WKRobotMenu } from '../entity/Bean';

export type RefreshRobotMenuListener = () => void

export class RobotManager {
  static shared: RobotManager = new RobotManager();

  private constructor() {
  }

  private refreshListeners: Map<string, RefreshRobotMenuListener> = new Map()

  getRobotMenus(robotIds: string | string[]): WKRobotMenu[] {
    return RobotDB.shared.queryRobotMenus(robotIds)
  }

  // 空列表也通知刷新；写入失败则不发送成功刷新通知。
  saveOrUpdateRobotMenus(list: WKRobotMenu[]): boolean {
    if (!RobotDB.shared.insertOrUpdateMenus(list)) {
      return false
    }
    this.setRefreshRobotMenu()
    return true
  }

  addOnRefreshRobotMenu(key: string, listener: RefreshRobotMenuListener) {
    if (key.length === 0) {
      return
    }
    this.refreshListeners.set(key, listener)
  }

  removeRefreshRobotMenu(key: string) {
    this.refreshListeners.delete(key)
  }

  private setRefreshRobotMenu() {
    // 与现有 Manager 一致，在调用方的 ArkTS 上下文通知；快照避免回调修改遍历集合。
    const listeners: RefreshRobotMenuListener[] = []
    this.refreshListeners.forEach((listener: RefreshRobotMenuListener) => {
      listeners.push(listener)
    })
    listeners.forEach((listener: RefreshRobotMenuListener) => {
      try {
        listener()
      } catch (e) {
        WKLogger.error('机器人菜单刷新监听错误', 'RobotManager', e)
      }
    })
  }
}
