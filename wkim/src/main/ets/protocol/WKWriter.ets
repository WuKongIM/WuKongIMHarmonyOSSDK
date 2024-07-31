import { CommonUtil } from '../common/CommonUtil'

export class WKWriter {
  private data: Array<number> = []
  private d32: BigInt = BigInt(4294967296)

  writeUint8(v: number) {
    this.data.push(v & 0xff)
  }

  writeUint16(v: number) {
    this.data.push((v >> 8) & 0xff)
    this.data.push(v & 0xff)
  }

  writeUint32(v: number) {
    this.data.push((v >> 24) & 0xff)
    this.data.push((v >> 16) & 0xff)
    this.data.push((v >> 8) & 0xff)
    this.data.push((v) & 0xff)
  }

  writeUint64(b: BigInt) {
    let v = b.valueOf() / (this.d32.valueOf())
    let b1 = Math.floor(Number(v).valueOf())
    let b2 = b.valueOf() % this.d32.valueOf()

    this.writeUint32(Number(b1).valueOf())
    this.writeUint32(Number(b2).valueOf())
  }

  writeBytes(bytes: number[]) {
    this.data.push(...bytes)
  }


  writeString(v: string) {
    if (v != '' && v != null) {
      let wData = CommonUtil.stringToUint8Array(v)
      this.writeUint16(wData.length)
      this.data.push(...wData)
    } else {
      this.writeUint16(0x00)
    }
  }

  toUint8List(): Uint8Array {
    return new Uint8Array(this.data)
  }

  getData(): Array<number> {
    return this.data
  }
}