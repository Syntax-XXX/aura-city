class_name LeaderboardBoard
extends Node3D
## 3D-Tafel auf dem Platz mit den Top 6 der (lokalen) Bestenliste.

var _label: Label3D


func _ready() -> void:
	WorldKit.box(self, Vector3(5.2, 3.6, 0.2), Vector3(0, 3.2, 0), WorldKit.mat(Color("0f0a1e"), 0.4, 0.2, 0.0), false)
	WorldKit.box(self, Vector3(5.4, 0.12, 0.25), Vector3(0, 5.05, 0), WorldKit.mat(Color("facc15"), 0.3, 0.0, 2.0), false)
	_label = Label3D.new()
	_label.font_size = 52
	_label.pixel_size = 0.006
	_label.outline_size = 8
	_label.position = Vector3(0, 3.25, 0.12)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_label.width = 760.0
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(_label)
	var t := Timer.new()
	t.wait_time = 5.0
	t.autostart = true
	t.timeout.connect(_refresh)
	add_child(t)
	_refresh()


func _refresh() -> void:
	var lines := PackedStringArray(["TOP AURA (lokal, NPC-Rivalen)"])
	var list := LocalLeaderboard.entries()
	for i in mini(6, list.size()):
		var e: Dictionary = list[i]
		lines.append("%d. %s%s  %s" % [i + 1, e["name"], "  ◀ DU" if e["is_player"] else "", UIFormat.number(e["score"])])
	if LocalLeaderboard.player_position() > 6:
		lines.append("…  %d. %s  %s" % [LocalLeaderboard.player_position(), Identity.display_name, UIFormat.number(Economy.lifetime)])
	_label.text = "\n".join(lines)
