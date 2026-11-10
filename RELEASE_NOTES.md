## Aura City 1.2.0 – Dampfen statt Tricks

3D-Open-World übers Dampfen: ziehen, Wolken blasen, Aura farmen – Godot 4.3. Alle Vapes sind erfunden (Satire).

### Installieren
- **Android:** `AuraCity-1.2.0-android-arm64.apk` aufs Handy laden und öffnen (Installation aus unbekannten Quellen erlauben).
- **iPhone/iPad:** `AuraCity-1.2.0-ios-unsigned.ipa` mit AltStore oder SideStore installieren. Die App wird dabei mit deiner eigenen Apple-ID signiert; mit einer kostenlosen ID gilt das 7 Tage, danach in AltStore/SideStore aktualisieren.
- **Windows:** `AuraCity-1.2.0-windows-x86_64.zip` entpacken, `AuraCity.exe` starten. Die Datei ist unsigniert, deshalb kann SmartScreen fragen („Weitere Informationen“ → „Trotzdem ausführen“).
- **Linux:** `tar -xzf AuraCity-1.2.0-linux-x86_64.tar.gz && ./AuraCity.x86_64`
- Prüfsummen: `SHA256SUMS`

### Online spielen
Hauptmenü → Server-Adresse eintragen → **Online spielen**. Die Aura berechnet und prüft der Server (Anti-Cheat). Offline spielen geht auch: Der Spielstand bleibt dann lokal, und du erscheinst nicht in der Bestenliste.

### Inhalt
- 9 Distrikte auf 900 × 900 m: Straßen, Verkehr, Passanten, Tag/Nacht, Regen
- Echte animierte Figuren (Quaternius, CC0) mit über 45 Animationen, Outfits, Frisuren, Accessoires
- 12 Wolkenformen mit Zug-Timing, Combos, Ketten und Meisterschaft; 29 Challenges inklusive 8 Aura-Battles gegen NPC-Rivalen
- Hoverboards in 6 Stufen, Aura-Drinks mit Boosts, 67 Items, 17 Erfolge, Quests, Tagesbelohnung
- Foto-Modus, Distrikt-Musik, Grafik- und Effekt-Qualitätsstufen

### Neu in 1.2.0
- Keine Tricks mehr: Mit 1–4 ziehst du an der Vape, mit F/Linksklick atmest du aus – die Wolke kommt aus dem Mund
- 12 Wolkenformen: Kleine Wolke, O-Ring, Ghost, Wasserfall, O-Ring-Kette, Qualle, Drache, Bullseye, Tornado, Riesen-Ghost, Triple Ghost, Wolkenkratzer
- Verkackter Zug = Husten: kostet Aura (vom Server geprüft) und beendet die Combo
- Viel mehr Passanten dampfen, auch mit Ringen und Ghosts
- „Wolkenbuch“ statt Trickbuch, Gadgets heißen jetzt Vapes

### Neu in 1.1.0
- Touch-Steuerung: schwebender Stick links, Wischen für die Kamera, Buttons für Ausatmen, Springen, Ziehen 1–4, Board, Sprint, Emote, Interagieren, Menü und Shop
- Handys starten automatisch mit sparsamer Grafik

### Steuerung (PC)
WASD laufen · Shift sprinten · Leertaste springen · 1–4 ziehen · F/Linksklick ausatmen · E interagieren · Q Hoverboard · N Aura-Kiosk · P Foto-Modus · B Shop · Esc Menü

### Hinweise
- Online auf dem Handy: im WLAN zu Hause `http://auracity.local`; unterwegs mit der Tailscale-App `http://100.126.128.24/auracity`. Beim ersten Start fragt iOS nach dem Zugriff auf das lokale Netzwerk – bitte erlauben.
- Die mobilen Builds sind auf echten Geräten noch ungetestet (gebaut auf GitHub, Touch-Steuerung automatisch getestet).
- Getestet mit automatischen Tests (Spiel, Server, End-to-End) und Software-Rendering. Die Bildrate auf echter Hardware ist noch nicht gemessen. Bei Rucklern: Einstellungen → Grafik/Effekte auf „Mittel“ bzw. „Sparsam“.
- Satire: Alle „Gadgets“ sind rein kosmetisch.

Assets: Quaternius und Poly Haven (CC0), siehe `assets/CREDITS.md`.
