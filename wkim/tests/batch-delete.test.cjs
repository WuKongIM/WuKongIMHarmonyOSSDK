// Execute the actual SDK transaction and manager methods with a transactional store double.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require('/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript');

function load(relative, name, bindings) {
  const file = path.join(__dirname, '../src/main/ets', relative + '.ets');
  const tree = ts.createSourceFile(file, fs.readFileSync(file, 'utf8'), ts.ScriptTarget.Latest, true);
  const source = tree.statements.filter(node => !ts.isImportDeclaration(node))
    .map(node => node.getFullText(tree)).join('\n');
  const exports = {};
  vm.runInNewContext(ts.transpileModule(source, { compilerOptions: {
    module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021
  } }).outputText, { ...bindings, exports });
  return exports[name].shared;
}

function setup() {
  let rows = new Map(), snapshot;
  const events = [], deleted = [], refreshes = [], queries = [], inserts = [];
  const h = { fail: '', available: true };
  class RdbPredicates { equalTo(_key, id) { this.id = id; return this; } }
  const db = {
    beginTransaction() { events.push('begin'); snapshot = structuredClone(rows); },
    querySqlSync(_sql, [id]) {
      if (h.fail === 'query') throw Error('query failed');
      const row = rows.get(id);
      return { row, goToNextRow: () => !!row && !row.isDeleted, close: () => events.push('close') };
    },
    updateSync(values, predicates) {
      if (h.fail === predicates.id) throw Error('update failed');
      const row = rows.get(predicates.id);
      row.isDeleted = values.is_deleted; row.content = values.content;
      events.push('update:' + predicates.id);
      return 1;
    },
    commit() { if (h.fail === 'commit') throw Error('commit failed'); events.push('commit'); },
    rollBack() { rows = snapshot; events.push('rollback'); }
  };
  const bindings = { HashMap: Map, WKLogger: { error() {}, info() {} },
    WKDBConst: { tableMessage: 'message', tableMessageExtra: 'message_extra' },
    WKDBHelper: { shared: { getDB: () => h.available ? db : undefined, safeClose: rs => rs?.close() } },
    relationalStore: { RdbPredicates } };
  const messageDB = load('db/MessageDB', 'MessageDB', bindings);
  messageDB.serializeWKMsg = rs => ({ ...rs.row });
  messageDB.queryMaxOrderSeqNotDeletedWithChannel = (id, type) => {
    queries.push([id, type]);
    return [...rows.values()].filter(row => row.channelId === id && row.channelType === type && !row.isDeleted)
      .sort((a, b) => b.orderSeq - a.orderSeq)[0];
  };
  const manager = load('manager/MessageManager', 'MessageManager', { ...bindings,
    MessageDB: { shared: messageDB },
    ConversationDB: { shared: { insertWithWKMsg: (msg, isSend) => {
      inserts.push([msg.clientMsgNo, isSend]); return { lastClientMsgNo: msg.clientMsgNo };
    } } },
    WKIM: { shared: { conversationManager: () => ({ setRefresh: list => {
      events.push('refresh'); refreshes.push(Array.from(list));
    } }) } }
  });
  manager.addDeletedListener(id => {
    assert.ok(events.includes('commit'), 'notifications must follow the commit');
    events.push('deleted:' + id); deleted.push(id);
  });
  function add(id, channelId = 'chat', channelType = 2, orderSeq = 1) {
    rows.set(id, { clientMsgNo: id, channelId, channelType, orderSeq, content: 'body', isDeleted: 0 });
  }
  return Object.assign(h, { manager, add, events, deleted, refreshes, queries, inserts, row: id => rows.get(id) });
}

test('one transaction, post-commit notifications and one refresh per distinct channel', () => {
  const h = setup();
  h.add('keep-group'); h.add('a', 'chat', 2, 2); h.add('b', 'chat', 2, 3);
  h.add('keep-person', 'chat', 1); h.add('c', 'chat', 1, 2);
  assert.equal(h.manager.deleteWithClientMsgNos(['a', 'b', 'a', '', 'missing', 'c']), true);
  assert.deepEqual(h.deleted, ['a', 'b', 'c']);
  assert.deepEqual(h.queries, [['chat', 2], ['chat', 1]]);
  assert.deepEqual(h.inserts, [['keep-group', true], ['keep-person', true]]);
  assert.equal(h.refreshes.length, 1);
  assert.equal(h.refreshes[0].length, 2);
  assert.equal(h.events.filter(e => e === 'begin').length, 1);
  assert.equal(h.events.filter(e => e === 'commit').length, 1);
  assert.ok(h.events.indexOf('deleted:c') < h.events.indexOf('refresh'));
  assert.equal(h.row('a').content, '');
  assert.equal(h.row('b').isDeleted, 1);
  assert.equal(h.row('keep-group').content, 'body');
});

for (const failure of ['b', 'query', 'commit']) {
  test(`transaction ${failure} failure rolls back and emits no deletion or conversation events`, () => {
    const h = setup(); h.add('a'); h.add('b'); h.fail = failure;
    assert.equal(h.manager.deleteWithClientMsgNos(['a', 'b']), false);
    assert.equal(h.row('a').isDeleted, 0);
    assert.equal(h.row('a').content, 'body');
    assert.equal(h.row('b').isDeleted, 0);
    assert.equal(h.deleted.length, 0);
    assert.equal(h.refreshes.length, 0);
    assert.ok(h.events.includes('rollback'));
  });
}

test('empty, unavailable, missing and already deleted messages do not emit notifications', () => {
  const h = setup();
  assert.equal(h.manager.deleteWithClientMsgNos(['']), true);
  assert.equal(h.events.length, 0);
  h.available = false;
  assert.equal(h.manager.deleteWithClientMsgNos(['a']), false);
  h.available = true;
  h.add('a'); h.row('a').isDeleted = 1;
  assert.equal(h.manager.deleteWithClientMsgNos(['a', 'missing']), true);
  assert.equal(h.deleted.length, 0);
  assert.equal(h.refreshes.length, 0);
});

test('deleting the last message follows Android: notify deletion, skip absent replacement', () => {
  const h = setup(); h.add('last');
  assert.equal(h.manager.deleteWithClientMsgNos(['last']), true);
  assert.deepEqual(h.deleted, ['last']);
  assert.equal(h.inserts.length, 0);
  assert.equal(h.refreshes.length, 0);
});
