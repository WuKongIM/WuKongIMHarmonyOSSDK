import { WKIM } from '@ohos/wkim';
import {
  ConnectionInfo,
  WKChannel,
  WKConnectStatus,
  WKConversation,
  WKReminder,
} from '@ohos/wkim/src/main/ets/entity/Bean';
import { DateUtil } from '@ohos/wkim/src/main/ets/common/DateUtil';
import { router } from '@kit.ArkUI';
import { IMUtil } from '../service/IMUtil';
import { HttpUtil } from '../service/HttpUtil';

function isRemind(list?: WKReminder[]): boolean {
  if (list === undefined || list.length === 0) {
    return false
  }
  let isRemindMe = false
  list.forEach((r) => {
    if (r.done === 0 && r.type === 1 && r.publisher !== IMUtil.uid) {
      isRemindMe = true
    }
  })
  return isRemindMe
}

@Observed
class ObservedArray<T> extends Array<T> {
  constructor(args: T[]) {
    if (args instanceof Array) {
      super(...args);
    } else {
      super(args)
    }
  }
}

@Observed
export class UIConv {
  msg: WKConversation
  name?: string
  avatar?: string
  itemViewState: number = 0
  unreadCount: number = 0
  isRemind: boolean = false

  constructor(msg: WKConversation) {
    this.msg = msg
    this.unreadCount = msg.unreadCount
    this.isRemind = isRemind(msg.getReminders())
  }
}

@Entry
@Component
struct Main {
  private nodeId: number = 0
  @State titleText: string = '悟空IM【连接成功】'
  @State list: ObservedArray<UIConv> = []
  private scroller: ListScroller = new ListScroller()
  // 监听channel刷新
  refreshChannel = (channel: WKChannel): void => {
    if (this.list.length === 0) {
      return
    }
    for (let i = 0; i < this.list.length; i++) {
      if (this.list[i].msg.channelId === channel.channelId && this.list[i].msg.channelType === channel.channelType) {
        this.list[i].msg.setChannel(channel)
        this.list[i].avatar = channel.avatar
        this.list[i].name = channel.channelName
        break
      }
    }
  }
  // 提醒项刷新
  refreshReminders = (reminders: WKReminder[]): void => {
    reminders.forEach((r) => {
      for (let i = 0; i < this.list.length; i++) {
        if (r.channelId === this.list[i].msg.channelId && r.channelType === this.list[i].msg.channelType) {
          if (this.list[i].msg.getReminders() === undefined || this.list[i].msg.getReminders()?.length === 0) {
            let reminders: WKReminder[] = []
            reminders.push(r)
            this.list[i].msg.setReminders(reminders)
          } else {
            this.list[i].msg.getReminders()?.forEach((tempReminder) => {
              if (tempReminder.reminderId === r.reminderId) {
                tempReminder.done = r.done
              }
            })
          }
          this.list[i].isRemind = isRemind(this.list[i].msg.getReminders())
          break
        }
      }
    })
  }

  addRefreshMsgListener() {
    // 刷新消息
    WKIM.shared.conversationManager().addRefreshListener((refreshList: WKConversation[]) => {
      refreshList.forEach((c) => {
        let isAdd = true
        if (this.list.length > 0) {
          for (let i = 0, len = this.list.length; i < len; i++) {
            if (c.channelId === this.list[i].msg.channelId && c.channelType === this.list[i].msg.channelType) {
              this.list[i].msg = c
              this.list[i].unreadCount = c.unreadCount
              isAdd = false
              break
            }
          }
        }
        if (isAdd) {
          let msg = new UIConv(c)
          this.list.push(msg)
        }
      })
    })

    // 更新远程扩展
    WKIM.shared.conversationManager().addRefreshExtrasListener((e) => {
      if (this.list.length > 0) {
        e.forEach((extra) => {
          for (let i = 0, len = this.list.length; i < len; i++) {
            if (extra.channelId === this.list[i].msg.channelId && extra.channelType === this.list[i].msg.channelType) {
              this.list[i].msg.remoteExtra = extra
              break
            }
          }
        })
      }
    })

    // 删除
    WKIM.shared.conversationManager().addDeletedListener((channelId: string, channelType: number) => {
      if (this.list.length > 0) {
        for (let i = 0, len = this.list.length; i < len; i++) {
          if (channelId === this.list[i].msg.channelId && channelType === this.list[i].msg.channelType) {
            this.list.splice(i, 1)
            break
          }
        }
      }
    })

    // 监听提醒项
    WKIM.shared.reminderManager().addRefreshListener(this.refreshReminders)
  }

