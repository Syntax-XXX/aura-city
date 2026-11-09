class_name Minimap
extends Control
## Übersichtskarte (Norden oben): Straßen, Distrikte (gesperrte gedimmt mit Rang) und der Spieler.

const SIZE := 190.0
## id, Mitte, Kurzname, benötigter Rang (wie Tor/Teleporter im Distrikt)
var districts := [
	[Vector3.ZERO, "Spawn", 0], [SkatePark.CENTER, "Skate", 0], [NeonDistrict.CENTER, "Neon", 1],
	[LuxuryDistrict.CENTER, "Luxus", 3], [Harbor.CENTER, "Hafen", 0], [SunsetBeach.CENTER, "Beach", 2],
	[IndustrialYard.CENTER, "Yard", 4], [Downtown.CENTER, "Downtown", 5],
]
var player: Node3D
var _redraw := 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_redraw -= delta
	if _redraw <= 0.0:
		_redraw = 0.1 # 10 Hz reichen
		queue_redraw()


func _to_map(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z) / (WorldRoot.WORLD_HALF * 2.0) * SIZE + Vector2(SIZE, SIZE) / 2.0


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE, SIZE)), Color(0.05, 0.04, 0.1, 0.85))
	var road := Color(0.4, 0.42, 0.5, 0.9)
	draw_line(_to_map(Vector3(-400, 0, 0)), _to_map(Vector3(400, 0, 0)), road, 2.0)
	draw_line(_to_map(Vector3(0, 0, -400)), _to_map(Vector3(0, 0, 260)), road, 2.0)
	draw_rect(Rect2(_to_map(Vector3(-200, 0, -200)), Vector2(400, 400) / (WorldRoot.WORLD_HALF * 2.0) * SIZE), road, false, 1.5)
	var font := UITheme.font()
	for d in districts:
		var pos := _to_map(d[0])
		var locked: bool = Economy.rank_index < int(d[2])
		var col: Color = Color(0.45, 0.45, 0.5) if locked else Color("c084fc")
		draw_circle(pos, 9.0, Color(col, 0.35))
		draw_circle(pos, 3.0, col)
		var label: String = ("🔒 " if locked else "") + str(d[1])
		draw_string(font, pos + Vector2(-40, -11), label, HORIZONTAL_ALIGNMENT_CENTER, 80, 10, Color(1, 1, 1, 0.5 if locked else 0.9))
	if player and player.global_position.z < WorldRoot.WORLD_HALF:
		var p := _to_map(player.global_position)
		var fwd := Vector2(-sin(player.rotation.y), -cos(player.rotation.y))
		var side := Vector2(-fwd.y, fwd.x)
		draw_colored_polygon(PackedVector2Array([p + fwd * 7.0, p - fwd * 4.0 + side * 4.0, p - fwd * 4.0 - side * 4.0]), UITheme.CYAN)
	elif player:
		draw_string(font, Vector2(0, SIZE / 2.0), "???", HORIZONTAL_ALIGNMENT_CENTER, SIZE, 16, UITheme.PINK)
	draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE, SIZE)), UITheme.LINE, false, 1.0)
