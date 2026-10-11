/**
 * Sanad ↔ Google Sheets connector (version 1).
 *
 * Lets the Sanad app load all the data of this spreadsheet once, and then
 * write every new or changed visit (and new customers, nurses, services and
 * areas) into it. Your other sheets and formulas (dashboard, monthly summary,
 * expenses…) are never touched.
 *
 * Setup (once, free):
 *   1. In this spreadsheet: Extensions → Apps Script. Delete what is there,
 *      paste this whole file, click Save.
 *   2. Deploy → New deployment → ⚙ → Web app.
 *        Execute as: Me
 *        Who has access: Anyone
 *      → Deploy → Authorize access → choose your account → Advanced →
 *        "Go to … (unsafe)" (it is your own script) → Allow.
 *   3. Copy the "Web app" URL and paste it in Sanad → More → Google Sheet.
 *
 * Keep the URL private, like a password. The first phone that connects is
 * paired automatically; for another phone use the "سند" menu in this
 * spreadsheet → "رمز الربط" (connection code).
 *
 * @OnlyCurrentDoc
 */

var SANAD = { version: 1, idHeader: 'معرف سند' };

function doGet() {
  return ContentService.createTextOutput(
    'Sanad connector v' + SANAD.version + ' is running. Paste this link in the Sanad app.'
  );
}

function doPost(e) {
  var out;
  try {
    var req = JSON.parse((e && e.postData && e.postData.contents) || '{}');
    out = route_(req);
  } catch (err) {
    out = { ok: false, error: 'server_error', message: String((err && err.message) || err) };
  }
  return ContentService.createTextOutput(JSON.stringify(out)).setMimeType(ContentService.MimeType.JSON);
}

function route_(req) {
  var lock = LockService.getScriptLock();
  lock.waitLock(30000);
  try {
    var props = PropertiesService.getScriptProperties();
    var key = props.getProperty('SANAD_KEY');
    var given = cleanKey_(req.key);
    var ss = SpreadsheetApp.getActiveSpreadsheet();
    if (req.action === 'pair') {
      if (!key) {
        key = newKey_();
        props.setProperty('SANAD_KEY', key);
      } else if (given !== key) {
        return { ok: false, error: 'code_required' };
      }
      return { ok: true, key: key, version: SANAD.version, title: ss.getName() };
    }
    if (!key || given !== key) return { ok: false, error: 'not_paired' };
    if (req.action === 'read') {
      return { ok: true, version: SANAD.version, title: ss.getName(), sheets: read_(ss, req.sheets) };
    }
    if (req.action === 'write') {
      return {
        ok: true,
        results: (req.ops || []).map(function (op) {
          return write_(ss, op);
        }),
      };
    }
    return { ok: false, error: 'unknown_action' };
  } finally {
    lock.releaseLock();
  }
}

// ---------------------------------------------------------------------------
// Reading
// ---------------------------------------------------------------------------

function read_(ss, names) {
  var tz = ss.getSpreadsheetTimeZone();
  return ss
    .getSheets()
    .filter(function (sh) {
      return !names || names.indexOf(sh.getName()) >= 0;
    })
    .map(function (sh) {
      var range = sh.getDataRange();
      var values = range.getValues();
      var shown = range.getDisplayValues();
      return {
        name: sh.getName(),
        rows: values.map(function (row, r) {
          return row.map(function (v, c) {
            return cellOut_(v, shown[r][c], tz);
          });
        }),
      };
    });
}

/** Dates as {d: "yyyy-MM-dd[ HH:mm]"}, time-only cells as shown, blanks as null. */
function cellOut_(v, shown, tz) {
  if (v instanceof Date) {
    if (v.getFullYear() < 1901) return shown;
    var hm = Utilities.formatDate(v, tz, 'HH:mm');
    return { d: Utilities.formatDate(v, tz, 'yyyy-MM-dd') + (hm === '00:00' ? '' : ' ' + hm) };
  }
  if (v === '' || v === null || v === undefined) return null;
  return v;
}

