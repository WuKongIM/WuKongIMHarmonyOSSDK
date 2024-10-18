import { promptAction, router } from '@kit.ArkUI';
import { WKIM } from '@ohos/wkim';
import {
  ChannelMsgOptions,
  WKChannel,
  WKMsg,
  WKMsgExtra,
  WKReply,
  WKSendMsgResult,
  WKSendOptions
} from '@ohos/wkim/src/main/ets/entity/Bean';
import { WKTextContent } from '@ohos/wkim/src/main/ets/model/WKTextContent';
import { LocationMessageContent, CardMessageContent } from '../msg/CustomerMsg';
import { IMUtil } from '../service/IMUtil';

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
export class UIMsg {
  msg: WKMsg
  status: number = 0
  avatarURL: string = ''
  itemViewType: number = 0 // 0 发送 1.接受 2.loading
  content = ''
  sendStatusIVURL = ''

  constructor(msg: WKMsg) {
    this.msg = msg
    if (msg.contentType === -1) {
      this.itemViewType = 2
    } else {
      if (this.msg.fromUID !== '' && this.msg.fromUID === IMUtil.uid) {
        this.itemViewType = 0
        if (this.msg.status === WKSendMsgResult.loading) {
          this.sendStatusIVURL = 'imgs/loading.png'
        } else if (this.msg.status === WKSendMsgResult.success) {
          this.sendStatusIVURL = 'imgs/success.png'
        } else if (this.msg.status === WKSendMsgResult.success) {
          this.sendStatusIVURL = 'imgs/error.png'
        }
      } else {
        this.itemViewType = 1
      }
      this.status = this.msg.status
      this.avatarURL = `https://api.multiavatar.com/${msg.fromUID}.png`
      if (this.msg.messageContent !== undefined) {
        this.content = this.msg.messageContent?.displayText()
      }
    }
  }
}

@Entry
@Component
struct Chat {
  channelId: string = (router.getParams() as Record<string, Object>)['channel_id'] as string
  channelType: number = (router.getParams() as Record<string, Object>)['channel_type'] as number
  @State title: string = ''
  @State sendContent: string = ''
  channel?: WKChannel
  @State list: ObservedArray<UIMsg> = []
  isRefresh = false
  isLoadMore = false
  canLoadMore = true
  canRefresh = true
  limit = 20
  scroller: Scroller = new Scroller()
  refreshChannelListener = (channel: WKChannel) => {
    if (channel.channelType === this.channelType && channel.channelId === this.channelId) {
      this.channel = channel
      this.title = channel.channelRemark === '' ? channel.channelName : channel.channelRemark
    }
  }
  sendResultListener = (clientMsgSeq: number, messageId: string, messageSeq: number, reasonCode: number) => {
    if (this.list.length > 0) {
      for (let i = 0; i < this.list.length; i++) {
        if (this.list[i].msg.clientSeq === clientMsgSeq) {
          this.list[i].msg.messageId = messageId
          this.list[i].msg.messageSeq = messageSeq
          this.list[i].msg.status = reasonCode
          this.list[i].status = reasonCode
          if (this.list[i].status === WKSendMsgResult.loading) {
            this.list[i].sendStatusIVURL = 'imgs/loading.png'
          } else if (this.list[i].status === WKSendMsgResult.success) {
            this.list[i].sendStatusIVURL = 'imgs/success.png'
          } else  {
            this.list[i].sendStatusIVURL = 'imgs/error.png'
          }
          break
        }
      }
    }
  }
  newMsgsListener = (msgs: WKMsg[]) => {
    msgs.forEach((msg) => {
      if (msg.channelId === this.channelId && msg.channelType === this.channelType) {

        let isAdd = true
        for (let i = 0; i < this.list.length; i++) {
          if (this.list[i].msg.clientMsgNo === msg.clientMsgNo || this.list[i].msg.messageId === msg.messageId) {
            isAdd = false
            break
          }
        }
        if (isAdd) {
          this.list.push(new UIMsg(msg))
        }
        this.scroller.scrollEdge(Edge.Bottom)
      }
    })
  }
  refreshMsgListener = (msg: WKMsg) => {
    if (this.list.length > 0) {
      for (let i = 0; i < this.list.length; i++) {
        if (this.list[i].msg.clientSeq === msg.clientSeq) {
          this.list[i].msg = msg
          break
        }
      }
    }
  }
  refreshExtrasListener = (extras: WKMsgExtra[]) => {
    if (this.list.length > 0) {
      extras.forEach((extra) => {
        for (let i = 0; i < this.list.length; i++) {
          if (this.list[i].msg.messageId === extra.messageId) {
            this.list[i].msg.remoteExtra = extra
            break
          }
        }
      })
    }
  }

