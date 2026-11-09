'use strict';
// Aura City Server – HTTP/JSON, keine externen Abhängigkeiten.
//   PORT (3710)  DATA_DIR (./data)  ADMIN_KEY (leer = Admin-API aus)  TZ_GAME (Europe/Berlin)
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { Game } = require('./src/game');
const { Store } = require('./src/store');

const PORT = Number(process.env.PORT || 3710);
const DATA_DIR = process.env.DATA_DIR || path.join(__dirname, 'data');
const ADMIN_KEY = process.env.ADMIN_KEY || '';
const VERSION = require('./package.json').version;

const gamedata = JSON.parse(fs.readFileSync(path.join(__dirname, 'gamedata.json'), 'utf8'));
const game = new Game(gamedata, { tz: process.env.TZ_GAME || 'Europe/Berlin' });
const store = new Store(path.join(DATA_DIR, 'players.json'));
const sessions = new Map(); // player id -> Session (nur im Speicher)
const buckets = new Map(); // Rate-Limits: key -> {n, reset}

function limited(key, max, windowMs) {
  const now = Date.now();
  const b = buckets.get(key);
  if (!b || now > b.reset) { buckets.set(key, { n: 1, reset: now + windowMs }); return false; }
  b.n += 1;
  return b.n > max;
}

function send(res, status, body) {
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Cache-Control': 'no-store',
  });
  res.end(JSON.stringify(body));
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let size = 0; const chunks = [];
    req.on('data', (c) => { size += c.length; if (size > 65536) { reject(new Error('too_large')); req.destroy(); } else chunks.push(c); });
    req.on('end', () => { try { resolve(chunks.length ? JSON.parse(Buffer.concat(chunks).toString('utf8')) : {}); } catch { reject(new Error('bad_json')); } });
    req.on('error', reject);
  });
}

function auth(req) {
  const m = /^Bearer (.+)$/.exec(req.headers.authorization || '');
  return m ? store.byAuth(m[1]) : null;
}

function safeEqual(a, b) {
  const x = Buffer.from(String(a)); const y = Buffer.from(String(b));
  return x.length === y.length && crypto.timingSafeEqual(x, y);
}

function leaderboard() {
  return Object.values(store.players)
    .filter((p) => Object.keys(p.flags).length === 0 && p.lifetime > 0)
    .sort((a, b) => b.lifetime - a.lifetime)
    .slice(0, 50)
    .map((p) => ({ name: p.name, score: p.lifetime, rank: game.rankFor(p.lifetime) }));
}

const routes = {
  'GET /api/health': () => [200, { ok: true, version: VERSION, time: Date.now(), players: Object.keys(store.players).length }],
  'GET /api/leaderboard': () => [200, { ok: true, entries: leaderboard(), time: Date.now() }],

  'POST /api/register': (req, body, ip) => {
    if (limited('reg:' + ip, 5, 3600000)) return [429, { ok: false, error: 'Zu viele neue Profile – später erneut versuchen' }];
    const profile = game.newProfile(body.name);
    const token = store.add(profile);
    sessions.set(profile.id, game.newSession());
    return [200, { ok: true, token, profile: game.toClient(profile), time: Date.now() }];
  },

  'POST /api/session': (req) => {
    const p = auth(req);
    if (!p) return [401, { ok: false, error: 'Unbekanntes Profil' }];
    sessions.set(p.id, game.newSession());
    return [200, { ok: true, profile: game.toClient(p), time: Date.now() }];
  },

  'POST /api/events': (req, body) => {
    const p = auth(req);
    if (!p) return [401, { ok: false, error: 'Unbekanntes Profil' }];
    if (limited('ev:' + p.id, 40, 10000)) return [429, { ok: false, error: 'Zu viele Anfragen' }];
    let s = sessions.get(p.id);
    if (!s) { s = game.newSession(); sessions.set(p.id, s); }
    const results = game.handleBatch(p, s, body.events, Date.now());
    store.dirty = true;
    return [200, { ok: true, results, profile: game.toClient(p), time: Date.now() }];
  },

  'GET /api/admin/flags': (req, body, ip, url) => {
    if (!ADMIN_KEY || !safeEqual(url.searchParams.get('key') || '', ADMIN_KEY)) return [403, { ok: false }];
    const list = Object.values(store.players)
      .filter((p) => Object.keys(p.flags).length || p.violations.length)
      .map((p) => ({ id: p.id, name: p.name, lifetime: p.lifetime, flags: p.flags, violations: p.violations.slice(-20) }));
    return [200, { ok: true, players: list }];
  },

  'POST /api/admin/unflag': (req, body, ip, url) => {
    if (!ADMIN_KEY || !safeEqual(url.searchParams.get('key') || '', ADMIN_KEY)) return [403, { ok: false }];
    const p = store.players[body.id];
    if (!p) return [404, { ok: false }];
    p.flags = {}; p.violations = []; p.perf_window = [];
    store.dirty = true;
    return [200, { ok: true }];
  },
};

const server = http.createServer(async (req, res) => {
  if (req.method === 'OPTIONS') return send(res, 204, {});
  const url = new URL(req.url, 'http://x');
  // hinter einem Pfad-Proxy (z. B. /auracity/api/…) funktioniert es ebenfalls
  const pathname = url.pathname.replace(/^.*?(\/api\/)/, '/api/');
  const route = routes[`${req.method} ${pathname}`];
  if (!route) return send(res, 404, { ok: false, error: 'not_found' });
  const ip = (req.headers['x-forwarded-for'] || req.socket.remoteAddress || '').split(',')[0].trim();
  try {
    const body = req.method === 'POST' ? await readBody(req) : {};
    const [status, out] = route(req, body, ip, url);
    send(res, status, out);
  } catch (e) {
    send(res, 400, { ok: false, error: e.message === 'too_large' ? 'too_large' : 'bad_request' });
  }
});

setInterval(() => { try { store.flush(); } catch (e) { console.error('Speichern fehlgeschlagen:', e.message); } }, 2000).unref();
for (const sig of ['SIGTERM', 'SIGINT']) {
  process.on(sig, () => { try { store.flush(); } finally { process.exit(0); } });
}

server.listen(PORT, () => console.log(`Aura City Server ${VERSION} auf :${PORT}, ${Object.keys(store.players).length} Profile`));
