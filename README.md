## 悟空IM HarmonyOS NEXT SDK

### 快速开始
**下载安装**
```
ohpm install @ohos/wkim
```
**引入**
```
import { WKIM } from '@ohos/wkim';
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

### 许可证
悟空IM 使用 Apache 2.0 许可证。有关详情，请参阅 LICENSE 文件。