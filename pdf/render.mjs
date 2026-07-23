// Render an HTML file (or URL) to a print-ready PDF with a page-number footer,
// driving the installed Google Chrome over the DevTools Protocol. The plain
// `chrome --headless --print-to-pdf` CLI cannot set a footer template, which is
// why this exists. No npm install — uses Node's built-in fetch + WebSocket
// (Node 22+) and whatever Chrome is on the machine.
//
//   node render.mjs <input.html | http(s)://url> <out.pdf> [options]
//
// Options:
//   --no-footer            omit the page-number footer
//   --footer '<html>'      custom footer template (Chrome fills <span class="pageNumber">
//                          and <span class="totalPages">); default = centred page number
//   --a4                   A4 paper (default US Letter)
//   --margin <inches>      uniform page margin (default 0.7in top/bottom, 0.67 sides)
//   --wait <ms>            settle time after load for images/fonts (default 1800)
//   --no-background        don't print background colours/images
//   --chrome <path>        Chrome binary (default: env CHROME, else macOS Google Chrome)
import { spawn } from 'node:child_process';
import { setTimeout as sleep } from 'node:timers/promises';
import { writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

const argv = process.argv.slice(2);
const [input, outPath] = argv.filter(a => !a.startsWith('--'));
if (!input || !outPath) {
  console.error('usage: node render.mjs <input.html|url> <out.pdf> [--no-footer] [--footer html] [--a4] [--margin in] [--wait ms] [--no-background] [--chrome path]');
  process.exit(2);
}
const opt = (name, def) => { const i = argv.indexOf(name); return i >= 0 && argv[i + 1] ? argv[i + 1] : def; };
const has = (name) => argv.includes(name);

const CHROME = opt('--chrome', process.env.CHROME || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome');
const url = /^https?:\/\/|^file:\/\//.test(input) ? input : 'file://' + resolve(input);
const a4 = has('--a4');
const margin = parseFloat(opt('--margin', '')) || null;
const wait = parseInt(opt('--wait', '1800'), 10);
const wantFooter = !has('--no-footer');
const footer = opt('--footer',
  `<div style="width:100%;font-size:9px;text-align:center;color:#6b7b86;font-family:Helvetica,Arial,sans-serif;"><span class="pageNumber"></span></div>`);
const EMPTY = '<span></span>';
const PORT = 9333 + (process.pid % 500);

const chrome = spawn(CHROME, [
  '--headless=new', '--disable-gpu', '--no-first-run', '--no-default-browser-check',
  `--remote-debugging-port=${PORT}`, `--user-data-dir=/tmp/cdp-pdf-${PORT}`, 'about:blank',
], { stdio: 'ignore' });

const getJSON = async (path, method = 'GET') =>
  (await fetch(`http://127.0.0.1:${PORT}${path}`, { method })).json();

let up = false;
for (let i = 0; i < 100; i++) { try { await getJSON('/json/version'); up = true; break; } catch { await sleep(100); } }
if (!up) { console.error('Chrome debug endpoint never came up — is Google Chrome installed?'); chrome.kill(); process.exit(1); }

let target;
try { target = await getJSON('/json/new?about:blank', 'PUT'); }
catch { target = await getJSON('/json/new?about:blank', 'GET'); }

const ws = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((res, rej) => { ws.onopen = res; ws.onerror = rej; });

let msgId = 0; const pending = new Map(); let waiters = [];
ws.onmessage = (e) => {
  const m = JSON.parse(e.data);
  if (m.id && pending.has(m.id)) { pending.get(m.id)(m.result); pending.delete(m.id); }
  else if (m.method) waiters = waiters.filter(w => (w.method === m.method ? (w.resolve(m), false) : true));
};
const send = (method, params = {}) => new Promise(res => { const id = ++msgId; pending.set(id, res); ws.send(JSON.stringify({ id, method, params })); });
const waitEvent = (method) => new Promise(resolve => waiters.push({ method, resolve }));

await send('Page.enable');
const loaded = waitEvent('Page.loadEventFired');
await send('Page.navigate', { url });
await loaded;
await sleep(wait);

const result = await send('Page.printToPDF', {
  displayHeaderFooter: wantFooter,
  headerTemplate: EMPTY,
  footerTemplate: wantFooter ? footer : EMPTY,
  printBackground: !has('--no-background'),
  paperWidth: a4 ? 8.27 : 8.5,
  paperHeight: a4 ? 11.69 : 11,
  marginTop: margin ?? 0.71, marginBottom: margin ?? 0.68,
  marginLeft: margin ?? 0.67, marginRight: margin ?? 0.67,
  preferCSSPageSize: false,
});
writeFileSync(outPath, Buffer.from(result.data, 'base64'));
ws.close();
chrome.kill();
console.log(`wrote ${outPath}`);
process.exit(0);
