# AURA CITY

Ein 3D-Open-World-Spiel (Godot 4.3, GDScript): Lauf durch eine riesige Stadt, lande Tricks mit
Timing, baue Combos und Ketten, farme Aura, steig im Rang auf und schalte Distrikte, Tricks und Kosmetik frei.

> Satire-Hinweis: Die „Gadgets“ sind rein kosmetische Fantasie-Objekte mit bunten Wolken-Effekten.
> Es gibt keine Inhalations- oder Nikotin-Mechanik.

## Features

- **Riesen-Map (900 × 900 m)** mit 9 Distrikten: Spawn City, Skate Park, Neon District, Luxury District,
  Hafen, Sunset Beach, Graffiti Yard, Downtown Skyline und eine geheime Dimension. Dazu Straßennetz mit Ring,
  Vororte, Teleporter-Hub am Spawn und eine Minimap.
- **12 Tricks** (Anfänger → Legendär) mit Timing-Leiste (Perfect/Good), Combos bis ×6, benannten Ketten,
  Meisterschaft (5 Stufen) und Freischaltung über Lifetime-Aura.
- **Aura-Wirtschaft:** 8 Ränge (NPC → Beyond Reality), Level, Aura/min, Aura Rush alle 5 Minuten,
  Tagesbelohnung mit 7-Tage-Serie.
- **Shop & Inventar:** 61 Items in 11 Kategorien und 7 Raritäten, Suche, Filter, 3D-Vorschau,
  Kaufbestätigung, Garderobe mit Live-Vorschau.
- **Quests & Erfolge:** tägliche/wöchentliche Quests, 14 Erfolge (auch geheime).
- **21 Challenges** (Perfects / Combo / Score), **63 Aura-Splitter**, davon 7 geheim und teils nur durch Klettern erreichbar.
- **Online-Modus mit server-autoritativer Aura (Anti-Cheat)** und Online-Bestenliste. Ein Offline-Modus mit lokalem Spielstand ist ebenfalls dabei.
- Komplettes UI: Hauptmenü, HUD, Shop, Inventar, Garderobe, Trickbuch, Quests, Erfolge, Einstellungen,
  Bestenliste, Pause, Tagesbelohnung, Dialoge, Toasts, Tutorial, Ladebildschirm.
- Prozedurale Grafik, Animation und Audio. Das Projekt braucht keine externen Assets.

## Steuerung

| Taste | Aktion |
|---|---|
| WASD / Pfeile | Laufen (Shift = Sprinten) |
| Maus | Kamera |
| Leertaste | Springen |
| 1–4 | Trick starten |
| F / Linksklick | Trick landen (im Timing-Fenster) |
| E | Interagieren (Shops, NPCs, Schilder, Teleporter, Challenges) |
| G | Emote |
| B / I / C / K / J / O / L | Shop / Inventar / Garderobe / Trickbuch / Quests / Erfolge / Bestenliste |
| Esc | Pause / Menü schließen |

## Starten

```bash
godot --path . --import      # einmalig
godot --path .               # Spiel
```

**Online spielen:** Im Hauptmenü die Server-Adresse eintragen und auf „Online spielen“ klicken.
- Im Heimnetz: `http://auracity.local`
- Über Tailscale: `http://100.126.128.24/auracity`

Beim ersten Verbinden legt der Server ein frisches Profil an. Das Token liegt in `user://net.json`.

## Server

Der Server liegt in `server/`: Node.js ohne externe Abhängigkeiten, gespeichert wird in einer JSON-Datei.
Details zum Anti-Cheat-Modell stehen in [DEVELOPMENT.md](DEVELOPMENT.md).

```bash
cd server && node server.js                 # PORT=3710, DATA_DIR=./data, ADMIN_KEY=…
docker compose up -d --build                # oder als Container
```

## Tests

```bash
godot --headless -- --tests                         # 80 Godot-Tests (Wirtschaft, Shop, Speichern, Tricks, Szene, Map)
cd server && node --test test/game.test.js          # 15 Server-Tests (Regeln + Anti-Cheat)
godot --headless -- --online-test http://127.0.0.1:3710   # End-to-End gegen laufenden Server
godot --headless -- --smoke                         # startet das echte Spiel und öffnet jedes Menü
```
