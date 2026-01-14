import UIAbility from '@ohos.app.ability.UIAbility';
import hilog from '@ohos.hilog';
import window from '@ohos.window';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import Want from '@ohos.app.ability.Want';
import { WKIM } from '@ohos/wkim';
import { OrderMessageContent } from '../msg/OrderMsg';

// 全局 Context 存储
export class GlobalContext {
  private static instance: GlobalContext
  private _context?: Context

  private constructor() {}

  static get shared(): GlobalContext {
    if (!GlobalContext.instance) {
      GlobalContext.instance = new GlobalContext()
    }
    return GlobalContext.instance
  }

  setContext(context: Context) {
    this._context = context
  }

  getContext(): Context | undefined {
    return this._context
  }
}

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    console.error('onCreate创建')
    // 保存全局 Context

    GlobalContext.shared.setContext(this.context)
    // 注册自定义消息
    WKIM.shared.messageManager().registerMsgContent(56, (jsonStr: string) => {
      return new OrderMessageContent().decodeJson(jsonStr)
    })
  }

  onDestroy() {
    console.error('onDestroy销毁')
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage) {
    // Main window is created, set main page for this ability
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err, data) => {
      if (err.code) {
        hilog.error(0x0000, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err) ?? '');
        return;
      }
      hilog.info(0x0000, 'testTag', 'Succeeded in loading the content. Data: %{public}s', JSON.stringify(data) ?? '');
    });
  }

  onWindowStageDestroy() {
    // Main window is destroyed, release UI related resources
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground() {
    // Ability has brought to foreground
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground() {
    // Ability has back to background
    hilog.info(0x0000, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