  build() {
    Column() {
      Row() {
        Image('imgs/ic_back.png').width(25).height(25).margin({
          left: 15,
          right: 15
        }).onClick(() => {
          router.back()
        })
        Text(this.title).fontColor('#fff').fontSize(20).fontWeight(FontWeight.Bold)
      }.expandSafeArea([SafeAreaType.SYSTEM, SafeAreaType.KEYBOARD], [SafeAreaEdge.TOP])
      .width('100%').height('10%').backgroundColor('#ff3f91f6')

      List({ scroller: this.scroller }) {
        ForEach(this.list, (item: UIMsg) => {
          ListItem() {
            if (item.itemViewType === 0) {
              SendView({ uiMsg: item })
            } else if (item.itemViewType === 1) {
              RecvView({ uiMsg: item })
            } else if (item.itemViewType === 2) {
              LoadingView()
            }
          }
        })
      }
      .layoutWeight(1)
      .backgroundColor('#f1f1f1')
      .width('100%')
      .height('100%')
      .onScrollIndex((start: number, end: number) => {
        // Listen to the first index of the current list.
        if (this.isRefresh || this.isLoadMore) {
          return
        }
        if (start === 0 && this.canRefresh) {
          let orderSeq = 0
          this.list.forEach((m) => {
            if (m.msg.orderSeq < orderSeq || orderSeq === 0) {
              orderSeq = m.msg.orderSeq
            }
          })
          this.isRefresh = true
          let msg = new WKMsg()
          msg.contentType = -1
          this.list.unshift(new UIMsg(msg))
          this.scroller.scrollEdge(Edge.Top)
          setTimeout(() => {
            this.getOrSyncMessages(0, orderSeq)
          }, 1000)
        }
        if (!this.isRefresh && this.canLoadMore) {
          if (end === this.list.length - 1) {
            let orderSeq = 0
            this.list.forEach((m) => {
              if (orderSeq < m.msg.orderSeq) {
                orderSeq = m.msg.orderSeq
              }
            })
            this.isLoadMore = true
            let msg = new WKMsg()
            msg.contentType = -1
            this.list.push(new UIMsg(msg))
            this.scroller.scrollEdge(Edge.End)
            setTimeout(() => {
              this.getOrSyncMessages(1, orderSeq)
            }, 1000)
          }
        }
      })

      Row() {
        TextInput({
          placeholder: '请输入内容',
          text: this.sendContent
        })
          .width('40%')
          .placeholderColor('#999')
          .backgroundColor('#eee')
          .fontColor('#000')
          .type(InputType.Normal)
          .onChange((v) => {
            this.sendContent = v
          })
          .fontWeight(1)
        Button('发送').margin({
          left: 10,
          right: 10
        }).fontSize(14).onClick(() => {
          if (this.sendContent === '') {
            promptAction.showToast({
              message: "请输入内容",
              duration: 1000,
              bottom: 100
            })
            return
          }

          let textModel: WKTextContent = new WKTextContent(this.sendContent)
          textModel.reply  =new WKReply()
          textModel.reply.messageId =''
          let channel = this.channel
          if (channel === undefined) {
            channel = new WKChannel(this.channelId, this.channelType)
          }
          let option = new WKSendOptions()
          // option.setting.receipt = 1 // 开启回执
          // option.setting.topic = 1  // 话题消息
          // option.setting.stream = 1 // 流消息
          // option.header.noPersist = true // 发送不存储消息
          // option.header.redDot = false // 发送不显示红点消息
          // option.topicId = '' // option.setting.topic = 1 时指定话题ID
          // option.expire = 300 // 消息过期时间
          WKIM.shared.messageManager().sendWithOption(textModel, channel, option)
          this.sendContent = ''
        })
        Button('自定义').fontSize(14).onClick(() => {

          let model = new CardMessageContent()
          model.uid = '11'
          model.name = '悟空IM'
          let channel = this.channel
          if (channel === undefined) {
            channel = new WKChannel(this.channelId, this.channelType)
          }
          let option = new WKSendOptions()
          WKIM.shared.messageManager().sendWithOption(model, channel, option)
        })
        Button('附件').margin({ left: 10, right: 10 }).fontSize(14).onClick(() => {
          let model = new LocationMessageContent()
          model.address = '上海市浦东新区'
          let channel = this.channel
          if (channel === undefined) {
            channel = new WKChannel(this.channelId, this.channelType)
          }
          let option = new WKSendOptions()
          option.setting.receipt = 1 // 开回执
          WKIM.shared.messageManager().sendWithOption(model, channel, option)
        })
      }.backgroundColor('#f6f6f6').width('100%').padding(10)
    }
    .height('100%')
  }

