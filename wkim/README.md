## 悟空IM HarmonyOS NEXT SDK
## [详细文档](https://githubim.com/sdk/harmonyos.html "文档")
### 快速开始
**下载安装**
```
ohpm install @wukong/wkim
```
**引入**
```
import { WKIM } from '@wukong/wkim';
```
**初始化**
```typescript
await WKIM.shared.init(uid, token)
```
**连接地址**
```typescript
    WKIM.shared.config.provider.connectAddrCallback = (): Promise<string> => {
      // 通过网络获取连接地址后返回
      let add = HttpUtil.getIP()
      return add
    }
```
**连接**
```typescript
WKIM.shared.connectionManager().connection()
```
**断开**
```typescript
// isLogout true：退出并清空用户信息 false：退出保持用户信息
WKIM.shared.connectionManager().disConnection(isLogout)
```
**发消息**
```typescript
// 构造消息model
let textModel: WKTextContent = new WKTextContent('你好,我是文本消息')
// 指定频道 
let channel: WKChannel = new WKChannel('uid',WKChannelType.personal)
// 发送
WKIM.shared.messageManager().send(textModel,channel)
```
### 监听
**连接状态**
```typescript
WKIM.shared.connectionManager()
  .addConnectStatusListener((status: number, reasonCode?: number, connInfo?: ConnectionInfo) => {
    switch (status) {
      case WKConnectStatus.success: {
       // `悟空IM(连接成功-节点:${connInfo?.nodeId})`
        break
      }
      case WKConnectStatus.fail:
        // '连接失败'
        break
      case WKConnectStatus.connecting:
       // '连接中...'
        break
      case WKConnectStatus.syncing:
       // '同步中...'
        break
      case WKConnectStatus.syncCompleted:
       // `悟空IM(连接成功-节点:${this.nodeId})`
        break
      case WKConnectStatus.noNetwork:
       // '网络异常'
        break
      case WKConnectStatus.kicked:
       // '其他账号登录'
        break
    }
  })
```

**消息入库**
```typescript
WKIM.shared.messageManager().addInsertedListener((msg) => {
    // 展示在UI上
    })
```
**新消息**
```typescript
newMsgsListener = (msgs: WKMsg[]) => {
  // 展示在UI上
}
WKIM.shared.messageManager().addNewMsgListener(this.newMsgsListener)
```

### 机器人菜单

```typescript
import { WKIM, WKRobotMenu } from '@wukong/wkim';

const manager = WKIM.shared.robotManager()
manager.addOnRefreshRobotMenu('chat-page', () => {
  const menus = manager.getRobotMenus('robot-id')
  // 使用 menus 更新页面
})

const menu = new WKRobotMenu()
menu.robotId = 'robot-id'
menu.cmd = '/help'
menu.remark = '帮助'
menu.type = 'command'
menu.createdAt = '2026-09-17 10:00:00'
menu.updatedAt = menu.createdAt
const saved = manager.saveOrUpdateRobotMenus([menu])

// 也支持按多个机器人查询
const menus = manager.getRobotMenus(['robot-id', 'another-robot-id'])

// 页面销毁时移除监听
manager.removeRefreshRobotMenu('chat-page')
```

菜单按 `robotId + cmd` 增量保存，更新时保留原创建时间，不删除未传入的旧菜单。
保存成功返回 `true` 并刷新；写入失败回滚整个批次，返回 `false`，不触发刷新。
空列表不清空数据，但仍触发刷新。查询未指定排序。
监听以 key 注册，同 key 覆盖；回调不携带参数，需重新查询菜单。
与其他 Manager 一致，请在 UI 所在的 ArkTS 上下文调用，刷新回调同步执行于调用上下文。

### 许可证
悟空IM 使用 Apache 2.0 许可证。有关详情，请参阅 LICENSE 文件。
