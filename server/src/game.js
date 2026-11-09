'use strict';
// Server-autoritative Spielregeln für Aura City.
// Der Client meldet nur Ereignisse (Trick gelandet, Splitter eingesammelt, Kauf …) mit seinem
// Zeitstempel t (ms). Der Server rechnet Aura, Combo, Ketten, Quests und Erfolge selbst aus
// und prüft jedes Ereignis auf Plausibilität. Zahlen kommen aus gamedata.json (Export aus Godot).

const crypto = require('node:crypto');

const CLOCK_SLACK_MS = 3000; // Client-Uhr darf höchstens so viel schneller laufen als die echte Zeit
const TOLERANCE_MS = 150; // Netz-/Frame-Toleranz bei Cooldowns und Mindestabständen
const MAX_EVENTS_PER_BATCH = 64;
const PERFECT_WINDOW = 60; // Anzahl Tricks für die Perfect-Quoten-Prüfung
const PERFECT_FLAG_RATIO = 0.95;
const VIOLATION_FLAG_COUNT = 12; // Verstöße pro Stunde bis zur Markierung

class Game {
  constructor(data, opts = {}) {
    this.G = data;
    this.tz = opts.tz || 'Europe/Berlin';
    this.clock = opts.clock || (() => Date.now());
    this.starter = this._starterInventory();
  }

  // ── Zeit ───────────────────────────────────────────────
  dayKey(ms) { return new Date(ms).toLocaleDateString('sv-SE', { timeZone: this.tz }); }
  weekKey(ms) {
    const [y, m, d] = this.dayKey(ms).split('-').map(Number);
    const utc = Date.UTC(y, m - 1, d);
    const back = (new Date(utc).getUTCDay() + 6) % 7;
    return new Date(utc - back * 86400000).toISOString().slice(0, 10);
  }
  rushLeft(ms) {
    const r = this.G.constants.rush;
    const p = (ms / 1000) % r.period;
    return p < r.length ? r.length - p : 0;
  }
  rushMult(ms) { return this.rushLeft(ms) > 0 ? this.G.constants.rush.multiplier : 1; }

  // ── Profil ─────────────────────────────────────────────
  _starterInventory() {
    const owned = {}; const equipped = {};
    // gleiche Reihenfolge wie im Client (Rarität, dann Preis, dann Export-Reihenfolge)
    for (const [id, it] of Object.entries(this.G.items)) {
      if (!it.starter) continue;
      owned[id] = true;
      if (!equipped[it.slot]) equipped[it.slot] = id;
    }
    return { owned, equipped };
  }

  newProfile(name) {
    return {
      id: crypto.randomBytes(12).toString('hex'),
      name: cleanName(name) || 'Player',
      created: this.clock(),
      aura: 0, lifetime: 0, daily_last_claim: '', daily_streak: 0,
      owned: { ...this.starter.owned }, equipped: { ...this.starter.equipped },
      mastery: {}, loadout: [...this.G.starter_loadout],
      quests: { daily_key: '', weekly_key: '', progress: {}, completed: {}, visited_today: {}, visited_week: {} },
      ach: { unlocked: {}, stats: {}, districts: {} },
      found_secrets: {}, shard_times: {},
      flags: {}, violations: [], perf_window: [],
    };
  }

  newSession() {
    return { t0: null, r0: 0, lastT: -Infinity, lastLand: null, lastById: {}, combo: 0, chain: [], challenge: null, log: [] };
  }

  rankFor(lifetime) {
    let idx = 0;
    this.G.ranks.forEach((r, i) => { if (lifetime >= r.min) idx = i; });
    return idx;
  }

  unlockedTricks(p) {
    return Object.entries(this.G.tricks).filter(([, t]) => p.lifetime >= t.unlock).map(([id]) => id);
  }

  masteryLevel(p, id) {
    const hits = p.mastery[id] || 0;
    return this.G.constants.mastery_steps.filter((s) => hits >= s).length;
  }