  getOrSyncMessages(pullModel: number, orderSeq: number) {
    let option = new ChannelMsgOptions(() => {
      // 消息同步中
    }, (list) => {
      this.isRefresh = false
      this.isLoadMore = false
      for (let i = 0; i < this.list.length; i++) {
        if (this.list[i].msg.contentType === -1) {
          this.list.splice(i, 1)
          break
        }
      }
      if (pullModel === 1) {
        this.canLoadMore = list.length >= this.limit
      }
      if (pullModel === 0) {
        this.canRefresh = list.length >= this.limit
      }
      // 显示消息
      if (list.length > 0) {
        let uiMsgs: UIMsg[] = []
        list.forEach((msg) => {
          let uiMsg = new UIMsg(msg)
          if (pullModel === 0) {
            uiMsgs.push(uiMsg)
          } else {
            this.list.push(uiMsg)
          }
        })
        if (uiMsgs.length > 0) {
          this.list.unshift(...uiMsgs)
          let index = uiMsgs.length - 1
          this.scroller.scrollToIndex(index)
        }
        if (orderSeq === 0) {
          this.scroller.scrollEdge(Edge.Bottom)
        }
      }
    })
    option.oldestOrderSeq = orderSeq
    option.pullMode = pullModel
    option.aroundMsgOrderSeq = 0
    option.limit = this.limit
    WKIM.shared.messageManager().getOrSyncHistoryMessages(new WKChannel(this.channelId, this.channelType), option)
  }

  listener() {
    // 强制刷新channel资料
    WKIM.shared.channelManager().fetchChannelInfo(this.channelId, this.channelType)
    // 监听channel资料更新事件
    WKIM.shared.channelManager().addRefreshListener(this.refreshChannelListener)
    // 监听发送消息入库
    WKIM.shared.messageManager().addInsertedListener((msg) => {
      this.list.push(new UIMsg(msg))
      this.scroller.scrollEdge(Edge.Bottom)
    })
    // 监听发送消息状态返回事件
    WKIM.shared.messageManager()
      .addSendStatusListener(this.sendResultListener)
    // 监听新消息
    WKIM.shared.messageManager().addNewMsgListener(this.newMsgsListener)
    // 监听刷新消息
    WKIM.shared.messageManager().addRefreshListener(this.refreshMsgListener)
    // 监听刷新扩展
    WKIM.shared.messageManager().addRefreshExtraListener(this.refreshExtrasListener)
  }

