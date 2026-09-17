// Run actual ArkTS entity/DB/manager code against SQLite with the SDK's migration SQL.
// Node 22.13+; the adapter replaces only HarmonyOS RdbStore and logging.
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { DatabaseSync } = require('node:sqlite');
const ts = require(process.env.TYPESCRIPT_PATH ||
  '/Applications/DevEco-Studio.app/Contents/tools/hvigor/hvigor/node_modules/typescript');

function load(relative, bindings = {}) {
  const file = path.join(__dirname, '../src/main/ets', relative + '.ets');
  const tree = ts.createSourceFile(file, fs.readFileSync(file, 'utf8'), ts.ScriptTarget.Latest, true);
  const body = tree.statements.filter(node => !ts.isImportDeclaration(node))
    .map(node => node.getFullText(tree)).join('\n');
  const exports = {};
  vm.runInNewContext(ts.transpileModule(body, { compilerOptions: {
    module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2021
  } }).outputText, { ...bindings, exports }, { filename: file });
  return exports;
}

function setup(t) {
  const sqlite = new DatabaseSync(':memory:');
  t.after(() => sqlite.close());
  sqlite.exec(fs.readFileSync(path.join(__dirname, '../src/main/resources/rawfile/202109271118.sql'), 'utf8'));
  const h = { available: true, fail: '', opened: 0, closed: 0, refreshes: 0 };
  class RdbPredicates {
    constructor(table) { this.table = table; this.keys = []; this.args = []; }
    equalTo(key, value) { this.keys.push(key); this.args.push(value); return this; }
    and() { return this; }
  }
  const store = {
    beginTransaction() { sqlite.exec('BEGIN'); },
    commit() {
      if (h.fail === 'commit') throw Error('commit failed');
      sqlite.exec('COMMIT');
    },
    rollBack() { sqlite.exec('ROLLBACK'); },
    querySqlSync(sql, args = []) {
      if (h.fail === 'query') throw Error('query failed');
      const stmt = sqlite.prepare(sql), rows = stmt.all(...args);
      const keys = stmt.columns().map(column => column.name);
      let index = -1;
      h.opened++;
      return {
        goToNextRow() { return ++index < rows.length; },
        getColumnIndex(key) { return keys.indexOf(key); },
        getString(i) { return rows[index][keys[i]] ?? ''; },
        close() { h.closed++; }
      };
    },
    updateSync(values, predicates) {
      if (h.fail === 'update') throw Error('update failed');
      const assignments = Object.keys(values).map(key => `${key}=?`).join(',');
      const where = predicates.keys.map(key => `${key}=?`).join(' AND ');
      return sqlite.prepare(`UPDATE ${predicates.table} SET ${assignments} WHERE ${where}`)
        .run(...Object.values(values), ...predicates.args).changes;
    },
    insertSync(table, values) {
      if (h.fail === 'insert') throw Error('insert failed');
      if (h.fail === 'insert-result') return -1;
      const keys = Object.keys(values);
      return sqlite.prepare(`INSERT INTO ${table} (${keys.join(',')}) VALUES (${keys.map(() => '?').join(',')})`)
        .run(...Object.values(values)).lastInsertRowid;
    }
  };
  const bindings = {
    WKLogger: { error() {} }, relationalStore: { RdbPredicates },
    WKDBHelper: { shared: {
      getDB: () => h.available ? store : undefined,
      safeClose: result => result?.close(), safeRollBack: () => store.rollBack()
    } },
    ...load('common/StringBuilder'), ...load('entity/Bean')
  };
  Object.assign(bindings, load('db/WKDBConst', bindings));
  Object.assign(bindings, load('db/RobotDB', bindings));
  Object.assign(bindings, load('manager/RobotManager', bindings));
  const sdk = load('WKIM', { ...bindings, WKConfig: class {} }).WKIM.shared;
  const manager = sdk.robotManager(), db = bindings.RobotDB.shared;
  function menu(robotId = 'bot', cmd = '/help', extra = {}) {
    return Object.assign(new bindings.WKRobotMenu(), {
      robotId, cmd, remark: '帮助', type: 'command', createdAt: 'created', updatedAt: 'updated'
    }, extra);
  }
  const rows = () => sqlite.prepare('SELECT * FROM robot_menu ORDER BY id').all();
  return Object.assign(h, { sqlite, manager, db, menu, rows });
}

test('SDK entry saves and queries menu fields; refresh runs after commit', t => {
  const h = setup(t), menu = h.menu("bot'1", '/帮助');
  h.manager.addOnRefreshRobotMenu('page', () => {
    // Starting a transaction succeeds only after the write transaction has ended.
    h.sqlite.exec('BEGIN; ROLLBACK');
    assert.equal(h.manager.getRobotMenus(menu.robotId)[0].remark, '帮助');
    h.refreshes++;
  });
  assert.equal(h.manager.saveOrUpdateRobotMenus([menu]), true);
  assert.equal(h.refreshes, 1);
  const result = h.manager.getRobotMenus(menu.robotId)[0];
  assert.deepEqual(JSON.parse(JSON.stringify(result)), JSON.parse(JSON.stringify(menu)));
  assert.equal(h.db.isExistMenu(menu.robotId, menu.cmd), true);
  assert.equal(h.db.isExistMenu(menu.robotId, '/missing'), false);
  assert.equal(h.opened, h.closed);
});