  // Format exakt wie die from_dict()-Methoden im Client
  toClient(p) {
    this.checkReset(p);
    return {
      id: p.id, name: p.name, flagged: Object.keys(p.flags).length > 0,
      economy: { aura: p.aura, lifetime: p.lifetime, daily_last_claim: p.daily_last_claim, daily_streak: p.daily_streak },
      inventory: { owned: Object.keys(p.owned), equipped: p.equipped },
      tricks: { unlocked: this.unlockedTricks(p), mastery: p.mastery, loadout: p.loadout },
      quests: {
        daily_key: p.quests.daily_key, weekly_key: p.quests.weekly_key, progress: p.quests.progress,
        completed: Object.keys(p.quests.completed), visited_today: Object.keys(p.quests.visited_today),
        visited_week: Object.keys(p.quests.visited_week),
      },
      achievements: { unlocked: p.ach.unlocked, stats: p.ach.stats, districts: Object.keys(p.ach.districts) },
      found_secrets: Object.keys(p.found_secrets),
    };
  }

  // ── Gutschriften, Quests, Erfolge ─────────────────────
  grant(p, amount, ctx) {
    const g = Math.round(amount * this.rushMult(ctx.ms));
    if (!(g > 0)) return 0;
    p.aura += g;
    p.lifetime += g;
    ctx.granted += g;
    if (ctx.s) ctx.s.log.push({ t: ctx.t, kind: 'aura', aura: g });
    this.questAdd(p, 'aura', g, -1, ctx);
    this.setMax(p, 'lifetime_aura', Math.floor(p.lifetime), ctx);
    this.setMax(p, 'rank', this.rankFor(p.lifetime), ctx);
    return g;
  }

  checkReset(p) {
    const now = this.clock();
    const dk = this.dayKey(now); const wk = this.weekKey(now);
    const q = p.quests;
    if (q.daily_key !== dk) { q.daily_key = dk; q.visited_today = {}; this._resetPeriod(p, 0); }
    if (q.weekly_key !== wk) { q.weekly_key = wk; q.visited_week = {}; this._resetPeriod(p, 1); }
  }

  _resetPeriod(p, period) {
    for (const [id, def] of Object.entries(this.G.quests)) {
      if (def.period === period) { p.quests.progress[id] = 0; delete p.quests.completed[id]; }
    }
  }

  questAdd(p, stat, amount, period, ctx) {
    this.checkReset(p);
    for (const [id, def] of Object.entries(this.G.quests)) {
      if (def.stat !== stat || p.quests.completed[id] || (period >= 0 && def.period !== period)) continue;
      p.quests.progress[id] = Math.min(def.goal, (p.quests.progress[id] || 0) + amount);
      if (p.quests.progress[id] >= def.goal) {
        p.quests.completed[id] = true;
        this.grant(p, def.reward, ctx);
      }
    }
  }

  stat(p, name) { return p.ach.stats[name] || 0; }
  inc(p, name, n, ctx) { p.ach.stats[name] = this.stat(p, name) + n; this._checkAch(p, name, ctx); }
  setMax(p, name, v, ctx) { if (v > this.stat(p, name)) { p.ach.stats[name] = v; this._checkAch(p, name, ctx); } }
  _checkAch(p, name, ctx) {
    for (const [id, def] of Object.entries(this.G.achievements)) {
      if (def.stat === name && !p.ach.unlocked[id] && this.stat(p, name) >= def.goal) {
        p.ach.unlocked[id] = Math.floor(this.clock() / 1000);
        if (def.reward > 0) this.grant(p, def.reward, ctx);
      }
    }
  }

  requirementError(p, item) {
    if (this.rankFor(p.lifetime) < item.required_rank) return 'Benötigt Rang ' + this.G.ranks[item.required_rank].name;
    if (p.lifetime < item.required_lifetime) return 'Benötigt mehr Lifetime-Aura';
    if (item.required_achievement && !p.ach.unlocked[item.required_achievement]) return 'Benötigt einen Erfolg';
    return '';
  }

