# AURA CITY – Entwicklung

Stand: 2026-11-09 · Godot 4.3 (gl_compatibility) · GDScript · Server: Node ≥ 20

## Status

| Bereich | Stand |
|---|---|
| Welt (9 Distrikte, 900 × 900 m, Straßen, Vororte) | fertig, Physik und Erreichbarkeit automatisch getestet |
| Spieler (Controller, Kamera, Animationszustände) | fertig |
| Tricks, Combos, Ketten, Meisterschaft | fertig |
| Wirtschaft, Ränge, Events, Tagesbelohnung | fertig |
| Shop, Inventar, Garderobe | fertig |
| Quests, Erfolge | fertig |
| UI (alle Menüs, HUD, Minimap, Tutorial) | fertig, nur headless getestet |
| Speichern (versioniert, atomar, Backup) | fertig |
| Online: server-autoritative Aura, Profile, Bestenliste | fertig, End-to-End getestet |
| Echtzeit-Multiplayer (andere Spieler sehen) | nicht umgesetzt |
| Figuren + Animationen (Quaternius CC0, Retarget UAL → Stadtfiguren) | fertig |
| Grafik (PBR, Himmel, Wasser, Natur, Props, Verkehr) | fertig, nur Lab-Szene gerendert |
| Hoverboards, Aura-Drinks, Aura-Battles, Foto-Modus, Distrikt-Musik | fertig |
| Exporte Windows/Linux + Forgejo-CI | Presets + `.forgejo/workflows/build.yml` vorhanden |

## Architektur

- **Autoloads** (Reihenfolge wichtig): Controls, Events (Signal-Bus), Settings (eigene Datei
  `user://settings.json`), Audio, ItemDB, TrickDB, Identity, Economy, Inventory, Quests, Achievements,
  SaveSystem (Offline-Spielstand `user://aura_city_save.json`), Net (Server-Client).
- **Daten** als `.tres` in `resources/`, erzeugt von `tools/gen_resources.py`.
- **Welt:** `scripts/world/world_root.gd` baut Umgebung, Straßen und Vororte. Jeder Distrikt hat ein
  eigenes Skript in `scripts/world/districts/` und verwendet `WorldKit` (Geometrie) und `DistrictBuilder`
  (Shops, NPCs, Challenges, Splitter, Teleporter).
- **UI:** `UIRoot` verwaltet Screens, Hotkeys, Maus-Modus und die Eingabesperre. Alle Screens erben von `UIScreen`.
- **Ablauf:** `scripts/core/main.gd`: Hauptmenü → Ladebildschirm → Welt + Spieler + UI.
  Startargumente nach `--`: `--tests`, `--smoke`, `--online-test <url>`, `--export-data <pfad>`,
  `--lab <ordner>` (Vorzeige-Szene rendern), `--shot <ordner>` (Stadtrundgang), `--count` (Render-Objekte), `--prof`.

## Online-Modus und Anti-Cheat

Online gilt allein der Server. Der Client rechnet zwar lokal mit, aber nur für Effekte wie „+X ✦“.
Den Aura-Stand übernimmt er immer vom Server.

1. Der Client schickt nur **Ereignisse** mit seinem Zeitstempel `t` (ms seit Spielstart), in Reihenfolge
   und gebündelt: `trick` (id, quality), `collectible`, `district`, `challenge_start/done`, `daily`,
   `buy`, `equip`, `loadout`, `name`.
2. Der Server (`server/src/game.js`) berechnet daraus Aura, Combo, Ketten, Meisterschaft, Quests,
   Erfolge und Rang selbst. Die Zahlen kommen aus `server/gamedata.json`, einem Export aus Godot
   (`--export-data`). Dadurch rechnen Client und Server mit denselben Regeln. Der E2E-Test prüft, dass
   die Client-Vorschau exakt dem Serverwert entspricht.
3. **Prüfungen:**
   - Die Client-Uhr darf nicht schneller laufen als die echte Zeit (Speedhack).
   - Zeitstempel dürfen nicht zurücklaufen.
   - Zwischen zwei Tricks muss mindestens die Animationsdauer liegen, zwischen Wiederholungen desselben Tricks der Cooldown.
   - Tricks müssen über die Lifetime-Aura freigeschaltet sein.
   - Splitter müssen die Respawn-Zeit einhalten, geheime Splitter zählen nur einmal.
   - Bei Challenges muss das Ziel im eigenen Trick-Protokoll des Servers stehen.
   - Käufe brauchen genug Aura und erfüllte Bedingungen.
4. **Verdacht:** Liegt die Perfect-Quote über 60 Tricks bei mindestens 95 % oder gibt es mindestens 12 Verstöße pro Stunde,
   wird das Profil markiert. Es erscheint dann nicht mehr in der Bestenliste, und der Spieler sieht im HUD
   „Profil wird geprüft“. Abgelehnte Ereignisse bringen nie Aura.
   - Admin-Übersicht: `GET /api/admin/flags?key=…`
   - Freigabe: `POST /api/admin/unflag?key=…` mit `{id}`
   - Den Admin-Schlüssel gibt es nur root-only auf pve2 in `/root/aura-city-admin-key.txt`.
