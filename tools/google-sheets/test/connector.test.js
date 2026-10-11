// Tests for Code.gs, run with: node --test tools/google-sheets/test
'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { FakeSpreadsheet, loadConnector, Utilities } = require('./fake_sheets');

const TZ = 'Africa/Cairo';
const date = (iso) => Utilities.parseDate(iso, TZ, 'yyyy-MM-dd');
const VISITS = 'سجل الزيارات';
const CASES = 'بيانات الحالات';
const LISTS = 'قوائم';

/** A spreadsheet shaped like the legacy workbook (title rows, formulas, template rows). */
function legacyWorkbook() {
  const ss = new FakeSpreadsheet('sanad_v9.2', TZ);
  const headers = [
    'م', 'تاريخ الزيارة', 'اليوم', 'وقت الزيارة', 'اسم المريض / الحالة', 'رقم التليفون',
    'العنوان التفصيلي', 'المنطقة', 'اسم الممرض / الفني', 'الخدمة المُقدَّمة', 'ثمن الزيارة (ج.م)',
    'حالة الاستلام', 'ملاحظات', 'الشهر (تلقائي)', '', '', '', '', 'كود الحالة',
  ];
  const visits = ss.insertSheet(VISITS).load([
    ['سند للرعاية المنزلية  |  سجل الزيارات الميدانية'],
    ['أدخل بيانات كل زيارة في صف جديد'],
    headers,
  ]);
  const data = [
    [1, date('2026-09-01'), 'Tuesday', '9م', 'منى عادل', "'01155555501", 'ش 10', 'سموحة', 'سارة', 'حقن عضل', 75, 'تم الاستلام', ''],
    [2, date('2026-09-02'), 'Wednesday', '11.30م', 'Ahmed', "'01012345678", '12 St', 'سموحة', 'سلطان', 'غيار عادى', 150, 'تم الاستلام', 'متابعة'],
  ];
  data.forEach((line, i) => line.forEach((v, c) => v !== '' && visits.getRange(4 + i, c + 1).setValue(v)));
  for (let r = 6; r <= 10; r++) {
    visits.getRange(r, 1).setValue(r - 3);
    visits.getRange(r, 3).setValue(`=IF(B${r}="","",TEXT(B${r},"dddd"))`);
    visits.getRange(r, 14).setValue(`=IF(B${r}="","",TEXT(B${r},"yyyy-mm"))`);
  }
  ss.insertSheet(CASES).load([
    ['سند للرعاية المنزلية  |  بيانات الحالات'],
    [''],
    ['اسم المريض / الحالة', 'رقم التليفون', 'العنوان التفصيلي', 'المنطقة'],
    ['منى عادل', "'01155555501", '', 'سموحة'],
  ]);
  ss.insertSheet(LISTS).load([
    ['الخدمات', 'السعر', 'الممرضين', 'المناطق'],
    ['حقن عضل', 75, 'سارة', 'سموحة'],
    ['غيار عادى', 150, 'سلطان', ''],
  ]);
  ss.insertSheet('داشبورد').load([['إجمالي الإيرادات', '=SUMIF(\'سجل الزيارات\'!L:L,"تم الاستلام",\'سجل الزيارات\'!K:K)']]);
  return ss;
}

function connected(ss) {
  const connector = loadConnector(ss);
  const { key } = connector.call({ action: 'pair' });
  return { connector, key, call: (body) => connector.call({ key, ...body }) };
}

const visitsOp = (extra) => ({
  sheet: VISITS,
  headerRow: 3,
  anchorCol: 2,
  ensureHeaders: ['طريقة الدفع', 'معرف سند'],
  ...extra,
});

const newRecord = (id, overrides = {}) => ({
  id,
  cells: {
    2: { d: '2026-10-11' },
    4: '7:30م',
    5: 'Karim Samir',
    6: '01277700033',
    7: '8 Fawzy Moaz St',
    8: 'سموحة',
    9: 'سارة',
    10: 'حقن عضل',
    11: 75,
    12: 'تم الاستلام',
    13: '=not a formula',
    'طريقة الدفع': 'نقدي',
    ...overrides,
  },
  ifBlank: { 1: '#' },
  unlessFormula: { 3: 'Sunday', 14: '2026-10' },
});