  initListener() {

    this.addRefreshMsgListener()
    WKIM.shared.channelManager().addRefreshListener(this.refreshChannel)
    WKIM.shared.connectionManager()
      .addConnectStatusListener((status: number, reasonCode?: number, connInfo?: ConnectionInfo) => {
        switch (status) {
          case WKConnectStatus.success: {
            if (connInfo !== undefined) {
              this.nodeId = connInfo.nodeId
            }
            this.titleText = `悟空IM(连接成功-节点:${this.nodeId})`
            break
          }
          case WKConnectStatus.fail:
            this.titleText = '连接失败'
            if (reasonCode !== undefined && reasonCode === WKConnectStatus.kicked) {
              // 被踢需退出到登录页面
              this.titleText = '已在其他设备登录'
            }
            break
          case WKConnectStatus.connecting:
            this.titleText = '连接中...'
            break
          case WKConnectStatus.syncing:
            this.titleText = '同步中...'
            break
          case WKConnectStatus.syncCompleted:
            this.titleText = `悟空IM(连接成功-节点:${this.nodeId})`
            break
          case WKConnectStatus.noNetwork:
            this.titleText = '网络异常'
            break
          case WKConnectStatus.kicked:
            this.titleText = '已断开[其他账号登录]'
            break
        }
      })
    let msgs = WKIM.shared.conversationManager().all()
    if (msgs !== undefined) {
      for (let i = 0; i < msgs.length; i++) {
        let uiMsg = new UIConv(msgs[i])
        if (msgs[i].getChannel() !== undefined) {
          uiMsg.avatar = msgs[i].getChannel()?.avatar
          uiMsg.name = msgs[i].getChannel()?.channelName
        }
        this.list.push(uiMsg)
      }
    }
  }

  aboutToDisappear(): void {
    WKIM.shared.channelManager().removeRefreshListener(this.refreshChannel)
    WKIM.shared.reminderManager().removeRefreshListener(this.refreshReminders)
  }

  aboutToAppear(): void {
    this.initListener()
  }

  @Builder
  itemEnd(conv: UIConv) {
    Row() {
      Text('已读未读')
        .padding({ left: 10, right: 10 })
        .backgroundColor('#ff0b8503')
        .height('100%')
        .fontSize(16)
        .fontWeight(FontWeight.Bolder)
        .fontColor('#fff')
        .onClick(() => {
          // 标记已读未读
          let count = 1
          if (conv.unreadCount > 0) {
            count = 0
          }
          WKIM.shared.conversationManager().updateRedDot(conv.msg.channelId, conv.msg.channelType, count)
          this.scroller.closeAllSwipeActions()
        })
      Text('模拟提醒')
        .padding({ left: 10, right: 10 })
        .backgroundColor('#ff5a6df1')
        .height('100%')
        .fontSize(16)
        .fontWeight(FontWeight.Bolder)
        .fontColor('#fff')
        .onClick(() => {
          // 模拟提醒
          this.scroller.closeAllSwipeActions()
          let list = conv.msg.getReminders()
          let reminder = new WKReminder()
          if (list === undefined || list.length === 0) {
            reminder.done = 0
            reminder.publisher = 'u1'
            reminder.needUpload = 0
            reminder.type = 1
            reminder.data = {
              'text': '[有人@你]'
            }
            reminder.reminderId = 11
            reminder.version = 1
            reminder.channelId = conv.msg.channelId
            reminder.channelType = conv.msg.channelType
          } else {
            reminder = list[0]
            reminder.done = reminder.done === 1 ? 0 : 1
          }
          let tempList: WKReminder[] = []
          tempList.push(reminder)
          WKIM.shared.reminderManager().save(tempList)
        })
      Text('模拟删除')
        .padding({ left: 10, right: 10 })
        .backgroundColor('#ffec141b')
        .height('100%')
        .fontSize(16)
        .fontWeight(FontWeight.Bolder)
        .fontColor('#fff')
        .onClick(() => {
          // 删除
          WKIM.shared.conversationManager().delete(conv.msg.channelId, conv.msg.channelType)
          this.scroller.closeAllSwipeActions()
        })
    }.justifyContent(FlexAlign.SpaceEvenly)
  }