5. **Grenze:** Das Timing (Nadelposition) misst der Client. Ein komplett nachgebauter Client kann
   „perfect“ behaupten. Dagegen helfen die Obergrenzen über Cooldowns und Uhrprüfung sowie die
   Perfect-Quoten-Markierung. Ein Cheat-Engine-Eingriff in den Aura-Wert selbst wirkt nicht: Der nächste
   Server-Abgleich überschreibt ihn, und Käufe ohne Deckung lehnt der Server ab (getestet).

**Profil:** Beim ersten Verbinden legt der Server ein frisches Profil an. Das Token liegt nur gehasht
(SHA-256) auf dem Server. Offline-Fortschritt bleibt lokal und wird nie hochgeladen.

**Aura Rush:** Der Rush folgt einem festen Zeitplan (alle 300 s für 45 s, ×2, Unix-Zeit). Server und
Clients kennen ihn ohne Abstimmung, und Online gleicht der Client die Zeit mit der Serverzeit ab.

**HTTP-API:**
- `POST /api/register`
- `POST /api/session`
- `POST /api/events` (Bearer-Token)
- `GET /api/leaderboard`
- `GET /api/health`

## Deployment (Homelab)

- **Container:** `aura-city-server` auf der selfhost-VM, `/opt/stacks/aura-city-server`, Port 3710,
  Daten in `/opt/appdata/aura-city-server/players.json` (mit `.bak`).
- **Erreichbarkeit:** `http://auracity.local` (Caddy und mDNS-Alias) sowie über Tailscale
  `http://100.126.128.24/auracity` (Caddy auf pve2).
- **Update:**
  1. `godot --headless -- --export-data server/gamedata.json`
  2. Dateien aus `server/` nach `/opt/stacks/aura-city-server/src` kopieren.
  3. `docker compose up -d --build`

## Figuren & Animationen

- Modelle: `assets/characters/models/*.fbx` (Ultimate Animated Character Pack, gleiches Skelett).
- Animationen: `assets/characters/ual_anims.res` – erzeugt mit `godot --headless -s tools/retarget_ual.gd`
  aus `assets/characters/source/UAL.glb`. Pro Frame wird das Welt-Rotationsdelta zur T-Pose übertragen,
  Positionen per Vorwärtskinematik; die Füße (hängen im Quaternius-Rig am Root) werden an das Schienbein-Ende gesetzt.
- `CharacterVisual`: Outfit → Basismodell (`BODIES`), Frisur → Spender-Haar (`HAIR_DONORS`) als Skin-Mesh am
  eigenen Skelett, Accessoires/Schuhe/Gadget über `BoneAttachment3D` (Größen aus den Vertex-Gewichten berechnet).
- `CharacterAnimator`: Zustände → Animationen mit Überblendung, Tricks = Animation + Drehung/Sprung/Salto.

## Performance

- Standard-Grafikstufe „Mittel“; `AutoQuality` senkt die Stufe nach dem Start automatisch, wenn die
  Bildrate unter 35 FPS liegt (aus, sobald man die Grafikstufe selbst wählt).
- Himmel als Kuppel-Mesh (`assets/shaders/sky_dome.gdshader`) statt Sky-Ressource: Tageszeit-Änderungen
  lösen keine Radiance-Neuberechnung aus.
- Fenster leuchten nachts über eine eigene Emissions-Textur (Multiplikation), Stärke von `DayNight`.
- Effekte: feste Emitter-Pools (Wolken 6, Funken 6, Ringe 3), Partikel blenden nah an der Kamera aus
  (kein Vollbild-Overdraw), Menge nach Effekt-Qualität. Shader-Warm-up im Ladebildschirm.
- Ausgeschaltete Laternen sind unsichtbar (Kompatibilitäts-Renderer zahlt sonst pro Licht einen Pass).
- NPCs/Verkehr außerhalb von 75 m bzw. 160 m pausieren Physik und Animation.
- Himmel/Licht werden nur 4×/s aktualisiert, keine Reflexionen.
- Kleine Objekte werden nur bis 140 m gerendert, mittelgroße bis 320 m, Schilder bis 260 m. Der Nebel kaschiert den Übergang.
- Laternenlichter blenden ab 70 m aus.
- Gebäude teilen sich Fenstertexturen und Materialien über einen Cache.
- Schatten reichen nur 70 m weit.
- Die Vororte werden mit festem Seed erzeugt.
- Die Welt hat rund 7.400 Nodes. Gemessen wurde nur headless: Es lief kein Rendering-Test, und die
  Bildrate auf echter Hardware ist noch nicht gemessen.

## Bekannte Punkte / nächste Aufgaben

- Die neuen Distrikte sind nur headless geprüft (Kollision, Erreichbarkeit, Splitter frei, Teleportziele).
  Optik und Parkour-Strecken müssen noch im Spiel angeschaut werden.
- Kein HTTPS. Im LAN und über Tailscale ist das in Ordnung, öffentlich bräuchte es TLS.
- Android löst `.local` meist nicht auf, dort die IP- bzw. Tailscale-Adresse nutzen.
- Export-Presets und Forgejo-CI fehlen noch. Der Runner läuft nur, wenn pve1 an ist.
- Echtzeit-Multiplayer: `Identity.replicated_state()` ist als Grenze vorbereitet, aber noch nicht umgesetzt.