test('the first phone is paired automatically; others need the code', () => {
  const connector = loadConnector(legacyWorkbook());
  const first = connector.call({ action: 'pair' });
  assert.equal(first.ok, true);
  assert.match(first.key, /^[A-Z2-9]{10}$/);
  assert.equal(first.title, 'sanad_v9.2');

  assert.deepEqual(connector.call({ action: 'pair' }), { ok: false, error: 'code_required' });
  const typed = first.key.slice(0, 5).toLowerCase() + '-' + first.key.slice(5);
  assert.equal(connector.call({ action: 'pair', key: typed }).ok, true, 'code is case- and dash-insensitive');
  assert.deepEqual(connector.call({ action: 'read', key: 'WRONG' }), { ok: false, error: 'not_paired' });
});

test('read returns every sheet with dates as {d} and blanks as null', () => {
  const { call } = connected(legacyWorkbook());
  const out = call({ action: 'read' });
  assert.equal(out.ok, true);
  assert.deepEqual(out.sheets.map((s) => s.name), [VISITS, CASES, LISTS, 'داشبورد']);
  const visits = out.sheets[0].rows;
  assert.deepEqual(visits[3].slice(0, 6), [1, { d: '2026-09-01' }, 'Tuesday', '9م', 'منى عادل', '01155555501']);
  assert.equal(visits[3][13], null);
  assert.equal(visits[2][18], 'كود الحالة');
});

test('a new record goes to the first free row, keeping formulas and the running number', () => {
  const ss = legacyWorkbook();
  const { call } = connected(ss);
  const out = call({ action: 'write', ops: [visitsOp({ upserts: [newRecord('rec-1')] })] });
  assert.equal(out.ok, true);
  const result = out.results[0];
  assert.equal(result.rows['rec-1'], 6, 'after the last row with a date');
  assert.equal(result.cols['طريقة الدفع'], 20, 'added after the last header (S)');
  assert.equal(result.cols['معرف سند'], 21);
  assert.deepEqual(result.missing, []);

  const visits = ss.getSheetByName(VISITS);
  const row = visits.row(6, 21);
  assert.equal(row[0], 3, 'running number kept');
  assert.ok(row[1] instanceof Date);
  assert.equal(Utilities.formatDate(row[1], TZ, 'yyyy-MM-dd'), '2026-10-11');
  assert.equal(row[2], '=IF(B6="","",TEXT(B6,"dddd"))', 'weekday formula kept');
  assert.equal(row[5], '01277700033', 'phone keeps its leading zero');
  assert.equal(row[10], 75);
  assert.equal(row[12], '=not a formula', 'text starting with = is not turned into a formula');
  assert.equal(row[13], '=IF(B6="","",TEXT(B6,"yyyy-mm"))', 'month formula kept');
  assert.equal(row[19], 'نقدي');
  assert.equal(row[20], 'rec-1');
  assert.equal(visits.cell(6, 13).f, '', 'notes stored as text');
  assert.equal(ss.getSheetByName('داشبورد').cell(1, 2).f.startsWith('=SUMIF'), true, 'other sheets untouched');
});

test('the month is written as text, as the monthly summary expects', () => {
  const ss = legacyWorkbook();
  const visits = ss.getSheetByName(VISITS);
  visits.getRange(6, 14).setValue(''); // a row without the month formula
  const { call } = connected(ss);
  call({ action: 'write', ops: [visitsOp({ upserts: [newRecord('r1')] })] });
  assert.equal(visits.cell(6, 14).v, '2026-10');
  assert.equal(visits.cell(6, 6).v, '01277700033');
});

test('updating a record rewrites its own row; past the template rows values are written', () => {
  const ss = legacyWorkbook();
  const { call } = connected(ss);
  call({ action: 'write', ops: [visitsOp({ upserts: [newRecord('rec-1')] })] });
  const out = call({ action: 'write', ops: [visitsOp({ upserts: [newRecord('rec-1', { 11: 90 })] })] });
  assert.equal(out.results[0].rows['rec-1'], 6);
  assert.equal(ss.getSheetByName(VISITS).cell(6, 11).v, 90);

  // Fill the template rows, then one more: no formulas there, so the weekday,
  // month and running number are written as values.
  const many = ['a', 'b', 'c', 'd', 'e'].map((id) => newRecord(id));
  const res = call({ action: 'write', ops: [visitsOp({ upserts: many })] }).results[0];
  assert.deepEqual(Object.values(res.rows), [7, 8, 9, 10, 11]);
  const row11 = ss.getSheetByName(VISITS).row(11, 21);
  assert.equal(row11[0], 8, 'running number = row − header row');
  assert.equal(row11[2], 'Sunday');
  assert.equal(row11[13], '2026-10');
});

