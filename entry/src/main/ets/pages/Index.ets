import { promptAction, router } from '@kit.ArkUI'
import { GlobalContext } from '../entryability/EntryAbility'
import { HttpUtil } from '../service/HttpUtil'
import { IMUtil } from '../service/IMUtil'
import { LoginCacheUtil } from '../service/LoginCacheUtil'

@Entry
@Component
struct Index {
  @State message: string = 'Hello World'
  @State apiURL: string = 'http://62.234.8.38:7090/v1'
  @State uid: string = 'sll'
  @State token: string = 'sll'
  @State isLoading: boolean = true // 用于控制加载状态

  async aboutToAppear(): Promise<void> {
    // 读取缓存的登录信息
    let context = GlobalContext.shared.getContext()
    let loginInfo = LoginCacheUtil.getLoginInfo(context)

    if (loginInfo !== undefined) {
      // 有缓存，直接初始化 IM 并跳转，不需要调用登录接口
      this.uid = loginInfo.uid
      this.token = loginInfo.token
      this.apiURL = loginInfo.apiURL
      // 设置请求 URL（HttpUtil 需要用到）
     HttpUtil.setURL(this.apiURL)
      await IMUtil.init(this.uid, this.token, context)
      router.replaceUrl({
        url: 'pages/Main',
        params: {
          'uid': this.uid,
          'token': this.token
        }
      })
    } else {
      // 没有缓存，显示登录界面
      this.isLoading = false
    }
  }

  build() {
    Row() {
      if (this.isLoading) {
        // 加载中状态
        Column() {
          LoadingProgress()
            .width(60)
            .height(60)
            .color('#007AFF')
          Text('正在加载...')
            .fontSize(16)
            .fontColor('#666')
            .margin({ top: 16 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        // 登录界面
        Column() {
          Text('欢迎登录悟空IM').fontSize(35).margin({
          bottom: 10,
        }).textAlign(TextAlign.Center).width('90%')
        Text('悟空IM演示程序。当前sdk版本：1.0.2')
          .fontSize(20)
          .margin({
            bottom: 30
          })
          .textAlign(TextAlign.Center)
          .width('90%')
          .align(Alignment.Center)

        TextInput({
          placeholder: '服务器地址',
          text: this.apiURL
        })
          .margin({
            bottom: 10
          })
          .placeholderColor('#999')
          .fontColor('#000')
          .backgroundColor('#eee')
          .type(InputType.Normal)
          .onChange((v) => {
            this.apiURL = v
          })
          .width('90%')

        TextInput({
          placeholder: '登录uid【随意输入】',
          text: this.token
        })
          .margin({
            bottom: 10
          })
          .placeholderColor('#999')
          .fontColor('#000')
          .backgroundColor('#eee')
          .type(InputType.Normal)
          .onChange((v) => {
            this.token = v
          })
          .width('90%')


        TextInput({
          placeholder: '登录token【随意输入】',
          text: this.uid
        })
          .placeholderColor('#999')
          .backgroundColor('#eee')
          .fontColor('#000')
          .type(InputType.Normal)
          .onChange((v) => {
            this.uid = v
          })
          .width('90%')
        Button('登录').margin({
          top: 30
        }).onClick(() => {
          if (this.apiURL == '' || this.uid == '' || this.token == '') {
            promptAction.showToast({
              message: "请求地址，uid，token 都不能为空",
              duration: 1000,
              bottom: 100
            })
            return
          }
          let context = GlobalContext.shared.getContext()
          HttpUtil.login(this.apiURL, this.uid, this.token, async (code) => {
            if (code == 200) {
              // 保存登录信息到本地缓存
              LoginCacheUtil.saveLoginInfo(context, this.uid, this.token, this.apiURL)
              await IMUtil.init(this.uid, this.token, context)
              router.replaceUrl({
                url: 'pages/Main',
                params: {
                  'uid': this.uid,
                  'token': this.token
                }
              })
            }
          })
        }).width('90%')
        }
        .width('100%')
      }
    }
    .height('100%')
  }
}