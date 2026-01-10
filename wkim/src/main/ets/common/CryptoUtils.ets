import cryptoFramework from '@ohos.security.cryptoFramework'
import util from '@ohos.util'
import { CommonUtil } from './CommonUtil'
import { WKLogger } from './WKLogger'


export class CryptoUtils {
  static readonly shared: CryptoUtils = new CryptoUtils()
  private readonly TAG = 'CryptoUtils'
  private readonly cipherAlgName = 'AES128|CBC|PKCS7'
  private readonly KEY_GENERATOR = 'X25519'
  private readonly AES_KEY_LENGTH = 16
  private publicKey = new Uint8Array()
  private privateKey = new Uint8Array()
  private header = new Uint8Array()
  private aesKey: string = ''
  private salt: string = ''
  private _isInitialized: boolean = false

  private constructor() {
  }

  get isReady(): boolean {
    return this._isInitialized && this.aesKey.length > 0 && this.salt.length > 0
  }

  public clear(): void {
    this.publicKey.fill(0)
    this.privateKey.fill(0)
    this.header.fill(0)
    this.publicKey = new Uint8Array()
    this.privateKey = new Uint8Array()
    this.header = new Uint8Array()
    this.aesKey = ''
    this.salt = ''
    this._isInitialized = false
    WKLogger.debug(`${this.TAG} 密钥已清空`)
  }

  getPublicKey() {
    if (this.publicKey.length <= 32) {
      return new util.Base64Helper().encodeToStringSync(this.publicKey)
    }
    let key = this.publicKey.subarray(12, this.publicKey.length)
    return new util.Base64Helper().encodeToStringSync(key)
  }

  async init() {
    try {
      let result = cryptoFramework.createAsyKeyGenerator(this.KEY_GENERATOR)
      let promiseKeyPair = await result.generateKeyPair()
      this.publicKey = promiseKeyPair.pubKey.getEncoded().data
      this.privateKey = promiseKeyPair.priKey.getEncoded().data
      if (this.publicKey.length > 32) {
        this.header = this.publicKey.slice(0, 12)
      }
      this._isInitialized = true
      WKLogger.info(`${this.TAG} 初始化密钥成功`)
    } catch (error) {
      WKLogger.error(`${this.TAG} 初始化密钥失败: ${error}`)
    }
  }

  setServerKeyAndSalt(serverKey: string, _salt: string) {
    this.salt = _salt
    let data = new util.Base64Helper().decodeSync(serverKey)
    let serverKeyBytes: Uint8Array
    if (this.header.length > 0) {
      serverKeyBytes = new Uint8Array([...this.header, ...data])
    } else {
      serverKeyBytes = new Uint8Array([...data])
    }
    try {
      let asyKey = cryptoFramework.createAsyKeyGenerator(this.KEY_GENERATOR)
      let pubKeyPair = asyKey.convertKeySync({ data: serverKeyBytes }, null)
      let priKeyPair = asyKey.convertKeySync(null, { data: this.privateKey })
      let aesKeyData =
        cryptoFramework.createKeyAgreement(this.KEY_GENERATOR).generateSecretSync(priKeyPair.priKey, pubKeyPair.pubKey)
      let key = this.digestMD5(new util.Base64Helper().encodeSync(aesKeyData.data))
      if (key.length > this.AES_KEY_LENGTH) {
        this.aesKey = key.substring(0, this.AES_KEY_LENGTH)
      } else {
        this.aesKey = key
      }
      WKLogger.debug(`${this.TAG} 安全码设置成功`)
    } catch (error) {
      WKLogger.error(`${this.TAG} 生成密钥错误:${error}`)
    }
  }

  digestMD5(data: Uint8Array): string {
    try {
      let md = cryptoFramework.createMd('MD5')
      md.updateSync({ data: data })
      let s = this.uint8ArrayToHexStr(md.digestSync().data)
      return s
    } catch (error) {
      WKLogger.error(`${this.TAG} digestMD5错误：${error}`)
      return ''
    }
  }

  uint8ArrayToHexStr(data: Uint8Array): string {
    let hexString = ""
    let i: number
    for (i = 0; i < data.length; i++) {
      let char = ('00' + data[i].toString(16)).slice(-2)
      hexString += char
    }
    return hexString
  }

  getIV() {
    let ivParam: cryptoFramework.IvParamsSpec = {
      algName: 'IvParamsSpec',
      iv: {
        data: CommonUtil.stringToUint8Array(this.salt)
      },
    }
    return ivParam
  }

  aesEncrypt(content: string): string {
    if (!this.isReady) {
      WKLogger.error(`${this.TAG} 未初始化密钥，无法进行加密`)
      return ''
    }
    try {
      let symKeyGenerator = cryptoFramework.createSymKeyGenerator("AES128")
      let cipher = cryptoFramework.createCipher(this.cipherAlgName)
      let key = symKeyGenerator.convertKeySync({
        data: CommonUtil.stringToUint8Array(this.aesKey)
      })
      cipher.initSync(cryptoFramework.CryptoMode.ENCRYPT_MODE, key, this.getIV())
      let result = cipher.doFinalSync({
        data: CommonUtil.stringToUint8Array(content)
      })
      let data = new util.Base64Helper().encodeToStringSync(result.data)
      return data
    } catch (error) {
      WKLogger.error(`${this.TAG} aes加密错误:${error}`)
      return ''
    }
  }

  aesDecrypt(content: string): string {
    if (!this.isReady) {
      WKLogger.error(`${this.TAG} 未初始化密钥，无法进行解密`)
      return ''
    }
    try {
      let symKeyGenerator = cryptoFramework.createSymKeyGenerator('AES128')
      let cipher = cryptoFramework.createCipher(this.cipherAlgName)
      let key = symKeyGenerator.convertKeySync({
        data: CommonUtil.stringToUint8Array(this.aesKey)
      })
      let d = new util.Base64Helper().decodeSync(content)
      cipher.initSync(cryptoFramework.CryptoMode.DECRYPT_MODE, key, this.getIV())
      let result = cipher.doFinalSync({
        data: d
      })
      return CommonUtil.uint8ArrayToString(result.data)
    } catch (error) {
      WKLogger.error(`${this.TAG} aes解码错误:${error}`)
      return ''
    }
  }
}