// ---------------------------------------------------------------------------
// Writing
// ---------------------------------------------------------------------------

/**
 * op = {
 *   sheet, headerRow (1-based), create: [headers] (to add the sheet if missing),
 *   ensureHeaders: [names] (added at the end of the header row if missing),
 *   anchorCol: column that is filled on every used row (new rows go after the last one),
 *   upserts: [{id, row?, match?: {col, value}, overwrite?, cells, ifBlank, unlessFormula}],
 *   stamps: [{id, row}], clears: [{id, cols}],
 *   appends: [{col, value, also: {col: value}, update?}]
 * }
 * Column keys are 1-based numbers or header names. Values: string, number,
 * {d: "yyyy-MM-dd"} (a date) or "#" in ifBlank (the running number).
 */
function write_(ss, op) {
  var sh = ss.getSheetByName(op.sheet);
  var size;
  if (!sh) {
    if (!op.create) return { sheet: op.sheet, error: 'sheet_not_found' };
    sh = ss.insertSheet(op.sheet);
    size = size_(sh);
    ensureSize_(size, 1, op.create.length);
    sh.getRange(1, 1, 1, op.create.length).setValues([op.create]).setFontWeight('bold');
    sh.setFrozenRows(1);
    sh.setRightToLeft(true);
  }
  var headerRow = op.headerRow || 1;
  var ctx = {
    sh: sh,
    size: size || size_(sh),
    tz: ss.getSpreadsheetTimeZone(),
    headerRow: headerRow,
    missing: {},
    used: {},
  };
  var touchesRows = !!(op.upserts || op.stamps || op.clears);
  var wanted = (op.ensureHeaders || []).slice();
  if (touchesRows && wanted.indexOf(SANAD.idHeader) < 0) wanted.push(SANAD.idHeader);
  ctx.cols = headers_(ctx, wanted);
  // Everything below the header is read once, here: reading after writing is
  // slow in Apps Script, so from now on the request only writes.
  ctx.grid = grid_(ctx);
  var result = { sheet: sh.getName(), rows: {}, cols: ctx.cols, missing: [] };

  if (op.appends) appendItems_(ctx, op.appends);
  if (!touchesRows) return done_(ctx, result);

  var g = ctx.grid;
  var idCol = ctx.cols[headerKey_(SANAD.idHeader)];
  var anchorCol = colOf_(ctx, op.anchorCol || 1);
  var start = g.start;
  var ids = {}; // row → id
  var idRow = {}; // id → row
  var lastUsed = headerRow;
  for (var i = 0; i < g.values.length; i++) {
    var at = start + i;
    var id = String(valueAt_(g, at, idCol)).trim();
    if (id) {
      ids[at] = id;
      if (!(id in idRow)) idRow[id] = at; // a copied row keeps the original's place
      lastUsed = at;
    }
    if (anchorCol && !blank_(valueAt_(g, at, anchorCol))) lastUsed = at;
  }
  var next = lastUsed + 1;
  var idsChanged = false;
  var maxRow = start - 1 + g.values.length;
  function setId(row, id) {
    if (ids[row] && idRow[ids[row]] === row) delete idRow[ids[row]];
    ids[row] = id;
    if (id) idRow[id] = row;
    ctx.used[row] = true;
    idsChanged = true;
    if (row > maxRow) maxRow = row;
  }

  (op.stamps || []).forEach(function (s) {
    if (idRow[s.id]) {
      result.rows[s.id] = idRow[s.id];
      return;
    }
    setId(s.row, s.id);
    result.rows[s.id] = s.row;
  });

  var matches = {};
  (op.upserts || []).forEach(function (u) {
    var row = idRow[u.id];
    if (!row && u.row && !ids[u.row]) row = u.row;
    if (!row && u.match) row = findMatch_(ctx, matches, u.match);
    var isNew = !row;
    if (isNew) row = next++;
    writeCells_(ctx, row, u.cells || {}, u.overwrite !== false || isNew);
    writeIfBlank_(ctx, row, u.ifBlank || {});
    writeUnlessFormula_(ctx, row, u.unlessFormula || {});
    setId(row, u.id);
    result.rows[u.id] = row;
  });

  (op.clears || []).forEach(function (c) {
    var row = idRow[c.id];
    if (!row) return;
    (c.cols || []).forEach(function (k) {
      var col = colOf_(ctx, k);
      if (!col) return;
      sh.getRange(row, col).clearContent();
      put_(ctx, row, col, '');
    });
    setId(row, '');
    result.rows[c.id] = null;
  });

  if (idsChanged) {
    var out = [];
    for (var r = start; r <= maxRow; r++) out.push([ids[r] || '']);
    ensureSize_(ctx.size, maxRow, idCol);
    if (out.length) sh.getRange(start, idCol, out.length, 1).setValues(out);
  }
  return done_(ctx, result);
}

