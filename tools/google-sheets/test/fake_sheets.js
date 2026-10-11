// A small in-memory imitation of the Apps Script services used by Code.gs,
// so the connector can be tested (and served locally) without Google.
// Only the behaviour Code.gs relies on is implemented.
'use strict';

const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const crypto = require('node:crypto');

const CODE_PATH = path.join(__dirname, '..', 'Code.gs');

/** Offset (minutes) of `tz` at `date`, e.g. 180 for Africa/Cairo in summer. */
function tzOffset(date, tz) {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: tz,
    hourCycle: 'h23',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  }).formatToParts(date);
  const get = (t) => Number(parts.find((p) => p.type === t).value);
  const asUtc = Date.UTC(get('year'), get('month') - 1, get('day'), get('hour'), get('minute'), get('second'));
  return Math.round((asUtc - date.getTime()) / 60000);
}

function pad(n) {
  return String(n).padStart(2, '0');
}

const Utilities = {
  formatDate(date, tz, format) {
    const local = new Date(date.getTime() + tzOffset(date, tz) * 60000);
    const y = local.getUTCFullYear();
    const map = {
      yyyy: String(y),
      MM: pad(local.getUTCMonth() + 1),
      dd: pad(local.getUTCDate()),
      HH: pad(local.getUTCHours()),
      mm: pad(local.getUTCMinutes()),
    };
    return format.replace(/yyyy|MM|dd|HH|mm/g, (t) => map[t]);
  },
  parseDate(text, tz, format) {
    if (format !== 'yyyy-MM-dd') throw new Error('unsupported format ' + format);
    const [y, m, d] = text.split('-').map(Number);
    const guess = new Date(Date.UTC(y, m - 1, d));
    return new Date(guess.getTime() - tzOffset(guess, tz) * 60000);
  },
  getUuid() {
    return crypto.randomUUID();
  },
};

/** Cell content as stored by Sheets: a typed value and an optional formula. */
function storeValue(input) {
  if (typeof input === 'string') {
    if (input.startsWith("'")) return { v: input.slice(1), f: '' };
    if (input.startsWith('=')) return { v: '', f: input };
    if (/^-?\d+(\.\d+)?$/.test(input)) return { v: Number(input), f: '' }; // like Sheets: "0101" → 101
    const date = /^(\d{4})-(\d{1,2})(?:-(\d{1,2}))?$/.exec(input); // like Sheets: "2026-10" → a date
    if (date) return { v: new Date(Date.UTC(+date[1], +date[2] - 1, +(date[3] || 1))), f: '' };
  }
  if (input === null || input === undefined) return { v: '', f: '' };
  return { v: input, f: '' };
}

class FakeRange {
  constructor(sheet, row, col, rows, cols) {
    if (row < 1 || col < 1 || row + rows - 1 > sheet.maxRows || col + cols - 1 > sheet.maxCols) {
      throw new Error(`Range (${row},${col},${rows}x${cols}) is outside the sheet (${sheet.maxRows}x${sheet.maxCols})`);
    }
    Object.assign(this, { sheet, row, col, rows, cols });
  }
  _each(fn) {
    const out = [];
    for (let r = 0; r < this.rows; r++) {
      const line = [];
      for (let c = 0; c < this.cols; c++) line.push(fn(this.sheet.cell(this.row + r, this.col + c), r, c));
      out.push(line);
    }
    return out;
  }
  getValues() {
    this.sheet.ss.read();
    return this._each((cell) => cell.v);
  }
  getFormulas() {
    this.sheet.ss.read();
    return this._each((cell) => cell.f);
  }
  getDisplayValues() {
    this.sheet.ss.read();
    return this._each((cell) => {
      if (cell.v instanceof Date) return Utilities.formatDate(cell.v, this.sheet.ss.tz, 'yyyy-MM-dd');
      return cell.v === '' ? '' : String(cell.v);
    });
  }
  getValue() {
    this.sheet.ss.read();
    return this.sheet.cell(this.row, this.col).v;
  }
  getFormula() {
    this.sheet.ss.read();
    return this.sheet.cell(this.row, this.col).f;
  }
  setValues(values) {
    if (values.length !== this.rows || values.some((r) => r.length !== this.cols)) {
      throw new Error('setValues: dimensions do not match the range');
    }
    values.forEach((line, r) =>
      line.forEach((v, c) => this.sheet.put(this.row + r, this.col + c, storeValue(v))),
    );
    return this;
  }
  setValue(v) {
    this.sheet.put(this.row, this.col, storeValue(v));
    return this;
  }
  clearContent() {
    this._each((_, r, c) => this.sheet.put(this.row + r, this.col + c, { v: '', f: '' }));
    return this;
  }
  setFontWeight() {
    return this;
  }
}

