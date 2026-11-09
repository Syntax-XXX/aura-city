'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { Game } = require('../src/game');

const data = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'gamedata.json'), 'utf8'));
const BASE = 1700000200 * 1000; // außerhalb eines Aura Rush (Rest 100 s von 300 s)

function setup() {
  let now = BASE;
  const game = new Game(data, { clock: () => now });
  const p = game.newProfile('Tester');
  const s = game.newSession();
  // Ereignis zur Client-Zeit t (ms seit Sitzungsbeginn); Server empfängt „jetzt“ = BASE + t
  const ev = (t, e) => { now = BASE + t; return game.handle(p, s, { t, ...e }, now); };
  return { game, p, s, ev, setNow: (v) => { now = v; } };
}

test('frisches Profil: keine Aura, Startitems ausgerüstet', () => {
  const { game, p } = setup();
  assert.equal(p.aura, 0);
  const c = game.toClient(p);
  assert.ok(c.inventory.owned.includes('skin_warm'));
  const firstSkin = Object.keys(data.items).find((id) => data.items[id].starter && data.items[id].slot === 'skin');
  assert.equal(c.inventory.equipped.skin, firstSkin); // gleiche Reihenfolge wie Inventory.reset() im Client
  assert.deepEqual(c.tricks.loadout, ['basic_spin', 'finger_flip', 'mini_pose', 'side_twist']);
  assert.deepEqual(c.tricks.unlocked.sort(), ['basic_spin', 'finger_flip', 'mini_pose', 'side_twist'].sort());
});

test('Trick-Aura wie im Client berechnet', () => {
  const { p, ev } = setup();
  const t = data.tricks.basic_spin;
  const r = ev(0, { type: 'trick', id: 'basic_spin', quality: 'good' });
  assert.ok(r.ok);
  assert.equal(r.aura, Math.round(t.base_aura * (1 + t.difficulty * 0.08)));
  assert.equal(p.aura, r.aura + 100); // + Erfolg „First Trick“ (100)
  assert.ok(p.ach.unlocked.first_trick);
});

test('gesperrter Trick wird abgelehnt', () => {
  const { p, ev } = setup();
  const r = ev(0, { type: 'trick', id: 'aura_explosion', quality: 'perfect' });
  assert.equal(r.ok, false);
  assert.equal(p.aura, 0);
  assert.equal(p.violations[0].reason, 'trick_gesperrt');
});

test('Cooldown und Mindestabstand werden geprüft', () => {
  const { p, ev } = setup();
  const t = data.tricks.side_twist; // Cooldown 1,0 s > Dauer 0,7 s
  assert.ok(ev(0, { type: 'trick', id: 'side_twist', quality: 'good' }).ok);
  const tooFast = ev(100, { type: 'trick', id: 'finger_flip', quality: 'good' });
  assert.equal(tooFast.reason, 'zu_schnell');
  const again = ev(t.duration * 1000 + 100, { type: 'trick', id: 'side_twist', quality: 'good' });
  assert.equal(again.reason, 'cooldown');
  assert.ok(ev(t.cooldown * 1000 + 50, { type: 'trick', id: 'side_twist', quality: 'good' }).ok);
  assert.equal(p.violations.length, 2);
});

test('Speedhack: Client-Uhr schneller als echte Zeit', () => {
  const { game, p, s, setNow } = setup();
  setNow(BASE);
  assert.ok(game.handle(p, s, { t: 0, type: 'district', id: 'spawn' }, BASE).ok);
  // Client behauptet 60 s später, Server sieht nur 10 s
  const r = game.handle(p, s, { t: 60000, type: 'district', id: 'skate' }, BASE + 10000);
  assert.equal(r.reason, 'speedhack');
  const back = game.handle(p, s, { t: -5, type: 'district', id: 'skate' }, BASE + 11000);
  assert.equal(back.reason, 'uhr_rueckwaerts');
});