/** Reports the header names that were not found (the sheet's columns changed). */
function done_(ctx, result) {
  result.missing = Object.keys(ctx.missing);
  return result;
}

/** Header name → column, adding the wanted headers that are missing. */
function headers_(ctx, wanted) {
  var sh = ctx.sh;
  var used = sh.getLastColumn();
  var width = Math.max(used, 1);
  ensureSize_(ctx.size, ctx.headerRow, width);
  var row = sh
    .getRange(ctx.headerRow, 1, 1, width)
    .getValues()[0]
    .map(function (v) {
      return String(v === null || v === undefined ? '' : v).trim();
    });
  var cols = {};
  row.forEach(function (v, i) {
    if (!v) return;
    var key = headerKey_(v);
    if (!(key in cols)) cols[key] = i + 1;
  });
  // New columns go after everything in the sheet: never over cells that
  // have no header.
  var last = used;
  wanted.forEach(function (name) {
    if (cols[headerKey_(name)]) return;
    last += 1;
    ensureSize_(ctx.size, ctx.headerRow, last);
    sh.getRange(ctx.headerRow, last).setValue(name).setFontWeight('bold');
    cols[headerKey_(name)] = last;
  });
  return cols;
}

/** Values and formulas of the rows below the header (two reads). */
function grid_(ctx) {
  var start = ctx.headerRow + 1;
  var n = Math.max(ctx.sh.getLastRow() - ctx.headerRow, 0);
  var width = Math.max(ctx.sh.getLastColumn(), 1);
  var range = n ? ctx.sh.getRange(start, 1, n, width) : null;
  return {
    start: start,
    width: width,
    values: range ? range.getValues() : [],
    formulas: range ? range.getFormulas() : [],
  };
}

function valueAt_(g, row, col) {
  var line = g.values[row - g.start];
  var v = line && col && col <= g.width ? line[col - 1] : '';
  return v === null || v === undefined ? '' : v;
}

function formulaAt_(g, row, col) {
  var line = g.formulas[row - g.start];
  return (line && col && col <= g.width && line[col - 1]) || '';
}

/** Keeps the copy read by grid_ in step with what is written. */
function put_(ctx, row, col, value) {
  var g = ctx.grid;
  var i = row - g.start;
  if (i < 0 || col > g.width) return;
  while (g.values.length <= i) {
    g.values.push(blankRow_(g.width));
    g.formulas.push(blankRow_(g.width));
  }
  g.values[i][col - 1] = value;
  g.formulas[i][col - 1] = '';
}

function blankRow_(width) {
  var row = [];
  for (var i = 0; i < width; i++) row.push('');
  return row;
}

function setCell_(ctx, row, col, value) {
  ensureSize_(ctx.size, row, col);
  ctx.sh.getRange(row, col).setValue(value);
  put_(ctx, row, col, value);
}

