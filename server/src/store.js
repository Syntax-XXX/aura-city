'use strict';
// Profile als eine JSON-Datei. Atomar schreiben (tmp + rename), alter Stand bleibt als .bak.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

const hashToken = (t) => crypto.createHash('sha256').update(String(t)).digest('hex');

class Store {
  constructor(file) {
    this.file = file;
    this.players = {};
    this.byToken = {};
    this.dirty = false;
    this._load();
  }

  _load() {
    for (const f of [this.file, this.file + '.bak']) {
      try {
        const data = JSON.parse(fs.readFileSync(f, 'utf8'));
        this.players = data.players || {};
        break;
      } catch (e) {
        if (e.code !== 'ENOENT') console.error(`Konnte ${f} nicht lesen: ${e.message}`);
      }
    }
    for (const p of Object.values(this.players)) this.byToken[p.token_hash] = p.id;
  }

  add(profile) {
    const token = crypto.randomBytes(24).toString('base64url');
    profile.token_hash = hashToken(token);
    this.players[profile.id] = profile;
    this.byToken[profile.token_hash] = profile.id;
    this.dirty = true;
    return token;
  }

  byAuth(token) {
    const id = this.byToken[hashToken(token)];
    return id ? this.players[id] : null;
  }

  flush() {
    if (!this.dirty) return;
    fs.mkdirSync(path.dirname(this.file), { recursive: true });
    const tmp = this.file + '.tmp';
    fs.writeFileSync(tmp, JSON.stringify({ version: 1, players: this.players }));
    JSON.parse(fs.readFileSync(tmp, 'utf8')); // vollständig lesbar?
    if (fs.existsSync(this.file)) fs.copyFileSync(this.file, this.file + '.bak');
    fs.renameSync(tmp, this.file);
    this.dirty = false;
  }
}

module.exports = { Store, hashToken };
