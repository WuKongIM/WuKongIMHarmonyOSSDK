// Runs the actual manager implementations; only platform, storage and transport are doubled.
// Run: node --test wkim/tests/cmd-persistence.test.cjs
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require(process.env.TYPESCRIPT_PATH ||
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript');

function setup() {
  const calls = { commands: [], inserts: [], extras: [], reactions: [], conversations: [],
    refreshes: [], newMessages: [], messageRefreshes: [], acks: [], sendStatus: [], completed: [] };
  const rows = new Map();
  class WKMsg {
    header = { noPersist: false, syncOnce: false, redDot: true };
    clientSeq = 0;
    contentType = 0;
    isDeleted = 0;
    fromUID = 'sender';
    channelId = 'group';
    channelType = 2;
  }
  const shared = { config: { uid: 'self', provider: {}, protocol: { decode: packet => packet } },
    cmdManager: () => ({ handle: json => calls.commands.push(json) }) };
  const bindings = {
    WKIM: { shared }, WKMsg, WKConversation: class {}, HashMap: Map,
    WKMsgContentType: { Text: 1, Image: 2, InsideMsg: 99, ContentFormatError: 97, SignalDecryptError: 98 },
    WKChannelType: { personal: 1, group: 2, community: 3, communityTopic: 4 },
    WKSendMsgResult: { success: 1 }, WKConnectStatus: { fail: 0 },
    WKPacketType: { recv: 3, connAck: 2, sendAck: 5, disconnect: 7, pong: 9 },
    WKRecvAckPacket: class { header = {}; }, WKSendAckPacket: class {},
    SyncOptions: class { constructor(...args) { this.args = args; } },
    WKLogger: { error() {}, info() {}, debug() {} },
    CommonUtil: {
      strIsEmpty: value => !value, strIsUnEmpty: value => !!value,
      jsonToRecord: value => { try { return JSON.parse(value); } catch { return undefined; } },
      readString: (value, key) => value[key], readNumber: (value, key) => value[key] || 0,
      stringToUint8Array: value => new TextEncoder().encode(value)
    },
    StringBuilder: class { append() {} toString() { return ''; } },
    CryptoUtils: { shared: { aesEncrypt: () => 'encrypted', aesDecrypt: value => value,
      digestMD5: () => 'valid-key' } },
    MessageDB: { shared: {
      queryWithClientMsgNo: client => rows.get(client),
      insert: msg => { calls.inserts.push(msg); return 42; },
      inserts: msgs => { calls.inserts.push(...msgs); return {
        newMessages: msgs, confirmedMessages: [], updatedMessages: []
      }; },
      insertExtras: extras => calls.extras.push(...extras)
    } },
    ConversationDB: { shared: {
      queryLastMsgSeqs: () => '',
      insertWithWKMsg: msg => { calls.conversations.push(msg); return { lastClientMsgNo: msg.clientMsgNo }; },
      insertOrReplaces: list => calls.conversations.push(...list)
    } }
  };
  function load(name) {
    const file = path.join(__dirname, '../src/main/ets/manager', `${name}.ets`);
    const source = fs.readFileSync(file, 'utf8');
    const tree = ts.createSourceFile(`${name}.ts`, source, ts.ScriptTarget.Latest, true);
    const body = tree.statements.filter(node => !ts.isImportDeclaration(node))
      .map(node => node.getFullText(tree)).join('\n');
    const result = ts.transpileModule(body, { compilerOptions: {
      module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021
    }, reportDiagnostics: true });
    assert.equal(result.diagnostics.filter(d => d.category === ts.DiagnosticCategory.Error).length, 0);
    const exports = {};
    vm.runInNewContext(result.outputText, { ...bindings, exports }, { filename: file });
    return exports[name].shared;
  }
  const messages = load('MessageManager');
  messages.getMessageModel = () => ({ displayText: () => 'ordinary' });
  messages.pushNewMsgs = list => calls.newMessages.push(...list);
  messages.refreshMessage = msg => calls.messageRefreshes.push(msg);
  messages.setSendStatus = ack => calls.sendStatus.push(ack);
  messages.saveReactions = list => calls.reactions.push(...list);
  shared.messageManager = () => messages;
  const conversations = load('ConversationManager');
  conversations.setRefresh = list => calls.refreshes.push(...list);
  shared.conversationManager = () => conversations;
  const connection = load('ConnectionManager');
  connection.sendPacket = packet => calls.acks.push(packet);
  connection.completeSending = seq => calls.completed.push(seq);
  shared.connectionManager = () => connection;
  function message(type, client = `client-${type}`) {
    return Object.assign(new WKMsg(), { clientMsgNo: client, messageId: '123', messageSeq: 10,
      content: JSON.stringify({ type, content: 'body', cmd: 'channelUpdate', param: {} }),
      remoteExtra: { messageId: client }, reactionList: [{ messageId: client }] });
  }
  function receive(type, noPersist = false, syncOnce = false, messageId = 123n) {
    connection.decodePacket({ header: { packetType: 3, noPersist, syncOnce, redDot: true },
      messageId, messageSeq: 10, clientMsgNo: `client-${type}`, messageTime: 100,
      expire: 0, fromUID: 'sender', channelId: 'group', channelType: 2,
      payload: message(type).content, msgKey: 'valid-key', toString: () => 'packet' });
  }
  return { calls, rows, shared, messages, conversations, message, receive };
}

for (const noPersist of [false, true]) {
  for (const syncOnce of [false, true]) {
    test(`实时 CMD 执行一次，不入库或刷新会话，保留 ACK 规则 (${noPersist}/${syncOnce})`, () => {
      const h = setup();
      h.rows.set('client-99', { status: 0 });
      h.receive(99, noPersist, syncOnce);
      assert.equal(h.calls.commands.length, 1);
      assert.equal(h.calls.commands[0].channel_id, 'group');
      assert.equal(h.calls.commands[0].channel_type, 2);
      for (const key of ['inserts', 'conversations', 'refreshes', 'newMessages',
        'messageRefreshes', 'completed', 'sendStatus']) {
        assert.equal(h.calls[key].length, 0, key);
      }
      assert.equal(h.calls.acks.length, noPersist ? 0 : 1);
      if (!noPersist) {
        assert.equal(h.calls.acks[0].messageId, 123n);
        assert.equal(h.calls.acks[0].header.syncOnce, syncOnce);
      }
    });
  }
}

test('零消息 ID 返回 UI 时为空字符串，接收 ACK 仍使用原始数值', () => {
  const h = setup();
  h.receive(1, false, false, 0n);
  assert.equal(h.calls.newMessages[0].messageId, '');
  assert.equal(h.calls.inserts[0].messageId, '');
  assert.equal(h.calls.acks[0].messageId, 0n);
});

test('普通文本及 1001 系统消息仍入库、更新会话、通知 UI 并回 ACK', () => {
  const h = setup();
  h.receive(1);
  h.receive(1001);
  assert.deepEqual(h.calls.inserts.map(msg => msg.contentType), [1, 1001]);
  assert.equal(h.calls.conversations.length, 2);
  assert.equal(h.calls.newMessages.length, 2);
  assert.equal(h.calls.acks.length, 2);
  assert.equal(h.calls.commands.length, 0);
});

test('普通消息 noPersist/syncOnce 不入库，但继续通知 UI', () => {
  const h = setup();
  h.receive(1, true, false);
  h.receive(1, false, true);
  assert.equal(h.calls.inserts.length, 0);
  assert.equal(h.calls.conversations.length, 0);
  assert.equal(h.calls.newMessages.length, 2);
  assert.equal(h.calls.acks.length, 1);
});

test('频道历史按解析后的类型排除 CMD 及扩展、回应，保留普通消息及原响应', async () => {
  const h = setup();
  const response = { msgs: [h.message(99), h.message(1001), h.message(1)] };
  h.shared.config.provider.syncMessageCallback = async () => response;
  const result = await h.messages.syncChannelMsgs({}, 0, 0, 0, 10);
  assert.equal(result, response);
  assert.deepEqual(h.calls.inserts.map(msg => msg.contentType), [1001, 1]);
  assert.deepEqual(h.calls.extras.map(extra => extra.messageId), ['client-1001', 'client-1']);
  assert.deepEqual(h.calls.reactions.map(item => item.messageId), ['client-1001', 'client-1']);
  assert.equal(h.calls.commands.length, 1);
});

test('只有 CMD 的频道历史执行指令且不调用消息/扩展入库', async () => {
  const h = setup();
  h.shared.config.provider.syncMessageCallback = async () => ({ msgs: [h.message(99)] });
  await h.messages.syncChannelMsgs({}, 0, 0, 0, 10);
  assert.equal(h.calls.commands.length, 1);
  assert.equal(h.calls.inserts.length, 0);
  assert.equal(h.calls.extras.length, 0);
  assert.equal(h.calls.reactions.length, 0);
});

test('最近会话同步按正文解析类型后过滤 CMD，保留服务端正常末条和未读', async () => {
  const h = setup();
  h.shared.config.provider.syncConversationCallback = async () => ({ conversations: [{
    channelId: 'group', channelType: 2, lastClientMsgNo: 'client-1001', lastMsgSeq: 10,
    unread: 3, timestamp: 100, recents: [h.message(1001), h.message(99)]
  }] });
  await h.conversations.sync();
  assert.equal(h.calls.commands.length, 1);
  assert.deepEqual(h.calls.inserts.map(msg => msg.contentType), [1001]);
  assert.deepEqual(h.calls.extras.map(extra => extra.messageId), ['client-1001']);
  assert.deepEqual(h.calls.reactions.map(item => item.messageId), ['client-1001']);
  assert.equal(h.calls.conversations[0].lastClientMsgNo, 'client-1001');
  assert.equal(h.calls.conversations[0].unreadCount, 3);
});