function writeCells_(ctx, row, cells, overwrite) {
  if (!overwrite) return writeIfBlank_(ctx, row, cells);
  var entries = entries_(ctx, cells);
  // Contiguous columns are written in one call.
  var i = 0;
  while (i < entries.length) {
    var j = i;
    while (j + 1 < entries.length && entries[j + 1][0] === entries[j][0] + 1) j++;
    var first = entries[i][0];
    var values = entries.slice(i, j + 1).map(function (e) {
      return in_(ctx, e[1], row);
    });
    ensureSize_(ctx.size, row, entries[j][0]);
    ctx.sh.getRange(row, first, 1, values.length).setValues([values]);
    values.forEach(function (v, k) {
      put_(ctx, row, first + k, v);
    });
    i = j + 1;
  }
}

function writeIfBlank_(ctx, row, cells) {
  entries_(ctx, cells).forEach(function (e) {
    if (blank_(valueAt_(ctx.grid, row, e[0])) && !formulaAt_(ctx.grid, row, e[0])) {
      setCell_(ctx, row, e[0], in_(ctx, e[1], row));
    }
  });
}

function writeUnlessFormula_(ctx, row, cells) {
  entries_(ctx, cells).forEach(function (e) {
    if (!formulaAt_(ctx.grid, row, e[0])) setCell_(ctx, row, e[0], in_(ctx, e[1], row));
  });
}