  // ── Anti-Cheat ─────────────────────────────────────────
  violation(p, reason, detail) {
    const now = this.clock();
    p.violations.push({ at: now, reason, detail: String(detail || '').slice(0, 120) });
    if (p.violations.length > 50) p.violations.splice(0, p.violations.length - 50);
    const recent = p.violations.filter((v) => now - v.at < 3600000).length;
    if (recent >= VIOLATION_FLAG_COUNT) this.flag(p, 'viele_verstoesse');
    return { ok: false, error: 'rejected', reason };
  }

  flag(p, reason) { if (!p.flags[reason]) p.flags[reason] = this.clock(); }

  // ── Ereignisse ─────────────────────────────────────────
  handleBatch(p, s, events, recvMs) {
    if (!Array.isArray(events)) return [];
    return events.slice(0, MAX_EVENTS_PER_BATCH).map((ev) => {
      try { return this.handle(p, s, ev, recvMs); } catch (e) { return { ok: false, error: 'invalid' }; }
    });
  }

  handle(p, s, ev, recvMs) {
    if (!ev || typeof ev.type !== 'string') return { ok: false, error: 'invalid' };
    const t = Number(ev.t);
    if (!Number.isFinite(t)) return { ok: false, error: 'invalid' };
    if (s.t0 === null) { s.t0 = t; s.r0 = recvMs; }
    if (t < s.lastT) return this.violation(p, 'uhr_rueckwaerts', `${t} < ${s.lastT}`);
    if (t - s.t0 > recvMs - s.r0 + CLOCK_SLACK_MS) return this.violation(p, 'speedhack', `client ${t - s.t0} ms vs server ${recvMs - s.r0} ms`);
    s.lastT = t;
    const ctx = { s, t, ms: s.r0 + (t - s.t0), granted: 0 };
    const fn = HANDLERS[ev.type];
    if (!fn) return { ok: false, error: 'unknown_type' };
    const res = fn.call(this, p, s, ev, ctx);
    if (res.ok && ctx.granted) res.granted = ctx.granted;
    return res;
  }
}

