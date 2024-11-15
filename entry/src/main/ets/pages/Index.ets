import { promptAction, router } from '@kit.ArkUI'
import { HttpUtil } from '../service/HttpUtil'
import { IMUtil } from '../service/IMUtil'

@Entry
@Component
struct Index {
  @State message: string = 'Hello World'
  @State apiURL: string = 'http://62.234.8.38:7090/v1'
  @State uid: string = 'sll'
  @State token: string = 'sll'

  build() {
    Row() {
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
          HttpUtil.login(this.apiURL, this.uid, this.token, async (code) => {
            if (code == 200) {
             await IMUtil.init(this.uid,this.token)
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
    .height('100%')
  }
}