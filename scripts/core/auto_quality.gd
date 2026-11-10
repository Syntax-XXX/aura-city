class_name AutoQuality
extends Node
## Misst die Bildrate nach dem Spielstart; liegt sie deutlich unter 35 FPS, wird die Grafikstufe
## (höchstens zweimal) gesenkt. Nur solange Settings.auto_quality aktiv ist.

const WARMUP := 4.0
const WINDOW := 6.0
const MIN_FPS := 35.0

var _t := 0.0
var _frames := 0
var _steps := 0


func _process(delta: float) -> void:
	if not Settings.auto_quality or Settings.graphics_quality <= 0 or _steps >= 2:
		set_process(false)
		return
	_t += delta
	if _t < WARMUP:
		return
	_frames += 1
	if _t >= WARMUP + WINDOW:
		var fps := _frames / WINDOW
		if fps < MIN_FPS:
			Settings.graphics_quality -= 1
			Settings.apply()
			_steps += 1
			Events.toast.emit("Grafik automatisch auf „%s“ gesenkt (%d FPS) – änderbar in den Einstellungen" % [["Niedrig", "Mittel", "Hoch"][Settings.graphics_quality], roundi(fps)], Color("fbbf24"))
			_t = 0.0
		else:
			set_process(false)
		_frames = 0