test('stamps link existing rows; archived records are cleared and the gap is not reused', () => {
  const ss = legacyWorkbook();
  const { call } = connected(ss);
  let out = call({ action: 'write', ops: [visitsOp({ stamps: [{ id: 'old-1', row: 4 }, { id: 'old-2', row: 5 }] })] });
  assert.deepEqual(out.results[0].rows, { 'old-1': 4, 'old-2': 5 });
  const visits = ss.getSheetByName(VISITS);
  assert.equal(visits.cell(4, 21).v, 'old-1');

  // An edit of an old record finds its row by ID even if the app's row is stale.
  out = call({ action: 'write', ops: [visitsOp({ upserts: [{ id: 'old-2', row: 99, cells: { 11: 160 } }] })] });
  assert.equal(out.results[0].rows['old-2'], 5);
  assert.equal(visits.cell(5, 11).v, 160);

  out = call({
    action: 'write',
    ops: [visitsOp({ clears: [{ id: 'old-1', cols: [2, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 'طريقة الدفع'] }] })],
  });
  assert.equal(out.results[0].rows['old-1'], null);
  assert.equal(visits.cell(4, 2).v, '');
  assert.equal(visits.cell(4, 11).v, '');
  assert.equal(visits.cell(4, 21).v, '');
  assert.equal(visits.cell(4, 1).v, 1, 'running number left in place');

  out = call({ action: 'write', ops: [visitsOp({ upserts: [newRecord('rec-2')] })] });
  assert.equal(out.results[0].rows['rec-2'], 6, 'goes after the last used row, not into the cleared row 4');
});

test('stamping twice is harmless and a stamped ID can be re-linked to its row', () => {
  const ss = legacyWorkbook();
  const { call } = connected(ss);
  call({ action: 'write', ops: [visitsOp({ stamps: [{ id: 'x', row: 4 }] })] });
  const out = call({ action: 'write', ops: [visitsOp({ stamps: [{ id: 'x', row: 4 }] })] });
  assert.deepEqual(out.results[0].rows, { x: 4 });
});

test('customers: existing ones are matched by phone and only blanks filled; new ones appended', () => {
  const ss = legacyWorkbook();
  const { call } = connected(ss);
  const out = call({
    action: 'write',
    ops: [
      {
        sheet: CASES,
        headerRow: 3,
        anchorCol: 1,
        upserts: [
          {
            id: 'cust-mona',
            match: { col: 2, value: '01155555501' },
            overwrite: false,
            cells: { 1: 'Mona Adel (other spelling)', 2: '01155555501', 3: 'ش 10 سموحة', 4: 'سموحة' },
          },
          { id: 'cust-new', match: { col: 2, value: '01099900044' }, cells: { 1: 'هدى', 2: '01099900044', 4: 'البيطاش' } },
        ],
      },
    ],
  });
  assert.deepEqual(out.results[0].rows, { 'cust-mona': 4, 'cust-new': 5 });
  const cases = ss.getSheetByName(CASES);
  assert.deepEqual(cases.row(4, 5), ['منى عادل', '01155555501', 'ش 10 سموحة', 'سموحة', 'cust-mona']);
  assert.deepEqual(cases.row(5, 5), ['هدى', '01099900044', '', 'البيطاش', 'cust-new']);

  // A later edit (overwrite) changes the matched row.
  call({ action: 'write', ops: [{ sheet: CASES, headerRow: 3, anchorCol: 1, upserts: [{ id: 'cust-mona', cells: { 1: 'منى عادل محمد' } }] }] });
  assert.equal(cases.cell(4, 1).v, 'منى عادل محمد');
});

