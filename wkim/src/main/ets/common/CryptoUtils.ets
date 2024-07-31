import cryptoFramework from '@ohos.security.cryptoFramework'
import util from '@ohos.util'
import { CommonUtil } from './CommonUtil'

let cipherAlgName = 'AES128|CBC|PKCS7'
let publicKey = new Uint8Array()
let privateKey = new Uint8Array()
let header = new Uint8Array()
let aesKey: string = ''
let salt: string = ''

export class CryptoUtils {
  private constructor() {
  }

  static getPublicKey() {
    if (publicKey.length <= 32) {
      return new util.Base64Helper().encodeToStringSync(publicKey)
    }
    let key = publicKey.subarray(12, publicKey.length)
    return new util.Base64Helper().encodeToStringSync(key)
  }

  static async init() {
    let result = cryptoFramework.createAsyKeyGenerator('X25519')
    let promiseKeyPair = await result.generateKeyPair()
    publicKey = promiseKeyPair.pubKey.getEncoded().data
    privateKey = promiseKeyPair.priKey.getEncoded().data
    if (publicKey.length > 32) {
      header = publicKey.slice(0, 12)
    }
  }

  static setServerKeyAndSalt(serverKey: string, _salt: string) {
    salt = _salt
    let data = new util.Base64Helper().decodeSync(serverKey)
    let serverKeyBytes:Uint8Array
    if (header.length>0) {
      serverKeyBytes  = new Uint8Array([...header, ...data])
    }else {
      serverKeyBytes  = new Uint8Array([...data])
    }
    let asyKey = cryptoFramework.createAsyKeyGenerator('X25519')
    let pubKeyPair = asyKey.convertKeySync({ data: serverKeyBytes }, null)
    let priKeyPair = asyKey.convertKeySync(null, { data: privateKey })
    let aesKeyData =
      cryptoFramework.createKeyAgreement('X25519').generateSecretSync(priKeyPair.priKey, pubKeyPair.pubKey)
    let key = CryptoUtils.digestMD5(new util.Base64Helper().encodeSync(aesKeyData.data))
    if (key.length > 16) {
      aesKey = key.substring(0, 16)
    } else {
      aesKey = key
    }
  }

  static digestMD5(data: Uint8Array): string {
    let md = cryptoFramework.createMd('MD5')
    md.updateSync({ data: data })
    let s = CryptoUtils.uint8ArrayToHexStr(md.digestSync().data)
    return s
  }

  static uint8ArrayToHexStr(data: Uint8Array): string {
    let hexString = ""
    let i: number
    for (i = 0; i < data.length; i++) {
      let char = ('00' + data[i].toString(16)).slice(-2)
      hexString += char
    }
    return hexString
  }

  static getIV() {
    let ivParam: cryptoFramework.IvParamsSpec = {
      algName: 'IvParamsSpec',
      iv: {
        data: CommonUtil.stringToUint8Array(salt)
      },
    }
    return ivParam
  }

  static aesEncrypt(content: string): string {
    let symKeyGenerator = cryptoFramework.createSymKeyGenerator("AES128")
    let cipher = cryptoFramework.createCipher(cipherAlgName)
    let key = symKeyGenerator.convertKeySync({
      data: CommonUtil.stringToUint8Array(aesKey)
    })
    cipher.initSync(cryptoFramework.CryptoMode.ENCRYPT_MODE, key, CryptoUtils.getIV())
    let result = cipher.doFinalSync({
      data: CommonUtil.stringToUint8Array(content)
    })
    let data =  new util.Base64Helper().encodeToStringSync(result.data)
    return data
  }

  static aesDecrypt(content: string): string {
    let symKeyGenerator = cryptoFramework.createSymKeyGenerator('AES128')
    let cipher = cryptoFramework.createCipher(cipherAlgName)
    let key = symKeyGenerator.convertKeySync({
      data: CommonUtil.stringToUint8Array(aesKey)
    })
    let d = new util.Base64Helper().decodeSync(content)
    cipher.initSync(cryptoFramework.CryptoMode.DECRYPT_MODE, key, CryptoUtils.getIV())
    let result = cipher.doFinalSync({
      data: d
    })
    return CommonUtil.uint8ArrayToString(result.data)
  }
}