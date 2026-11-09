#!/usr/bin/env python3
"""Erzeugt die .tres-Daten (Items, Tricks, Quests, Achievements) für AURA CITY.

Aufruf:  python3 tools/gen_resources.py
Die Dateien landen unter resources/ und können danach auch im Godot-Editor bearbeitet werden.
"""
import os
import shutil

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "resources")

RARITY = {"common": 0, "uncommon": 1, "rare": 2, "epic": 3, "legendary": 4, "mythic": 5, "secret": 6}


def color(hex_str):
    h = hex_str.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    return f"Color({r:.3f}, {g:.3f}, {b:.3f}, 1)"


def write(kind, script, filename, fields):
    folder = os.path.join(ROOT, kind)
    os.makedirs(folder, exist_ok=True)
    lines = [
        f'[gd_resource type="Resource" script_class="{script[0]}" load_steps=2 format=3]',
        "",
        f'[ext_resource type="Script" path="{script[1]}" id="1_s"]',
        "",
        "[resource]",
        'script = ExtResource("1_s")',
    ]
    for k, v in fields.items():
        if isinstance(v, bool):
            v = "true" if v else "false"
        elif isinstance(v, str) and v.startswith(("Color(", "&\"")):
            pass
        elif isinstance(v, str):
            v = '"' + v.replace("\\", "\\\\").replace('"', '\\"') + '"'
        lines.append(f"{k} = {v}")
    with open(os.path.join(folder, filename + ".tres"), "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


ITEM = ("ItemDef", "res://scripts/inventory/item_def.gd")
TRICK = ("TrickDef", "res://scripts/gameplay/trick_def.gd")
QUEST = ("QuestDef", "res://scripts/quests/quest_def.gd")
ACH = ("AchievementDef", "res://scripts/achievements/achievement_def.gd")

# id, name, kategorie, rarität, preis, glyphe, farbe, akzent, variante, beschreibung, extra
ITEMS = [
    # Haut
    ("skin_warm", "Warm Tone", "skin", "common", 0, "◐", "e0ac69", "c68642", "", "Standard-Hautton.", {"starter": True}),
    ("skin_light", "Light Tone", "skin", "common", 0, "◐", "ffdbac", "f1c27d", "", "Heller Hautton.", {"starter": True}),
    ("skin_deep", "Deep Tone", "skin", "common", 0, "◐", "8d5524", "6b3e1d", "", "Dunkler Hautton.", {"starter": True}),
    ("skin_neon", "Neon Glow", "skin", "epic", 30000, "◑", "22d3ee", "a855f7", "glow", "Haut, die im Dunkeln leuchtet.", {"required_rank": 2}),
    ("skin_gold", "Pure Gold", "skin", "legendary", 180000, "◑", "fbbf24", "fde68a", "metal", "Für alle, die es geschafft haben.", {"required_rank": 4}),
    ("skin_holo", "Hologram", "skin", "mythic", 800000, "◑", "a5f3fc", "f0abfc", "glow", "Halb hier, halb in einer anderen Realität.", {"required_rank": 5}),
    ("skin_void", "Void Walker", "skin", "secret", 0, "◑", "1e1b4b", "7c3aed", "glow", "Nur wer die geheime Dimension fand, trägt das.", {"hidden_until_unlocked": True, "required_achievement": '&"secret_explorer"'}),
    # Haare
    ("hair_short", "Short Cut", "hair", "common", 0, "♒", "2b1b0e", "000000", "short", "Klassisch kurz.", {"starter": True}),
    ("hair_spiky", "Spiky", "hair", "common", 600, "♒", "111111", "000000", "spiky", "Spitz nach oben.", {}),
    ("hair_long", "Long Flow", "hair", "uncommon", 1800, "♒", "8b5a2b", "000000", "long", "Lang und lässig.", {}),
    ("hair_afro", "Cloud Afro", "hair", "rare", 6000, "♒", "1f1208", "000000", "afro", "Groß, rund, legendär fluffig.", {}),
    ("hair_mohawk", "Neon Mohawk", "hair", "epic", 24000, "♒", "f472b6", "22d3ee", "mohawk", "Punk-Energie in Neon.", {"required_rank": 2}),
    ("hair_flame", "Flame Hair", "hair", "legendary", 150000, "♒", "f97316", "fde047", "spiky", "Brennt. Metaphorisch.", {"required_rank": 4}),
    # Outfits
    ("outfit_hoodie", "Gray Hoodie", "outfit", "common", 0, "♜", "6b7280", "374151", "hoodie", "Der Klassiker.", {"starter": True}),
    ("outfit_tee_white", "White Tee", "outfit", "common", 400, "♜", "f3f4f6", "d1d5db", "tee", "Schlicht, sauber.", {}),
    ("outfit_track", "Tracksuit", "outfit", "uncommon", 2200, "♜", "1d4ed8", "f8fafc", "tracksuit", "Drei Streifen Energie.", {}),
    ("outfit_varsity", "Varsity Jacket", "outfit", "rare", 7500, "♜", "b91c1c", "fef3c7", "jacket", "Main-Character-Jacke.", {}),
    ("outfit_neon", "Neon Runner", "outfit", "epic", 32000, "♜", "0f172a", "22d3ee", "jacket", "Leuchtet bei Nacht.", {"required_rank": 2}),
    ("outfit_suit", "Midnight Suit", "outfit", "legendary", 200000, "♜", "111827", "fbbf24", "suit", "Luxus-Distrikt-Pflicht.", {"required_rank": 4}),
    ("outfit_cosmic", "Cosmic Robe", "outfit", "mythic", 950000, "♜", "312e81", "f0abfc", "robe", "Gewebt aus Sternenstaub.", {"required_rank": 5}),
    # Schuhe
    ("shoes_white", "White Kicks", "shoes", "common", 0, "▲", "f8fafc", "d1d5db", "sneaker", "Frisch aus dem Karton.", {"starter": True}),
    ("shoes_black", "Black Kicks", "shoes", "common", 500, "▲", "111827", "374151", "sneaker", "Passen zu allem.", {}),
    ("shoes_hightop", "Red High-Tops", "shoes", "uncommon", 2000, "▲", "dc2626", "f8fafc", "hightop", "Hoch hinaus.", {}),
    ("shoes_neon", "Neon Steps", "shoes", "epic", 22000, "▲", "22d3ee", "f472b6", "hightop", "Jeder Schritt leuchtet.", {"required_rank": 2}),
    ("shoes_gold", "Gold Steppers", "shoes", "legendary", 120000, "▲", "fbbf24", "fde68a", "hightop", "Laut auf jedem Boden.", {"required_rank": 3}),
    # Accessoires
    ("acc_cap", "Snapback", "accessory", "common", 800, "◒", "1f2937", "f472b6", "cap", "Schirm nach hinten.", {}),
    ("acc_shades", "Shades", "accessory", "uncommon", 2500, "◒", "111111", "38bdf8", "shades", "Zu cool für die Sonne.", {}),
    ("acc_headphones", "Bass Cans", "accessory", "rare", 8000, "◒", "a855f7", "22d3ee", "headphones", "Eigener Soundtrack.", {}),
    ("acc_chain", "Aura Chain", "accessory", "epic", 28000, "◒", "fbbf24", "fde68a", "chain", "Glänzt bei jedem Trick.", {"required_rank": 2}),
    ("acc_crown", "Crown", "accessory", "legendary", 250000, "◒", "fbbf24", "ef4444", "crown", "König(in) der Stadt.", {"required_rank": 5}),
    ("acc_halo", "Halo", "accessory", "mythic", 1200000, "◒", "fef9c3", "ffffff", "halo", "Jenseits der Realität.", {"required_rank": 6}),
    ("acc_horns", "Void Horns", "accessory", "secret", 0, "◒", "312e81", "a855f7", "horns", "Ein Andenken aus der Leere.", {"hidden_until_unlocked": True, "required_achievement": '&"secret_explorer"'}),
    # Gadgets (fiktive Wolken-Gadgets, rein kosmetisch)
    ("gadget_cloudpen", "Cloud Pen", "gadget", "common", 0, "✎", "8b5cf6", "22d3ee", "pen", "Fiktives Gadget, das bunte Wolken-Effekte zaubert.", {"starter": True}),
    ("gadget_cloudpen_pink", "Cloud Pen Bubblegum", "gadget", "uncommon", 1500, "✎", "f472b6", "fde047", "pen", "Pinke Effektwolken.", {}),
    ("gadget_mistbox", "Mist Box", "gadget", "rare", 9000, "▣", "1f2937", "ef4444", "box", "Kantig. Dicke Effektwolken.", {}),
    ("gadget_orb", "Nebula Orb", "gadget", "epic", 35000, "●", "312e81", "f0abfc", "orb", "Eine schwebende Mini-Galaxie.", {"required_rank": 2}),
    ("gadget_wand", "Aura Wand", "gadget", "legendary", 220000, "✦", "fbbf24", "22d3ee", "wand", "Für Profis der Show.", {"required_rank": 4}),
    ("gadget_cosmic", "Skyscraper 9000", "gadget", "mythic", 1000000, "▲", "f8fafc", "a855f7", "box", "Der Effekt verdeckt den Himmel.", {"required_rank": 5}),
    # Trails
    ("trail_cyan", "Cyan Trail", "trail", "uncommon", 3000, "≈", "22d3ee", "a5f3fc", "", "Eine leuchtende Spur.", {}),
    ("trail_pink", "Pink Trail", "trail", "uncommon", 3000, "≈", "f472b6", "fbcfe8", "", "Eine pinke Spur.", {}),
    ("trail_fire", "Fire Trail", "trail", "epic", 40000, "≈", "f97316", "fde047", "", "Heißer Abgang.", {"required_rank": 3}),
    ("trail_rainbow", "Rainbow Trail", "trail", "legendary", 300000, "≈", "ef4444", "22d3ee", "rainbow", "Alle Farben, alle Blicke.", {"required_rank": 5}),
    # Partikel
    ("fx_sparkles", "Sparkles", "particle", "rare", 10000, "✧", "fde68a", "ffffff", "", "Ein Hauch Glitzer.", {}),
    ("fx_hearts", "Hearts", "particle", "rare", 10000, "♥", "f472b6", "ffffff", "", "Liebe liegt in der Luft.", {}),
    ("fx_stars", "Star Aura", "particle", "epic", 45000, "★", "facc15", "ffffff", "", "Sterne umkreisen dich.", {"required_rank": 3}),
    ("fx_money", "Money Rain", "particle", "legendary", 280000, "$", "4ade80", "bbf7d0", "", "Es regnet Aura.", {"required_rank": 5}),
    ("fx_void", "Void Particles", "particle", "secret", 0, "◇", "7c3aed", "1e1b4b", "", "Splitter einer anderen Dimension.", {"hidden_until_unlocked": True, "required_achievement": '&"secret_explorer"'}),
    # Animationen (Idle-Stil)
    ("anim_chill", "Chill Idle", "animation", "common", 0, "☺", "94a3b8", "ffffff", "chill", "Entspannt rumstehen.", {"starter": True}),
    ("anim_bounce", "Bounce Idle", "animation", "uncommon", 2500, "☺", "38bdf8", "ffffff", "bounce", "Immer im Takt.", {}),
    ("anim_flex", "Flex Idle", "animation", "epic", 30000, "☺", "f59e0b", "ffffff", "flex", "Zeig was du hast.", {"required_rank": 3}),
    # Emotes (Taste G)
    ("emote_wave", "Wave", "emote", "common", 0, "✋", "fde68a", "ffffff", "wave", "Hallo sagen.", {"starter": True}),
    ("emote_dance", "Dance", "emote", "uncommon", 3500, "♫", "f472b6", "ffffff", "dance", "Einfach tanzen.", {}),
    ("emote_dab", "Dab", "emote", "rare", 9000, "↗", "22d3ee", "ffffff", "dab", "Ein Klassiker.", {}),
    ("emote_flex", "Big Flex", "emote", "epic", 25000, "💪", "f59e0b", "ffffff", "flex", "Muskeln zeigen.", {"required_rank": 2}),
    # Titel
    ("title_newbie", "Fresh Spawn", "title", "common", 0, "❝", "9ca3af", "ffffff", "", "Gerade angekommen.", {"starter": True}),
    ("title_main", "Main Character", "title", "uncommon", 4000, "❝", "38bdf8", "ffffff", "", "Die Story dreht sich um dich.", {"required_rank": 2}),
    ("title_legend", "Street Legend", "title", "rare", 15000, "❝", "a855f7", "ffffff", "", "Jeder kennt deinen Namen.", {"required_rank": 3}),
    ("title_sigma", "Certified Sigma", "title", "epic", 60000, "❝", "f59e0b", "ffffff", "", "Grindset aktiviert.", {"required_rank": 5}),
    ("title_godlike", "Godlike", "title", "legendary", 400000, "❝", "fde047", "ffffff", "", "Unantastbar.", {"required_rank": 6}),
    ("title_beyond", "Beyond Reality", "title", "mythic", 1500000, "❝", "22d3ee", "ffffff", "", "Nicht mehr von dieser Welt.", {"required_rank": 7}),
    ("title_void", "Void Touched", "title", "secret", 0, "❝", "7c3aed", "ffffff", "", "Du warst dort.", {"hidden_until_unlocked": True, "required_achievement": '&"secret_explorer"'}),
]

# id, name, tier, schwierigkeit, basis, dauer, cooldown, combo, animation, farbe, pitch, freischaltung, beschreibung
TRICKS = [
    ("basic_spin", "Basic Spin", 0, 1, 40, 0.7, 0.8, 0.25, "spin", "c084fc", 1.0, 0, "Eine saubere 360°-Drehung."),
    ("finger_flip", "Finger Flip", 0, 2, 50, 0.6, 0.8, 0.25, "flip", "38bdf8", 1.1, 0, "Das Gadget wirbelt durch die Finger."),
    ("mini_pose", "Mini Pose", 0, 2, 55, 0.8, 1.0, 0.25, "pose", "f472b6", 1.05, 0, "Kurz posen, Kamera liebt dich."),
    ("side_twist", "Side Twist", 0, 3, 65, 0.7, 1.0, 0.3, "twist", "4ade80", 1.15, 0, "Hüfte links, Hüfte rechts."),
    ("double_spin", "Double Spin", 1, 4, 110, 0.9, 1.4, 0.35, "double_spin", "a855f7", 0.95, 1500, "Zwei volle Drehungen."),
    ("shadow_move", "Shadow Move", 1, 5, 140, 0.9, 1.6, 0.35, "shadow", "6366f1", 0.85, 4000, "Kurz verschwinden, woanders auftauchen."),
    ("neon_flip", "Neon Flip", 1, 6, 180, 1.0, 1.8, 0.4, "neon_flip", "22d3ee", 1.2, 8000, "Rückwärtssalto mit Neon-Spur."),
    ("air_pose", "Air Pose", 1, 6, 200, 1.1, 2.0, 0.4, "air_pose", "f9a8d4", 1.1, 15000, "Pose mitten in der Luft."),
    ("phantom_combo", "Phantom Combo", 2, 8, 380, 1.3, 2.6, 0.5, "phantom", "818cf8", 0.8, 40000, "Drei Schatten, ein Trick."),
    ("ultra_spin", "Ultra Spin", 2, 8, 420, 1.2, 2.6, 0.5, "ultra_spin", "e879f9", 0.9, 80000, "Fünffach-Drehung im Wirbelsturm."),
    ("cosmic_pose", "Cosmic Pose", 2, 9, 520, 1.4, 3.0, 0.55, "cosmic", "fde047", 1.25, 150000, "Die Sterne posen mit."),
    ("aura_explosion", "Aura Explosion", 2, 10, 800, 1.6, 4.0, 0.6, "explosion", "f43f5e", 0.7, 300000, "Die ganze Straße spürt deine Aura."),
]

QUESTS = [
    ("daily_tricks", "Trick-Routine", "Lande 10 Tricks", 0, "trick", 10, 300),
    ("daily_combos", "Combo-Zeit", "Schaffe 3 Combos (mind. 3 Tricks)", 0, "combo", 3, 450),
    ("daily_districts", "Stadtbummel", "Besuche 2 Distrikte", 0, "district", 2, 250),
    ("daily_collectibles", "Sammler", "Finde 5 Aura-Splitter", 0, "collectible", 5, 500),
    ("weekly_aura", "Aura-Woche", "Verdiene 10.000 Aura", 1, "aura", 10000, 3000),
    ("weekly_challenges", "Challenge-Marathon", "Schaffe 20 Challenges", 1, "challenge", 20, 4500),
    ("weekly_unlocks", "Shopping-Tour", "Schalte 5 Kosmetik-Items frei", 1, "unlock", 5, 3000),
]

ACHIEVEMENTS = [
    ("first_trick", "First Trick", "Lande deinen ersten Trick.", "✦", "tricks", 1, 100, False),
    ("trick_100", "Trick Machine", "Lande 100 Tricks.", "⚙", "tricks", 100, 2000, False),
    ("perfectionist", "Perfectionist", "50 Perfect-Landungen.", "◎", "perfects", 50, 3000, False),
    ("combo_starter", "Combo Starter", "Erreiche eine 5er-Combo.", "✚", "best_combo", 5, 500, False),
    ("combo_master", "Combo Master", "Erreiche eine 10er-Combo.", "✪", "best_combo", 10, 2500, False),
    ("first_1000", "First 1,000 Aura", "Sammle 1.000 Aura.", "✧", "lifetime_aura", 1000, 200, False),
    ("aura_100k", "Aura Tycoon", "Sammle 100.000 Lifetime-Aura.", "♛", "lifetime_aura", 100000, 10000, False),
    ("first_legendary", "First Legendary Item", "Besitze ein legendäres Item.", "♦", "legendary_items", 1, 5000, False),
    ("collector", "Collector", "Finde 25 Aura-Splitter.", "❖", "collectibles", 25, 2500, False),
    ("globetrotter", "Globetrotter", "Besuche alle 9 Distrikte.", "⌂", "districts", 9, 6000, False),
    ("challenger", "Challenger", "Schaffe 10 Challenges.", "⚑", "challenges", 10, 2000, False),
    ("secret_explorer", "Secret Explorer", "Finde die geheime Dimension.", "◈", "secret_found", 1, 7777, True),
    ("godlike_rank", "Godlike Rank", "Erreiche den Rang Godlike.", "☀", "rank", 6, 50000, False),
    ("beyond_reality", "Beyond Reality", "Erreiche den höchsten Rang.", "∞", "rank", 7, 0, True),
]


def main():
    for kind in ("items", "tricks", "quests", "achievements"):
        shutil.rmtree(os.path.join(ROOT, kind), ignore_errors=True)
    for (iid, name, cat, rar, price, glyph, col, acc, variant, desc, extra) in ITEMS:
        fields = {"id": f'&"{iid}"', "display_name": name, "description": desc, "price": price,
                  "rarity": RARITY[rar], "category": f'&"{cat}"', "icon_glyph": glyph,
                  "color": color(col), "accent_color": color(acc), "variant": f'&"{variant}"'}
        for k, v in extra.items():
            fields[k] = v
        write("items", ITEM, iid, fields)
    for (tid, name, tier, diff, base, dur, cd, combo, anim, col, pitch, unlock, desc) in TRICKS:
        write("tricks", TRICK, tid, {"id": f'&"{tid}"', "display_name": name, "description": desc, "tier": tier,
                                     "difficulty": diff, "base_aura": base, "duration": dur, "cooldown": cd,
                                     "combo_bonus": combo, "animation": f'&"{anim}"', "effect_color": color(col),
                                     "sound_pitch": pitch, "unlock_lifetime_aura": unlock})
    for (qid, name, desc, period, stat, goal, reward) in QUESTS:
        write("quests", QUEST, qid, {"id": f'&"{qid}"', "display_name": name, "description": desc, "period": period,
                                     "stat": f'&"{stat}"', "goal": goal, "reward_aura": reward})
    for (aid, name, desc, glyph, stat, goal, reward, secret) in ACHIEVEMENTS:
        write("achievements", ACH, aid, {"id": f'&"{aid}"', "display_name": name, "description": desc,
                                         "icon_glyph": glyph, "stat": f'&"{stat}"', "goal": goal,
                                         "reward_aura": reward, "secret": secret})
    print(f"{len(ITEMS)} Items, {len(TRICKS)} Tricks, {len(QUESTS)} Quests, {len(ACHIEVEMENTS)} Achievements erzeugt")


if __name__ == "__main__":
    main()
