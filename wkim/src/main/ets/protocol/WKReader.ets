import { CommonUtil } from '../common/CommonUtil'

export class WKReader {
  private data: Uint8Array
  private readonly byteData: DataView
  private offset: number = 0

  constructor(_data: Uint8Array) {
    this.data = _data
    this.byteData = new DataView(_data.buffer)
  }

  readByte(): number {
    let d = this.data[this.offset]
    this.offset++
    return d
  }

  readUint8(): number {
    let v = this.byteData.getUint8(this.offset)
    this.offset++
    return v
  }

  readUint16(): number {
    let v = this.byteData.getUint16(this.offset)
    this.offset += 2
    return v
  }


  readUint32(): number {
    let v = this.byteData.getUint32(this.offset)
    this.offset += 4;
    return v;
  }


  readUint64(): BigInt {
    let tempData = this.data.subarray(this.offset, this.offset + 8)
    this.offset += 8
    let n = BigInt(0)
    for (let i = 0; i < tempData.length; i++) {
      let d = BigInt(Math.pow(2, (tempData.length - i - 1) * 8))
      n = n + BigInt(tempData[i]) * d
    }
    return n
  }

  readString(): string {
    let len = this.readUint16()
    if (len <= 0) {
      return "";
    }
    let d = this.data.subarray(this.offset, this.offset + len);
    this.offset += len;
    return CommonUtil.uint8ArrayToString(d)
  }


  readVariableLength(): number {
    let multiplier = 0;
    let rLength = 0;
    while (multiplier < 27) {
      let b = this.readUint8();
      rLength = rLength | ((b & 127) << multiplier);
      if ((b & 128) == 0) {
        break;
      }
      multiplier += 7;
    }
    return rLength;
  }

  readRemaining(): Uint8Array {
    let tempData = this.data.subarray(this.offset)
    this.offset = this.data.length
    return tempData
  }
}