class FakeSheet {
  constructor(ss, name, rows = 1000, cols = 26) {
    Object.assign(this, { ss, name, maxRows: rows, maxCols: cols, data: new Map(), frozen: 0, rtl: false });
  }
  cell(r, c) {
    return this.data.get(`${r},${c}`) || { v: '', f: '' };
  }
  put(r, c, content) {
    if (content.v === '' && !content.f) this.data.delete(`${r},${c}`);
    else this.data.set(`${r},${c}`, content);
    this.ss.writes += 1;
    this.ss.dirty = true;
  }
  getName() {
    return this.name;
  }
  getLastRow() {
    this.ss.read();
    let last = 0;
    for (const key of this.data.keys()) last = Math.max(last, Number(key.split(',')[0]));
    return last;
  }
  getLastColumn() {
    this.ss.read();
    let last = 0;
    for (const key of this.data.keys()) last = Math.max(last, Number(key.split(',')[1]));
    return last;
  }
  getMaxRows() {
    this.ss.read();
    return this.maxRows;
  }
  getMaxColumns() {
    this.ss.read();
    return this.maxCols;
  }
  insertRowsAfter(_, n) {
    this.maxRows += n;
  }
  insertColumnsAfter(_, n) {
    this.maxCols += n;
  }
  getRange(row, col, rows = 1, cols = 1) {
    return new FakeRange(this, row, col, rows, cols);
  }
  getDataRange() {
    return new FakeRange(this, 1, 1, Math.max(this.getLastRow(), 1), Math.max(this.getLastColumn(), 1));
  }
  setFrozenRows(n) {
    this.frozen = n;
  }
  setRightToLeft(v) {
    this.rtl = v;
  }

  /** Test helpers: fill from a 2D array (row 1 first); '=…' strings become formulas. */
  load(rows) {
    rows.forEach((line, r) => line.forEach((v, c) => this.put(r + 1, c + 1, storeValue(v))));
    return this;
  }
  row(r, cols = this.getLastColumn()) {
    const out = [];
    for (let c = 1; c <= cols; c++) {
      const cell = this.cell(r, c);
      out.push(cell.f ? cell.f : cell.v);
    }
    return out;
  }
}

class FakeSpreadsheet {
  constructor(name = 'Sanad', tz = 'Africa/Cairo') {
    Object.assign(this, { name, tz, sheets: [], writes: 0, flushes: 0, dirty: false });
  }
  /** A read after a write makes Apps Script apply the pending writes first (slow). */
  read() {
    if (this.dirty) this.flushes += 1;
    this.dirty = false;
  }
  getName() {
    return this.name;
  }
  getSpreadsheetTimeZone() {
    return this.tz;
  }
  getSheets() {
    return this.sheets;
  }
  getSheetByName(name) {
    return this.sheets.find((s) => s.name === name) || null;
  }
  insertSheet(name) {
    const sheet = new FakeSheet(this, name);
    this.sheets.push(sheet);
    return sheet;
  }
}

/** Loads Code.gs in a sandbox bound to `ss`; returns {call(body) → parsed JSON, context, props}. */
function loadConnector(ss) {
  const props = new Map();
  const context = vm.createContext({
    // Same Date as the fake sheets, so `instanceof Date` works inside Code.gs.
    Date,
    Utilities,
    SpreadsheetApp: {
      getActiveSpreadsheet: () => ss,
      getActive: () => ss,
      getUi: () => {
        throw new Error('no UI in tests');
      },
    },
    PropertiesService: {
      getScriptProperties: () => ({
        getProperty: (k) => (props.has(k) ? props.get(k) : null),
        setProperty: (k, v) => props.set(k, String(v)),
        deleteProperty: (k) => props.delete(k),
      }),
    },
    LockService: { getScriptLock: () => ({ waitLock() {}, releaseLock() {} }) },
    ContentService: {
      MimeType: { JSON: 'application/json' },
      createTextOutput: (text) => ({
        text,
        setMimeType() {
          return this;
        },
        getContent() {
          return this.text;
        },
      }),
    },
    Logger: { log() {} },
    console,
  });
  vm.runInContext(fs.readFileSync(CODE_PATH, 'utf8'), context, { filename: 'Code.gs' });
  return {
    context,
    props,
    call(body) {
      const out = context.doPost({ postData: { contents: JSON.stringify(body) } });
      return JSON.parse(out.getContent());
    },
  };
}

module.exports = { FakeSpreadsheet, FakeSheet, loadConnector, Utilities, tzOffset };