test('a customer saved again under a new ID takes over its row (no duplicate)', () => {
  const ss = legacyWorkbook();
  const { call } = connected(ss);
  const casesOp = (upserts) => ({ sheet: CASES, headerRow: 3, anchorCol: 1, upserts });
  const mona = (id) => ({ id, match: { col: 2, value: '01155555501' }, overwrite: false, cells: { 1: 'منى عادل', 2: '01155555501' } });
  call({ action: 'write', ops: [casesOp([mona('old-id')])] });
  // The phone's data was loaded again: same customer, new ID.
  const out = call({ action: 'write', ops: [casesOp([mona('new-id')])] });
  assert.deepEqual(out.results[0].rows, { 'new-id': 4 });
  const cases = ss.getSheetByName(CASES);
  assert.equal(cases.getLastRow(), 4);
  assert.equal(cases.cell(4, 5).v, 'new-id');
});

test('a row written in the same request is never taken over by a phone match', () => {
  const ss = legacyWorkbook();
  const { call } = connected(ss);
  const out = call({
    action: 'write',
    ops: [
      {
        sheet: CASES,
        headerRow: 3,
        anchorCol: 1,
        upserts: [
          { id: 'a', match: { col: 2, value: '01155555501' }, cells: { 1: 'منى عادل', 2: '01155555501' } },
          { id: 'b', match: { col: 2, value: '01155555501' }, cells: { 1: 'Other', 2: '01155555501' } },
        ],
      },
    ],
  });
  assert.deepEqual(out.results[0].rows, { a: 4, b: 5 });
});

test('a copied row: the original keeps its ID, the copy gets its own', () => {
  const ss = legacyWorkbook();
  const { call } = connected(ss);
  call({ action: 'write', ops: [visitsOp({ stamps: [{ id: 'v1', row: 4 }] })] });
  const visits = ss.getSheetByName(VISITS);
  const idCol = visits.row(3).indexOf('معرف سند') + 1;
  // The user copies row 4 (with its ID) over row 5.
  visits.getRange(5, idCol).setValue('v1');
  call({ action: 'write', ops: [visitsOp({ stamps: [{ id: 'v2', row: 5 }] })] });
  assert.equal(visits.cell(4, idCol).v, 'v1');
  assert.equal(visits.cell(5, idCol).v, 'v2');
  const out = call({ action: 'write', ops: [visitsOp({ upserts: [{ id: 'v1', row: 4, cells: { 11: 90 } }] })] });
  assert.deepEqual(out.results[0].rows, { v1: 4 });
  assert.equal(visits.cell(4, 11).v, 90);
  assert.equal(visits.cell(5, 11).v, 150);
});

test('lists: missing names are appended in their own column, existing ones are kept or updated', () => {
  const ss = legacyWorkbook();
  const { call } = connected(ss);
  const out = call({
    action: 'write',
    ops: [
      {
        sheet: LISTS,
        headerRow: 1,
        appends: [
          { col: 1, value: 'حقن عضل', also: { 2: 80 } },
          { col: 1, value: 'رسم القلب', also: { 2: 300 } },
          { col: 1, value: 'غيار عادي', also: { 2: 175 }, update: true },
          { col: 3, value: 'ساره', also: {} },
          { col: 3, value: 'يوسف' },
          { col: 4, value: 'البيطاش' },
        ],
      },
    ],
  });
  assert.equal(out.ok, true);
  const lists = ss.getSheetByName(LISTS);
  assert.deepEqual(lists.row(2, 4), ['حقن عضل', 75, 'سارة', 'سموحة'], 'existing service price not changed without update');
  assert.deepEqual(lists.row(3, 4), ['غيار عادى', 175, 'سلطان', 'البيطاش'], 'spelling variant matched; price updated');
  assert.deepEqual(lists.row(4, 4), ['رسم القلب', 300, 'يوسف', '']);
});

test('new columns go after every used column, never over cells without a header', () => {
  const ss = legacyWorkbook();
  const visits = ss.getSheetByName(VISITS);
  visits.getRange(6, 21).setValue('ملاحظة جانبية'); // a note in a column without a header
  const { call } = connected(ss);
  const out = call({ action: 'write', ops: [visitsOp({ stamps: [{ id: 'v1', row: 6 }] })] });
  assert.equal(out.results[0].cols['طريقة الدفع'], 22);
  assert.equal(out.results[0].cols['معرف سند'], 23);
  assert.equal(visits.cell(6, 21).v, 'ملاحظة جانبية');
  assert.equal(visits.cell(6, 23).v, 'v1');
});