  build() {
    Column() {
      Row() {
        Text(this.titleText)
          .fontColor(Color.White)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 10 })
          .layoutWeight(1)

        Text('退出')
          .fontColor(Color.White)
          .fontSize(16)
          .padding({ left: 15, right: 15, top: 8, bottom: 8 })
          .backgroundColor('#ff2979ff')
          .borderRadius(6)
          .margin({ right: 15 })
          .onClick(() => {
            WKIM.shared.connectionManager().disConnection(true)
            router.replaceUrl({ url: 'pages/Index' })
          })
      }
      .width('100%')
      .height('10%')
      .backgroundColor('#ff3f91f6')
      .expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.KEYBOARD], [SafeAreaEdge.TOP])


      List({ scroller: this.scroller }) {
        ForEach(this.list, (item: UIConv) => {
          ListItem() {
            ItemView({ conv: item })
          }.backgroundColor('#fff').onClick(() => {
            if (item.itemViewState === 1) {
              this.scroller.closeAllSwipeActions()
              return
            }
            let json: Record<string, Object> = {
              'channel_id': item.msg.channelId,
              'channel_type': item.msg.channelType
            }
            router.pushUrl({
              url: 'pages/Chat',
              params: json
            })
          }).swipeAction({
            end: {
              builder: this.itemEnd(item), onStateChange: (state) => {
                item.itemViewState = state
              }
            }, edgeEffect: SwipeEdgeEffect.Spring
          })
        })
      }
      .listDirection(Axis.Vertical)
      .divider({
        strokeWidth: 0,
        color: '#ccc'
      })
      .height('100%')
      .width('100%')
      .layoutWeight(1)
    }.backgroundColor('#f6f6f6')
  }
}


@Component
export default struct ItemView {
  @ObjectLink conv: UIConv

  build() {
    Row() {
      Column() {
        Image(this.getAvatar())
          .width(55)
          .height(55)
          .objectFit(ImageFit.Cover)
          .align(Alignment.Start)
      }.width('15%').margin({
        left: 10
      })

      Column() {
        Row() {
          Text(this.getName())
            .fontColor('#ff090101')
            .fontSize(18)
            .maxLines(1)
            .fontWeight(FontWeight.Bold)
            .textAlign(TextAlign.Start)
            .align(Alignment.Start)
            .textAlign(TextAlign.Start)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)

          Text(this.getTime())
            .fontColor('#ff838080')
            .fontSize(12)
            .margin({
              right: 10
            })
            .maxLines(1)

        }
        .alignItems(VerticalAlign.Center)
        .justifyContent(FlexAlign.SpaceBetween)
        .width('95%')

        Row() {
          if (this.conv.isRemind) {
            Text('[有人@我]')
              .fontColor('#ffee0d0d')
              .fontSize(16)
              .maxLines(1)
              .fontWeight(FontWeight.Normal)
              .ellipsisMode(EllipsisMode.END)
              .margin({ right: 5 })
          }
          Text(this.getContent())
            .fontColor('#ff3f4040')
            .fontSize(16)
            .maxLines(1)
            .fontWeight(FontWeight.Normal)
            .ellipsisMode(EllipsisMode.END)
            .layoutWeight(1)

          if (this.conv.msg.unreadCount > 0) {
            Text(`${this.conv.msg.unreadCount}`)
              .fontColor('#ffee0303')
              .fontSize(16)
              .maxLines(1)
              .fontWeight(FontWeight.Bold)
              .margin({
                left: 10,
                right: 10
              })
          }
        }.margin({
          top: 5,
        }).width('95%')

      }.width('85%')
    }.justifyContent(FlexAlign.Start).alignItems(VerticalAlign.Center).width('100%').padding({
      top: 7.5,
      bottom: 7.5
    })
  }

  getAvatar(): string {
    if (this.conv.avatar === undefined) {
      return 'imgs/ic_default_avatar.png'
    }
    return `${HttpUtil.getURL()}/${this.conv.avatar}`
  }

  getName(): string {
    let channel = this.conv.msg.getChannel()
    if (channel === undefined) {
      WKIM.shared.channelManager().fetchChannelInfo(this.conv.msg.channelId, this.conv.msg.channelType)
    }
    return this.conv.name ?? '会话'
  }

  getTime(): string {
    let msg = this.conv.msg.getMsg()
    if (msg === undefined) {
      return ''
    }
    let time = DateUtil.getTimeToYYYYDDMMHHMMSS(msg.timestamp * 1000)
    return time
  }

  getContent(): string {
    let msg = this.conv.msg.getMsg()
    if (msg === undefined) {
      return ''
    }
    let content = msg.messageContent?.displayText()
    return content ?? ''
  }
}