function appendItems_(ctx, appends) {
  var lists = {};
  appends.forEach(function (a) {
    var col = colOf_(ctx, a.col);
    if (!col) return;
    var list = lists[col] || (lists[col] = column_(ctx, col));
    var key = norm_(a.value);
    if (!key) return;
    var row = list.rows[key];
    if (row && !a.update) return;
    if (!row) {
      row = list.last + 1;
      list.last = row;
      list.rows[key] = row;
      setCell_(ctx, row, col, in_(ctx, a.value, row));
    }
    Object.keys(a.also || {}).forEach(function (k) {
      var c = colOf_(ctx, k);
      if (!c) return;
      var value = in_(ctx, a.also[k], row);
      if (String(valueAt_(ctx.grid, row, c)) !== String(value).replace(/^'/, '')) setCell_(ctx, row, c, value);
    });
  });
}

/** Normalised values of one column below the header: value → row, and the last used row. */
function column_(ctx, col) {
  var g = ctx.grid;
  var list = { rows: {}, last: ctx.headerRow };
  for (var i = 0; i < g.values.length; i++) {
    var v = valueAt_(g, g.start + i, col);
    if (blank_(v)) continue;
    list.last = g.start + i;
    var key = norm_(v);
    if (!(key in list.rows)) list.rows[key] = g.start + i;
  }
  return list;
}

/**
 * Row whose phone (digits) equals match.value. It is taken over even if it
 * carries another ID (the same customer, saved again on the phone or by
 * another phone), but never a row already written in this request.
 */
function findMatch_(ctx, cache, match) {
  var col = colOf_(ctx, match.col);
  if (!col || !match.value) return null;
  var list = cache[col];
  if (!list) {
    list = cache[col] = {};
    var g = ctx.grid;
    for (var i = 0; i < g.values.length; i++) {
      var key = phone_(valueAt_(g, g.start + i, col));
      if (key && !(key in list)) list[key] = g.start + i;
    }
  }
  var row = list[phone_(match.value)];
  return row && !ctx.used[row] ? row : null;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function entries_(ctx, cells) {
  return Object.keys(cells)
    .map(function (k) {
      return [colOf_(ctx, k), cells[k]];
    })
    .filter(function (e) {
      return e[0];
    })
    .sort(function (a, b) {
      return a[0] - b[0];
    });
}

function colOf_(ctx, key) {
  if (typeof key === 'number') return key;
  if (/^\d+$/.test(String(key))) return Number(key);
  var col = ctx.cols[headerKey_(key)];
  if (!col) ctx.missing[key] = true;
  return col || null;
}

/** Header text compared without surrounding/duplicate spaces. */
function headerKey_(v) {
  return String(v === null || v === undefined ? '' : v)
    .trim()
    .replace(/\s+/g, ' ');
}

/** Converts a value from the app into what is written in the cell. */
function in_(ctx, v, row) {
  if (v === null || v === undefined) return '';
  if (v === '#') return row - ctx.headerRow;
  if (typeof v === 'object' && v.d) return Utilities.parseDate(v.d, ctx.tz, 'yyyy-MM-dd');
  // Text that Sheets would turn into a number, date or formula stays text
  // (keeps the leading 0 of phone numbers, and months like "2026-10" as the
  // text the workbook's monthly summary looks for).
  if (typeof v === 'string' && (/^[=+\-@]/.test(v) || /^[\d\s.,\/:\-]+$/.test(v))) return "'" + v;
  return v;
}

function blank_(v) {
  return v === '' || v === null || v === undefined || (typeof v === 'string' && v.trim() === '');
}

function norm_(v) {
  return String(v === null || v === undefined ? '' : v)
    .trim()
    .toLowerCase()
    .replace(/[ً-ْـ]/g, '')
    .replace(/[أإآٱ]/g, 'ا')
    .replace(/ى/g, 'ي')
    .replace(/ة/g, 'ه')
    .replace(/\s+/g, ' ');
}

function phone_(v) {
  var d = String(v === null || v === undefined ? '' : v).replace(/\D/g, '');
  if (d.length === 10 && d.charAt(0) === '1') d = '0' + d;
  if (d.length === 12 && d.indexOf('20') === 0) d = '0' + d.substring(2);
  return d;
}

/** The sheet's size, read once and kept up to date. */
function size_(sh) {
  return { sh: sh, rows: sh.getMaxRows(), cols: sh.getMaxColumns() };
}

function ensureSize_(size, rows, cols) {
  if (rows > size.rows) {
    size.sh.insertRowsAfter(size.rows, rows - size.rows);
    size.rows = rows;
  }
  if (cols > size.cols) {
    size.sh.insertColumnsAfter(size.cols, cols - size.cols);
    size.cols = cols;
  }
}

var KEY_ALPHABET_ = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

function newKey_() {
  var hex = (Utilities.getUuid() + Utilities.getUuid()).replace(/-/g, '');
  var key = '';
  for (var i = 0; i < 10; i++) key += KEY_ALPHABET_.charAt(parseInt(hex.substr(i * 2, 2), 16) % KEY_ALPHABET_.length);
  return key;
}

function cleanKey_(k) {
  return String(k || '')
    .toUpperCase()
    .replace(/[^A-Z0-9]/g, '');
}

// ---------------------------------------------------------------------------
// Menu (for connecting another phone)
// ---------------------------------------------------------------------------

function onOpen() {
  SpreadsheetApp.getUi()
    .createMenu('سند')
    .addItem('رمز الربط (Connection code)', 'showConnectionCode')
    .addItem('رمز جديد (يفصل الهواتف المربوطة)', 'newConnectionCode')
    .addToUi();
}

function showConnectionCode() {
  var ui = SpreadsheetApp.getUi();
  var key = PropertiesService.getScriptProperties().getProperty('SANAD_KEY');
  ui.alert(
    'سند',
    key
      ? 'رمز الربط: ' + key.substring(0, 5) + '-' + key.substring(5) +
          '\n\nاكتبه في تطبيق سند على الهاتف الآخر مع رابط الـ Web app.'
      : 'لم يتم ربط أي هاتف بعد. أول هاتف يتصل برابط الـ Web app يُربط تلقائياً.',
    ui.ButtonSet.OK
  );
}

function newConnectionCode() {
  var ui = SpreadsheetApp.getUi();
  var answer = ui.alert(
    'سند',
    'الهواتف المربوطة الآن ستحتاج إلى الربط من جديد. هل تريد المتابعة؟',
    ui.ButtonSet.YES_NO
  );
  if (answer !== ui.Button.YES) return;
  PropertiesService.getScriptProperties().deleteProperty('SANAD_KEY');
  ui.alert('سند', 'تم. أول هاتف يتصل الآن يُربط تلقائياً.', ui.ButtonSet.OK);
}
