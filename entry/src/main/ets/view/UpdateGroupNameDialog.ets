import { WKIM } from '@ohos/wkim'
import { WKLogger } from '@ohos/wkim/src/main/ets/common/WKLogger'
import { WKChannelType } from '@ohos/wkim/src/main/ets/entity/Bean'
import { HttpUtil } from '../service/HttpUtil'

@Preview
@CustomDialog
export struct UpdateGroupNameDialog {
  @State textValue: string = ''
  controller: CustomDialogController
  channelId: string = ''
  channelType: number = WKChannelType.personal

  constructor(channelId: string, channelType: number) {
    super()
    this.channelId = channelId
    this.channelType = channelType
  }

  build() {
    Column() {
      Text('修改群名称').fontSize(20).margin({ top: 10, bottom: 10 })
      TextInput({ placeholder: '请输入群名称', text: this.textValue }).height(60).width('90%')
        .onChange((value: string) => {
          this.textValue = value
        })
      Flex({ justifyContent: FlexAlign.SpaceAround }) {
        Button('取消')
          .onClick(() => {
            this.controller.close()
          }).backgroundColor(0xffffff).fontColor('#ff9a9a9b')
        Button('确定')
          .onClick(() => {
            this.controller.close()
            if (this.textValue === '') {
              return
            }
            HttpUtil.updateGroupName(this.channelId,this.textValue)
          }).backgroundColor(0xffffff).fontColor('#ff0346ea')
      }.margin({ bottom: 10 })
    }.borderRadius(10).backgroundColor('#fff')
  }
}