test('Combo und Kette „Street Starter“ geben Bonus', () => {
  const { p, s, ev } = setup();
  let t = 0;
  for (const id of ['finger_flip', 'side_twist', 'basic_spin']) {
    const r = ev(t, { type: 'trick', id, quality: 'good' });
    assert.ok(r.ok, JSON.stringify(r));
    t += data.tricks[id].duration * 1000 + 300;
  }
  assert.equal(s.combo, 3);
  const chain = data.chains.find((c) => c.name === 'Street Starter');
  assert.ok(p.lifetime > chain.bonus);
  // Fehlversuch beendet die Combo
  ev(t + 5000, { type: 'trick', id: 'mini_pose', quality: 'fail' });
  assert.equal(s.combo, 0);
});

test('Kauf nur mit genug Aura und erfüllten Bedingungen', () => {
  const { p, ev } = setup();
  const [id, item] = Object.entries(data.items).find(([, i]) => !i.starter && i.required_rank === 0 && !i.required_achievement && i.required_lifetime === 0);
  assert.equal(ev(0, { type: 'buy', id }).error, 'Nicht genug Aura');
  p.aura = item.price; p.lifetime = Math.max(p.lifetime, item.price);
  assert.ok(ev(10, { type: 'buy', id }).ok);
  assert.equal(p.aura, 0);
  assert.equal(ev(20, { type: 'buy', id }).error, 'Schon im Besitz');
  const [rid, ritem] = Object.entries(data.items).find(([, i]) => i.required_rank >= 3);
  p.aura = ritem.price + 1;
  assert.match(ev(30, { type: 'buy', id: rid }).error, /Rang/);
  assert.ok(ev(40, { type: 'equip', slot: item.slot, id }).ok);
  assert.equal(p.equipped[item.slot], id);
  assert.equal(ev(50, { type: 'equip', slot: ritem.slot, id: rid }).ok, false);
});

test('Splitter: Respawn-Zeit und Geheimnisse nur einmal', () => {
  const { p, ev } = setup();
  const shard = Object.keys(data.collectibles).find((k) => !data.collectibles[k].secret);
  const secret = Object.keys(data.collectibles).find((k) => data.collectibles[k].secret);
  assert.ok(ev(0, { type: 'collectible', id: shard }).ok);
  assert.equal(ev(1000, { type: 'collectible', id: shard }).reason, 'splitter_respawn');
  assert.ok(ev(data.constants.collectible_respawn * 1000, { type: 'collectible', id: shard }).ok);
  const before = p.aura;
  assert.ok(ev(200000, { type: 'collectible', id: secret }).ok);
  assert.ok(p.aura > before);
  assert.equal(ev(201000, { type: 'collectible', id: secret }).reason, 'geheimnis_doppelt');
  assert.equal(ev(202000, { type: 'collectible', id: 'erfunden' }).error, 'unknown_collectible');
});

test('Challenge: Belohnung nur, wenn das Ziel im Server-Protokoll steht', () => {
  const { p, ev } = setup();
  const name = 'Erste Schritte'; // 2 Perfects
  assert.ok(ev(0, { type: 'challenge_start', id: name }).ok);
  assert.equal(ev(1000, { type: 'challenge_done', id: name }).reason, 'challenge_ziel');
  assert.ok(ev(2000, { type: 'challenge_start', id: name }).ok);
  ev(3000, { type: 'trick', id: 'basic_spin', quality: 'perfect' });
  ev(5000, { type: 'trick', id: 'finger_flip', quality: 'perfect' });
  const before = p.aura;
  const r = ev(6000, { type: 'challenge_done', id: name });
  assert.ok(r.ok, JSON.stringify(r));
  assert.ok(p.aura - before >= data.challenges[name].reward);
  assert.equal(ev(7000, { type: 'challenge_done', id: name }).reason, 'challenge_nicht_gestartet');
});

test('Challenge-Multiplikator ×1,5 während aktiver Challenge', () => {
  const a = setup(); const b = setup();
  a.ev(0, { type: 'challenge_start', id: 'Präzision' });
  const ra = a.ev(10, { type: 'trick', id: 'basic_spin', quality: 'good' });
  const rb = b.ev(10, { type: 'trick', id: 'basic_spin', quality: 'good' });
  assert.equal(ra.aura, Math.round(rb.aura * 1.5));
});