const HANDLERS = {
  trick(p, s, ev, ctx) {
    const def = this.G.tricks[ev.id];
    if (!def) return { ok: false, error: 'unknown_trick' };
    if (p.lifetime < def.unlock) return this.violation(p, 'trick_gesperrt', ev.id);
    const quality = ev.quality;
    if (!['perfect', 'good', 'fail'].includes(quality)) return { ok: false, error: 'invalid' };
    const last = s.lastLand;
    if (last && ctx.t - last.t < last.duration * 1000 - TOLERANCE_MS) return this.violation(p, 'zu_schnell', `${ctx.t - last.t} ms`);
    const lastSame = s.lastById[ev.id];
    if (lastSame !== undefined && ctx.t - lastSame < def.cooldown * 1000 - TOLERANCE_MS) return this.violation(p, 'cooldown', `${ev.id} ${ctx.t - lastSame} ms`);
    s.lastById[ev.id] = ctx.t;
    if (quality === 'fail') {
      s.combo = 0; s.chain = [];
      s.lastLand = { t: ctx.t, duration: 0 };
      return { ok: true };
    }
    const C = this.G.constants;
    const window = ((last ? last.duration : 0) + C.combo_window + C.timing_timeout + 0.6) * 1000;
    if (last && s.combo > 0 && ctx.t - last.t <= window) s.combo += 1;
    else { s.combo = 1; s.chain = []; }
    s.chain.push(ev.id);
    s.lastLand = { t: ctx.t, duration: def.duration };
    const comboMult = Math.min(Math.max(1 + (s.combo - 1) * 0.25, 1), C.combo_cap) + (s.combo > 1 ? def.combo_bonus : 0);
    const challenge = s.challenge && ctx.t <= s.challenge.until ? C.challenge_mult : 1;
    const amount = Math.round(def.base_aura * (1 + def.difficulty * 0.08) * C.quality_mult[quality]
      * Math.min(Math.max(comboMult, 1), C.combo_cap) * (1 + this.masteryLevel(p, ev.id) * 0.1) * challenge);
    const granted = this.grant(p, amount, ctx);
    s.log.push({ t: ctx.t, kind: 'trick', quality, combo: s.combo });
    if (s.log.length > 400) s.log.splice(0, s.log.length - 400);
    p.mastery[ev.id] = (p.mastery[ev.id] || 0) + 1;
    this.inc(p, 'tricks', 1, ctx);
    if (quality === 'perfect') this.inc(p, 'perfects', 1, ctx);
    this.setMax(p, 'best_combo', s.combo, ctx);
    this.questAdd(p, 'trick', 1, -1, ctx);
    if (s.combo === 3) this.questAdd(p, 'combo', 1, -1, ctx);
    // Ketten
    for (const chain of this.G.chains) {
      const n = chain.sequence.length;
      if (s.chain.length >= n && chain.sequence.every((id, i) => s.chain[s.chain.length - n + i] === id)) {
        this.grant(p, chain.bonus * challenge, ctx);
      }
    }
    // Perfect-Quote: Bots/manipulierte Clients landen (fast) immer perfekt
    p.perf_window.push(quality === 'perfect' ? 1 : 0);
    if (p.perf_window.length > PERFECT_WINDOW) p.perf_window.splice(0, p.perf_window.length - PERFECT_WINDOW);
    if (p.perf_window.length >= PERFECT_WINDOW && p.perf_window.reduce((a, b) => a + b, 0) / PERFECT_WINDOW >= PERFECT_FLAG_RATIO) {
      this.flag(p, 'perfect_quote');
    }
    return { ok: true, aura: granted, combo: s.combo };
  },

  collectible(p, s, ev, ctx) {
    const def = this.G.collectibles[ev.id];
    if (!def) return { ok: false, error: 'unknown_collectible' };
    if (def.secret) {
      if (p.found_secrets[ev.id]) return this.violation(p, 'geheimnis_doppelt', ev.id);
      p.found_secrets[ev.id] = true;
    } else {
      const last = p.shard_times[ev.id];
      const respawn = this.G.constants.collectible_respawn * 1000;
      if (last !== undefined && ctx.ms - last < respawn - 5000) return this.violation(p, 'splitter_respawn', ev.id);
      p.shard_times[ev.id] = ctx.ms;
    }
    this.grant(p, def.reward * (def.secret ? this.G.constants.secret_multiplier : 1), ctx);
    this.inc(p, 'collectibles', 1, ctx);
    if (ev.id.startsWith('secret')) this.inc(p, 'secret_found', 1, ctx);
    this.questAdd(p, 'collectible', 1, -1, ctx);
    return { ok: true };
  },

  district(p, s, ev, ctx) {
    if (!this.G.districts.includes(ev.id)) return { ok: false, error: 'unknown_district' };
    this.checkReset(p);
    if (!p.quests.visited_today[ev.id]) { p.quests.visited_today[ev.id] = true; this.questAdd(p, 'district', 1, 0, ctx); }
    if (!p.quests.visited_week[ev.id]) { p.quests.visited_week[ev.id] = true; this.questAdd(p, 'district', 1, 1, ctx); }
    if (!p.ach.districts[ev.id]) {
      p.ach.districts[ev.id] = true;
      this.setMax(p, 'districts', Object.keys(p.ach.districts).length, ctx);
      if (ev.id === 'secret') this.setMax(p, 'secret_found', Math.max(1, this.stat(p, 'secret_found')), ctx);
    }
    return { ok: true };
  },

  challenge_start(p, s, ev, ctx) {
    const def = this.G.challenges[ev.id];
    if (!def) return { ok: false, error: 'unknown_challenge' };
    s.challenge = { id: ev.id, start: ctx.t, until: ctx.t + def.seconds * 1000 + 1000 };
    return { ok: true };
  },

  challenge_done(p, s, ev, ctx) {
    const def = this.G.challenges[ev.id];
    const c = s.challenge;
    if (!def || !c || c.id !== ev.id) return this.violation(p, 'challenge_nicht_gestartet', ev.id);
    s.challenge = null;
    if (ctx.t > c.until + 500) return this.violation(p, 'challenge_zeit', ev.id);
    // Gegen das eigene Protokoll prüfen, ob das Ziel wirklich erreicht wurde
    const log = s.log.filter((e) => e.t >= c.start && e.t <= ctx.t);
    let progress = 0;
    if (def.kind === 'perfects') progress = log.filter((e) => e.kind === 'trick' && e.quality === 'perfect').length;
    else if (def.kind === 'combo') progress = log.reduce((m, e) => (e.kind === 'trick' ? Math.max(m, e.combo) : m), 0);
    else progress = log.reduce((sum, e) => (e.kind === 'aura' ? sum + e.aura : sum), 0);
    if (progress < def.goal) return this.violation(p, 'challenge_ziel', `${ev.id} ${progress}/${def.goal}`);
    this.grant(p, def.reward, ctx);
    this.inc(p, 'challenges', 1, ctx);
    this.questAdd(p, 'challenge', 1, -1, ctx);
    return { ok: true };
  },

  daily(p, s, ev, ctx) {
    const now = this.clock();
    const today = this.dayKey(now);
    if (p.daily_last_claim === today) return { ok: false, error: 'Heute schon abgeholt' };
    const yesterday = this.dayKey(now - 86400000);
    p.daily_streak = p.daily_last_claim === yesterday ? p.daily_streak + 1 : 1;
    p.daily_last_claim = today;
    this.grant(p, this.G.constants.daily_base * Math.min(p.daily_streak, 7), ctx);
    return { ok: true };
  },

  buy(p, s, ev, ctx) {
    const item = this.G.items[ev.id];
    if (!item) return { ok: false, error: 'Unbekanntes Item' };
    if (p.owned[ev.id]) return { ok: false, error: 'Schon im Besitz' };
    const req = this.requirementError(p, item);
    if (req) return { ok: false, error: req };
    if (p.aura < item.price) return { ok: false, error: 'Nicht genug Aura' };
    p.aura -= item.price;
    p.owned[ev.id] = true;
    this.questAdd(p, 'unlock', 1, -1, ctx);
    this.setMax(p, 'legendary_items', Object.keys(p.owned).filter((id) => (this.G.items[id] || {}).rarity >= 4).length, ctx);
    return { ok: true };
  },

  equip(p, s, ev) {
    const slot = String(ev.slot || '');
    if (!this.G.slots.includes(slot)) return { ok: false, error: 'invalid' };
    if (!ev.id) {
      if (slot !== 'skin') delete p.equipped[slot];
      return { ok: true };
    }
    const item = this.G.items[ev.id];
    if (!item || !p.owned[ev.id] || item.slot !== slot) return { ok: false, error: 'Nicht im Besitz' };
    p.equipped[slot] = ev.id;
    return { ok: true };
  },

  loadout(p, s, ev) {
    const slot = Number(ev.slot);
    const def = this.G.tricks[ev.id];
    if (!(slot >= 0 && slot < 4) || !def || p.lifetime < def.unlock) return { ok: false, error: 'invalid' };
    const existing = p.loadout.indexOf(ev.id);
    if (existing >= 0) p.loadout[existing] = p.loadout[slot];
    p.loadout[slot] = ev.id;
    return { ok: true };
  },

  name(p, s, ev) {
    const n = cleanName(ev.name);
    if (!n) return { ok: false, error: 'Ungültiger Name' };
    p.name = n;
    return { ok: true };
  },
};

function cleanName(name) {
  return String(name || '').replace(/[\u0000-\u001f\u007f<>]/g, '').trim().slice(0, 16);
}

module.exports = { Game, cleanName, CLOCK_SLACK_MS };
