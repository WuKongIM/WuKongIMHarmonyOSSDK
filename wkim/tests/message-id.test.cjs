// Verify the actual places where server/database IDs enter the SDK.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.env.TYPESCRIPT_PATH ||
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript');

function load(relative, bindings = {}) {
  const file = path.join(__dirname, '../src/main/ets', relative + '.ets');
  const tree = ts.createSourceFile(file, fs.readFileSync(file, 'utf8'), ts.ScriptTarget.Latest, true);
  const source = tree.statements.filter(node => !ts.isImportDeclaration(node))
    .map(node => node.getFullText(tree)).join('\n');
  const exports = {};
  vm.runInNewContext(ts.transpileModule(source, { compilerOptions: {
    module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021
  } }).outputText, { ...bindings, exports });
  return exports;
}

function setup() {
  const b = {
    WKLogger: { error() {}, info() {} }, HashMap: Map,
    DateUtil: { getCurrentSeconds: () => 0 },
    WKIM: { shared: { config: { uid: 'self', provider: {} }, messageManager: () => ({
      generateClientMsgNo: () => 'client', getMessageModel: () => undefined
    }) } },
    WKDBConst: { getString: (row, key) => row[key] ?? '', getNumber: (row, key) => row[key] ?? 0 },
    WKFormatErrorContent: class {}, WKSendAckPacket: class { messageId = ''; },
    relationalStore: { RdbPredicates: class { equalTo() { return this; } } },
    hilog: { info() {} }
  };
  for (const file of ['common/CommonUtil', 'entity/Bean', 'db/MessageDB',
    'manager/MessageManager', 'protocol/WKPacketType', 'protocol/WKReader', 'protocol/WKProtocol']) {
    Object.assign(b, load(file, b));
  }
  return b;
}

for (const id of [0n, 123n, 18446744073709551615n]) {
  test(`SENDACK ${id}: decode once, then store and notify UI`, () => {
    const b = setup(), expected = id === 0n ? '' : id.toString();
    const bytes = new Uint8Array(19), data = new DataView(bytes.buffer);
    bytes[0] = b.WKPacketType.sendAck << 4;
    bytes[1] = 17;
    data.setBigUint64(2, id);
    data.setUint32(10, 1); // clientSeq
    data.setUint32(14, 0); // messageSeq
    bytes[18] = 2; // failed send
    const packet = new b.WKProtocol().decode(bytes);
    assert.equal(packet.messageId, expected);
    let updates, uiId;
    b.WKDBHelper = { shared: { getDB: () => ({ updateSync: values => { updates = values; return 1; } }) } };
    b.MessageDB.shared.updateMsgSendStatus = ack => load('db/MessageDB', b).MessageDB.shared.updateMsgSendStatus(ack);
    b.MessageManager.shared.addSendStatusListener((_seq, messageId) => { uiId = messageId; });
    b.MessageManager.shared.setSendStatus(packet);
    assert.equal(uiId, expected);
    assert.equal(updates.message_id, expected || undefined, 'zero ACK must not overwrite an assigned ID');
  });
}

test('local defaults are empty and legacy database zero is normalized when creating WKMsg', () => {
  const b = setup();
  assert.equal(new b.WKMsg().messageId, '');
  for (const id of ['0', '', '123']) {
    assert.equal(b.MessageDB.shared.serializeWKMsg({ message_id: id }).messageId, id === '0' ? '' : id);
  }
});

test('history Provider zero is normalized during parsing, before saving and returning the response', async () => {
  const b = setup(), manager = b.MessageManager.shared;
  const msg = Object.assign(new b.WKMsg(), { messageId: '0', content: '{"type":1}' });
  const response = { msgs: [msg] };
  b.WKIM.shared.config.provider.syncMessageCallback = async () => response;
  b.MessageDB.shared.inserts = list => assert.equal(list[0].messageId, '');
  manager.getMessageModel = () => undefined;
  const result = await manager.syncChannelMsgs({}, 0, 0, 0, 10);
  assert.equal(result, response);
  assert.equal(result.msgs[0].messageId, '');
});