test('verdächtige Perfect-Quote wird markiert, aber nicht gesperrt', () => {
  const { game, p, ev } = setup();
  let t = 0;
  for (let i = 0; i < 70; i += 1) {
    const id = ['basic_spin', 'finger_flip', 'mini_pose', 'side_twist'][i % 4];
    const r = ev(t, { type: 'trick', id, quality: 'perfect' });
    assert.ok(r.ok, `${i}: ${JSON.stringify(r)}`);
    t += 4000;
  }
  assert.ok(p.flags.perfect_quote);
  assert.equal(game.toClient(p).flagged, true);
});

test('Tagesbelohnung einmal pro Tag, Serie wächst', () => {
  const { p, ev, setNow, game, s } = setup();
  assert.ok(ev(0, { type: 'daily' }).ok);
  assert.equal(p.daily_streak, 1);
  assert.equal(ev(10, { type: 'daily' }).ok, false);
  setNow(BASE + 86400000);
  assert.ok(game.handle(p, s, { t: 20, type: 'daily' }, BASE + 86400000).ok);
  assert.equal(p.daily_streak, 2);
});

test('Tagesquests werden am nächsten Tag zurückgesetzt', () => {
  const { p, ev, setNow, game } = setup();
  ev(0, { type: 'trick', id: 'basic_spin', quality: 'good' });
  assert.equal(p.quests.progress.daily_tricks, 1);
  setNow(BASE + 86400000);
  game.checkReset(p);
  assert.equal(p.quests.progress.daily_tricks, 0);
});

test('Wochenschlüssel ist der Montag', () => {
  const { game } = setup();
  assert.equal(game.weekKey(Date.UTC(2026, 10, 11, 12)), '2026-11-09'); // Mi → Mo
  assert.equal(game.weekKey(Date.UTC(2026, 10, 15, 12)), '2026-11-09'); // So → Mo davor
});

test('Name wird bereinigt, Loadout nur mit freigeschalteten Tricks', () => {
  const { p, ev } = setup();
  assert.ok(ev(0, { type: 'name', name: '<b>Hacker</b>\u0000XYZ_sehr_langer_Name' }).ok);
  assert.equal(p.name, 'bHacker/bXYZ_seh');
  assert.equal(ev(10, { type: 'loadout', slot: 0, id: 'aura_explosion' }).ok, false);
  assert.ok(ev(20, { type: 'loadout', slot: 0, id: 'mini_pose' }).ok);
  assert.deepEqual(p.loadout, ['mini_pose', 'finger_flip', 'basic_spin', 'side_twist']);
});

test('Aura-Drink: Rang + Preis geprüft, Boost wirkt serverseitig', () => {
  const { p, ev } = setup();
  const [id, d] = Object.entries(data.drinks).find(([, x]) => x.rank === 0);
  assert.equal(ev(0, { type: 'drink', id }).error, 'Nicht genug Aura');
  const [hid] = Object.entries(data.drinks).find(([, x]) => x.rank >= 3);
  p.aura = 1e7;
  assert.match(ev(10, { type: 'drink', id: hid }).error, /Rang/);
  p.aura = d.price;
  assert.ok(ev(20, { type: 'drink', id }).ok);
  assert.equal(p.aura, 0);
  const t = data.tricks.basic_spin;
  const r = ev(1000, { type: 'trick', id: 'basic_spin', quality: 'good' });
  assert.equal(r.aura, Math.round(Math.round(t.base_aura * (1 + t.difficulty * 0.08)) * d.aura));
  // nach Ablauf kein Boost mehr
  const r2 = ev(d.seconds * 1000 + 5000, { type: 'trick', id: 'basic_spin', quality: 'good' });
  assert.equal(r2.aura, Math.round(t.base_aura * (1 + t.difficulty * 0.08)));
});