test('a big first update reads each sheet once instead of cell by cell', () => {
  const ss = legacyWorkbook();
  const { call } = connected(ss);
  const customers = [];
  const visits = [];
  for (let i = 0; i < 100; i++) {
    const phone = '0120000' + String(i).padStart(4, '0');
    customers.push({ id: 'c' + i, match: { col: 2, value: phone }, overwrite: false, cells: { 1: 'Name ' + i, 2: phone, 3: 'Street', 4: 'سموحة' } });
    visits.push(newRecord('v' + i));
  }
  const flushes = ss.flushes;
  const out = call({
    action: 'write',
    ops: [
      visitsOp({ stamps: [{ id: 's1', row: 4 }, { id: 's2', row: 5 }], upserts: visits }),
      { sheet: CASES, headerRow: 3, anchorCol: 1, upserts: customers },
      { sheet: LISTS, headerRow: 1, appends: [{ col: 'الممرضين', value: 'ممرض جديد' }] },
    ],
  });
  assert.equal(out.ok, true);
  assert.equal(Object.keys(out.results[0].rows).length, 102);
  assert.equal(Object.keys(out.results[1].rows).length, 100);
  // Each sheet: at most one wait for earlier writes before reading it.
  assert.ok(ss.flushes - flushes <= 6, `flushes: ${ss.flushes - flushes}`);
});

test('sheets that do not exist are created with their headers', () => {
  const ss = new FakeSpreadsheet('New sheet', TZ);
  ss.insertSheet('Sheet1');
  const { call } = connected(ss);
  const headers = ['م', 'تاريخ الزيارة', 'اليوم', 'وقت الزيارة', 'اسم المريض / الحالة', 'رقم التليفون'];
  const out = call({
    action: 'write',
    ops: [{ sheet: VISITS, headerRow: 1, anchorCol: 2, create: headers, upserts: [{ id: 'r1', cells: { 2: { d: '2026-10-11' }, 5: 'Mona' }, ifBlank: { 1: '#' } }] }],
  });
  assert.equal(out.results[0].rows.r1, 2);
  const sheet = ss.getSheetByName(VISITS);
  assert.deepEqual(sheet.row(1, 7), [...headers, 'معرف سند']);
  assert.equal(sheet.cell(2, 1).v, 1);
  assert.equal(sheet.rtl, true);
});

test('writing beyond the sheet size grows the sheet', () => {
  const ss = legacyWorkbook();
  const visits = ss.getSheetByName(VISITS);
  visits.maxRows = 10;
  visits.maxCols = 19;
  const { call } = connected(ss);
  const out = call({ action: 'write', ops: [visitsOp({ upserts: ['a', 'b', 'c', 'd', 'e', 'f'].map((id) => newRecord(id)) })] });
  assert.equal(out.ok, true, JSON.stringify(out));
  assert.equal(out.results[0].rows.f, 11);
  assert.ok(visits.maxRows >= 11 && visits.maxCols >= 21);
});

test('bad requests are answered with an error, not an exception', () => {
  const connector = loadConnector(legacyWorkbook());
  const out = connector.context.doPost({ postData: { contents: 'not json' } });
  assert.equal(JSON.parse(out.getContent()).error, 'server_error');
  assert.match(connector.context.doGet().getContent(), /Sanad connector v1/);
});

test('cells can be addressed by header name; unknown names are reported', () => {
  const ss = legacyWorkbook();
  const { call } = connected(ss);
  const out = call({
    action: 'write',
    ops: [
      visitsOp({
        anchorCol: 'تاريخ الزيارة',
        upserts: [
          {
            id: 'by-name',
            cells: { 'تاريخ الزيارة': { d: '2026-10-12' }, '  ثمن الزيارة  (ج.م) ': 120, 'عمود محذوف': 'x' },
            ifBlank: { 'م': '#' },
          },
        ],
      }),
    ],
  });
  const result = out.results[0];
  assert.equal(result.rows['by-name'], 6);
  assert.equal(ss.getSheetByName(VISITS).cell(6, 11).v, 120, 'header matched despite extra spaces');
  assert.deepEqual(result.missing, ['عمود محذوف']);
});