  aboutToAppear(): void {
    this.listener()
    this.channel = WKIM.shared.channelManager().getChannel(this.channelId, this.channelType)
    if (this.channel !== undefined) {
      this.title = this.channel.channelName
    }
    this.getOrSyncMessages(0, 0)
  }

  aboutToDisappear(): void {
    // 移除发送状态监听
    WKIM.shared.messageManager().removeSendStatusListener(this.sendResultListener)
    // 移除刷新消息扩展监听
    WKIM.shared.messageManager().removeRefreshExtraListener(this.refreshExtrasListener)
    // 移除刷新消息监听
    WKIM.shared.messageManager().removeRefreshListener(this.refreshMsgListener)
    // 移除新消息监听
    WKIM.shared.messageManager().removeNewMsgListener(this.newMsgsListener)
    // 移除刷新channel监听
    WKIM.shared.channelManager().removeRefreshListener(this.refreshChannelListener)
  }
}

@Component
export default struct SendView {
  @ObjectLink uiMsg: UIMsg

  getUid() {
    let msg = this.uiMsg.msg.messageContent as CardMessageContent
    return msg.uid
  }

  getName() {
    let msg = this.uiMsg.msg.messageContent as CardMessageContent
    return msg.name
  }

  getColorBG() {
    if (this.uiMsg.msg.contentType === 16) {
      return '#ffc8a804'
    } else if (this.uiMsg.msg.contentType === 17) {
      return '#ffd410ea'
    }
    return '#ff075cdb'
  }

  getAddressUrl() {
    let msg = this.uiMsg.msg.messageContent as LocationMessageContent
    return msg.url
  }

  getAddress() {
    let msg = this.uiMsg.msg.messageContent as LocationMessageContent
    return msg.address
  }

  build() {
    Row() {
      Row() {
        Column() {
          if (this.uiMsg.msg.contentType === 16) {
            Text(`uid:${this.getUid()}`)
              .fontSize(14)
              .fontColor('#fff')
              .padding(10)
            Text(`名字:${this.getName()}`)
              .fontSize(14)
              .fontColor('#fff32727')
              .padding(10)
          } else if (this.uiMsg.msg.contentType === 17) {
            Image(this.getAddressUrl()).width(200).height(150)
            Text(`地址:${this.getAddress()}`)
              .fontSize(14)
              .fontColor('#fffaf9f9')
              .padding(10)
          } else {
            Text(this.uiMsg.content)
              .fontSize(14)
              .fontColor('#fff')
              .padding(10)
          }

          Image(this.uiMsg.sendStatusIVURL).width(20).height(20)
        }.alignItems(HorizontalAlign.End).backgroundColor(this.getColorBG()).margin({
          left: 60
        })
      }.layoutWeight(1).justifyContent(FlexAlign.End)

      Image(this.uiMsg.avatarURL).width(40).height(40).margin({ right: 10, left: 10 })
    }.justifyContent(FlexAlign.End).width('100%').margin({
      top: 10
    })
  }
}

@Component
export struct RecvView {
  @ObjectLink uiMsg: UIMsg

  build() {
    Row() {
      Image(this.uiMsg.avatarURL).width(40).height(40).margin({ right: 10, left: 10 })
      Text(this.uiMsg.content)
        .fontSize(14)
        .fontColor('#000')
        .padding(10)
        .backgroundColor('#fff')
        .margin({ right: 60 })
    }.margin({
      top: 10,
      right: 60
    })
  }
}


@Component
export struct LoadingView {
  build() {
    Row() {
      Image('imgs/loading.png').width(30).height(30)
    }.width('100%').justifyContent(FlexAlign.Center).margin({
      top: 10,
      bottom: 10
    })
  }
}