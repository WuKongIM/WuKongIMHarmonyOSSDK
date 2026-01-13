import util from '@ohos.util';
import { JSON } from '@kit.ArkTS';
import { WKLogger } from './WKLogger';

export class CommonUtil {
  static strIsEmpty(str: Object): boolean {
    if (str === null || str === undefined) {
      return true
    }
    return str.toString().length == 0
  }

  static strIsUnEmpty(str: Object): boolean {
    return str !== null && str !== undefined && str.toString().length > 0
  }

  static stringToUint8Array(str: string) {
    // let arr: number[] = [];
    // for (let i = 0, j = str.length; i < j; ++i) {
    //   arr.push(str.charCodeAt(i));
    // }
    // return new Uint8Array(arr);

    let textEncoder = new util.TextEncoder();
    //获取点流并发出 UTF-8 字节流 TextEncoder 的所有实例仅支持 UTF-8 编码
    return textEncoder.encodeInto(str);
  }

  static stringToNumbers(str: string): number[] {
    // let arr: number[] = [];
    // for (let i = 0, j = str.length; i < j; ++i) {
    //   arr.push(str.charCodeAt(i));
    // }
    // return arr

    let textEncoder = new util.TextEncoder();
    //获取点流并发出 UTF-8 字节流 TextEncoder 的所有实例仅支持 UTF-8 编码
    let t = textEncoder.encodeInto(str);
    return Array.of(...t)
  }

  static uint8ArrayToString(array: Uint8Array) {
    // let arrayString = '';
    // for (let i = 0; i < array.length; i++) {
    //   arrayString += String.fromCharCode(array[i]);
    // }
    // return arrayString;

    let textDecoder = util.TextDecoder.create("utf-8", { ignoreBOM: true })
    return textDecoder.decodeToString(new Uint8Array(array), { stream: false });
  }

  static jsonToRecord(jsonStr: string): Record<string, Object> | undefined {
    try {
      let json = JSON.parse(jsonStr) as Record<string, Object>
      return json
    } catch (e) {
      return undefined
    }
  }

  static jsonToRecordArray(jsonStr: string): Record<string, Object>[] | undefined {
    try {
      let json = JSON.parse(jsonStr) as Record<string, Object>[]
      return json
    } catch (e) {
      return undefined
    }
  }

  static isJSONStr(str: string): boolean {
    try {
      JSON.parse(str);
      return true;
    } catch (error) {
      return false;
    }
  }

  static readNumber(json: Record<string, Object>, key: string): number {
    let v = json[key]
    if (v !== null && v !== undefined) {
      return v as number
    }
    return 0
  }

  static readString(json: Record<string, Object>, key: string): string | undefined {
    let v = json[key]
    if (v !== undefined && v !== null) {
      return v as string
    }
    return undefined
  }

  static readJson(json: Record<string, Object>, key: string): Record<string, Object> | undefined {
    let v = json[key]
    try {
      if (v === undefined || v === null) {
        return undefined
      }
      let json = JSON.parse(JSON.stringify(v)) as Record<string, Object>
      return json
    } catch (e) {
      WKLogger.error('异常解析,method:readJson,key:', key)
      return undefined
    }
  }

  static readArr(json: Record<string, Object>, key: string): Record<string, Object>[] | undefined {
    let v = json[key]
    try {
      if (v !== undefined && v !== null) {
        let arr = JSON.parse(JSON.stringify(v)) as Record<string, Object>[]
        return arr
      }
      return undefined
    } catch (e) {
      return undefined
    }
  }

  static removeDuplicates(array: string[]) {
    return array.filter((item, index) => {
      return array.indexOf(item) === index
    })
  }
}