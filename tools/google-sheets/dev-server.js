// Local stand-in for a deployed Sanad connector, for development and
// end-to-end tests: runs the real Code.gs against an in-memory spreadsheet and
// answers like Google does (POST → 302 → GET with the JSON result).
//
//   node tools/google-sheets/dev-server.js [workbook.json] [port]
//
// Port 0 picks a free port; the first line printed is the connector URL.
// workbook.json: {"title": "...", "sheets": [{"name": "...", "rows": [[...]]}]}
// where dates are {"d": "yyyy-MM-dd"} and "=…" strings are formulas.
// GET /state returns the current content of every sheet; GET /code the
// connection code (what the sheet's "سند" menu shows), to connect a second
// phone.
'use strict';

const http = require('node:http');
const fs = require('node:fs');
const { FakeSpreadsheet, loadConnector, Utilities } = require('./test/fake_sheets');

const [file, portArg] = process.argv.slice(2);
const port = Number(portArg || 8787);
const TZ = 'Africa/Cairo';

function load(path) {
  const json = path ? JSON.parse(fs.readFileSync(path, 'utf8')) : { title: 'Sanad (dev)', sheets: [{ name: 'Sheet1', rows: [] }] };
  const ss = new FakeSpreadsheet(json.title, TZ);
  for (const sheet of json.sheets) {
    const target = ss.insertSheet(sheet.name);
    sheet.rows.forEach((line, r) =>
      line.forEach((v, c) => {
        if (v === null || v === '') return;
        const value = typeof v === 'object' && v.d ? Utilities.parseDate(v.d, TZ, 'yyyy-MM-dd') : v;
        // Text stays text (as in the original file); "=…" is a formula.
        target.getRange(r + 1, c + 1).setValue(typeof value === 'string' && !value.startsWith('=') ? "'" + value : value);
      }),
    );
  }
  return ss;
}

const ss = load(file);
const connector = loadConnector(ss);
const results = new Map();
let counter = 0;

const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': '*' };

function dump() {
  return ss.getSheets().map((sheet) => ({
    name: sheet.getName(),
    rows: Array.from({ length: sheet.getLastRow() }, (_, i) =>
      sheet.row(i + 1).map((v) => (v instanceof Date ? Utilities.formatDate(v, TZ, 'yyyy-MM-dd') : v)),
    ),
  }));
}

http
  .createServer((req, res) => {
    const url = new URL(req.url, `http://${req.headers.host}`);
    if (req.method === 'OPTIONS') {
      res.writeHead(204, cors).end();
      return;
    }
    if (req.method === 'POST' && url.pathname === '/exec') {
      let body = '';
      req.on('data', (chunk) => (body += chunk));
      req.on('end', () => {
        const out = connector.context.doPost({ postData: { contents: body } }).getContent();
        const id = String(++counter);
        results.set(id, out);
        res.writeHead(302, { ...cors, Location: `http://${req.headers.host}/echo?id=${id}` }).end();
      });
      return;
    }
    if (req.method === 'GET' && url.pathname === '/echo') {
      const out = results.get(url.searchParams.get('id'));
      res.writeHead(out ? 200 : 404, { ...cors, 'Content-Type': 'application/json; charset=utf-8' }).end(out || '{}');
      return;
    }
    if (req.method === 'GET' && url.pathname === '/exec') {
      res.writeHead(200, { ...cors, 'Content-Type': 'text/plain' }).end(connector.context.doGet().getContent());
      return;
    }
    if (req.method === 'GET' && url.pathname === '/code') {
      res.writeHead(200, { ...cors, 'Content-Type': 'text/plain' }).end(connector.props.get('SANAD_KEY') || '');
      return;
    }
    if (req.method === 'GET' && url.pathname === '/state') {
      res.writeHead(200, { ...cors, 'Content-Type': 'application/json; charset=utf-8' }).end(JSON.stringify(dump()));
      return;
    }
    res.writeHead(404, cors).end();
  })
  .listen(port, '127.0.0.1', function () {
    console.log(`Sanad connector (dev) on http://127.0.0.1:${this.address().port}/exec`);
  });