test('upsert matches both keys, preserves id/creation time and unmentioned menus', t => {
  const h = setup(t);
  h.manager.saveOrUpdateRobotMenus([h.menu(), h.menu('bot', '/old'), h.menu('other')]);
  const id = h.rows()[0].id;
  const updated = h.menu('bot', '/help', { type: 'link', remark: '新版', createdAt: 'ignored', updatedAt: 'new' });
  assert.equal(h.manager.saveOrUpdateRobotMenus([updated, updated]), true);
  assert.equal(h.rows().length, 3);
  assert.equal(h.rows()[0].id, id);
  assert.equal(h.rows()[0].created_at, 'created');
  assert.equal(h.rows()[0].updated_at, 'new');
  assert.equal(h.rows()[0].type, 'link');
  assert.equal(h.rows()[0].remark, '新版');
  assert.equal(h.manager.getRobotMenus('other')[0].remark, '帮助');
  assert.equal(h.manager.getRobotMenus(['bot', 'other', 'bot']).length, 3);
  assert.equal(h.manager.getRobotMenus([]).length, 0);
  assert.equal(h.manager.getRobotMenus('missing').length, 0);
});

test('empty save refreshes without deleting; no listeners and keyed replacement/removal are safe', t => {
  const h = setup(t);
  assert.equal(h.manager.saveOrUpdateRobotMenus([h.menu()]), true);
  h.manager.addOnRefreshRobotMenu('', () => assert.fail('empty key'));
  h.manager.addOnRefreshRobotMenu('page', () => assert.fail('replaced callback'));
  h.manager.addOnRefreshRobotMenu('page', () => h.refreshes++);
  assert.equal(h.manager.saveOrUpdateRobotMenus([]), true);
  assert.equal(h.refreshes, 1);
  assert.equal(h.rows().length, 1);
  h.manager.removeRefreshRobotMenu('page');
  h.manager.removeRefreshRobotMenu('missing');
  h.manager.saveOrUpdateRobotMenus([]);
  assert.equal(h.refreshes, 1);
});

test('listener errors and registration during callbacks do not disrupt current notifications', t => {
  const h = setup(t), calls = [];
  h.manager.addOnRefreshRobotMenu('throw', () => { throw Error('listener'); });
  h.manager.addOnRefreshRobotMenu('register', () => {
    calls.push('register');
    h.manager.addOnRefreshRobotMenu('next', () => calls.push('next'));
  });
  h.manager.addOnRefreshRobotMenu('last', () => calls.push('last'));
  assert.equal(h.manager.saveOrUpdateRobotMenus([]), true);
  assert.deepEqual(calls, ['register', 'last']);
});

for (const failure of ['update', 'insert', 'insert-result', 'commit']) {
  test(`${failure} failure rolls back the entire batch and suppresses refresh`, t => {
    const h = setup(t);
    h.manager.saveOrUpdateRobotMenus([h.menu()]);
    h.manager.addOnRefreshRobotMenu('page', () => h.refreshes++);
    h.fail = failure;
    assert.equal(h.manager.saveOrUpdateRobotMenus([
      h.menu('bot', '/help', { remark: 'changed' }), h.menu('bot', '/new')
    ]), false);
    assert.equal(h.refreshes, 0);
    assert.equal(h.rows().length, 1);
    assert.equal(h.rows()[0].remark, '帮助');
    h.fail = '';
    assert.equal(h.manager.saveOrUpdateRobotMenus([h.menu('bot', '/retry')]), true);
  });
}

test('plain inserts retain duplicates and roll back on a later constraint failure', t => {
  const h = setup(t);
  assert.equal(h.db.insertMenus([h.menu(), h.menu()]), true);
  assert.equal(h.rows().length, 2);
  assert.equal(h.db.insertMenus([h.menu('new'), h.menu('bad', '/bad', { type: null })]), false);
  assert.equal(h.rows().length, 2);
  assert.equal(h.db.insertMenus([]), true);
});

test('unavailable DB and query failures are safe and do not leak result sets', t => {
  const h = setup(t);
  h.manager.addOnRefreshRobotMenu('page', () => h.refreshes++);
  h.available = false;
  assert.equal(h.manager.saveOrUpdateRobotMenus([h.menu()]), false);
  assert.equal(h.manager.getRobotMenus('bot').length, 0);
  assert.equal(h.db.isExistMenu('bot', '/help'), false);
  assert.equal(h.refreshes, 0);
  h.available = true;
  h.fail = 'query';
  assert.equal(h.manager.getRobotMenus('bot').length, 0);
  assert.equal(h.db.isExistMenu('bot', '/help'), false);
  assert.equal(h.opened, h.closed);
});
