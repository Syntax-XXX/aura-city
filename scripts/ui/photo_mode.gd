class_name PhotoMode
extends Node
## Foto-Modus [P]: Zeit eingefroren, UI aus, frei fliegende Kamera.
## WASD/Maus bewegen, Leertaste/Strg hoch/runter, Mausrad = Sichtfeld, Enter = Screenshot, P/Esc = zurück.

signal toggled(active: bool)

var active := false
var ui_root: Control
var _cam: Camera3D
var _prev_cam: Camera3D
var _yaw := 0.0
var _pitch := 0.0
var _last := 0
var _hint: Label


func toggle() -> void:
	if active:
		_exit()
	else:
		_enter()


func _enter() -> void:
	_prev_cam = get_viewport().get_camera_3d()
	if _prev_cam == null:
		return
	active = true
	_cam = Camera3D.new()
	_cam.far = 900.0
	_cam.fov = _prev_cam.fov
	get_tree().root.add_child(_cam)
	_cam.global_transform = _prev_cam.global_transform
	var e := _cam.global_transform.basis.get_euler()
	_pitch = e.x
	_yaw = e.y
	_cam.current = true
	Engine.time_scale = 0.0
	ui_root.visible = false
	_hint = Label.new()
	_hint.text = "FOTO-MODUS · WASD/Maus bewegen · Leertaste/Strg hoch/runter · Mausrad Zoom · Enter = Foto · P = zurück"
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	ui_root.get_parent().add_child(_hint)
	UIKit.pin(_hint, Control.PRESET_CENTER_BOTTOM, 16)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if DisplayServer.get_name() != "headless" else Input.mouse_mode
	_last = Time.get_ticks_usec()
	toggled.emit(true)


func _exit() -> void:
	active = false
	Engine.time_scale = 1.0
	if _prev_cam:
		_prev_cam.current = true
	if _cam:
		_cam.queue_free()
	if _hint:
		_hint.queue_free()
	ui_root.visible = true
	toggled.emit(false)


func _process(_delta: float) -> void:
	if not active:
		return
	# echte Zeit, weil time_scale = 0
	var now := Time.get_ticks_usec()
	var dt := minf((now - _last) / 1000000.0, 0.1)
	_last = now
	var dir := Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		dir.z -= 1
	if Input.is_action_pressed("move_back"):
		dir.z += 1
	if Input.is_action_pressed("move_left"):
		dir.x -= 1
	if Input.is_action_pressed("move_right"):
		dir.x += 1
	if Input.is_action_pressed("jump"):
		dir.y += 1
	if Input.is_key_pressed(KEY_CTRL):
		dir.y -= 1
	var speed := 14.0 if Input.is_action_pressed("sprint") else 5.0
	_cam.rotation = Vector3(_pitch, _yaw, 0)
	_cam.global_position += (_cam.global_transform.basis * dir) * speed * dt


func _input(event: InputEvent) -> void:
	if not active:
		return
	var motion := event as InputEventMouseMotion
	if motion:
		_yaw -= motion.relative.x * 0.003
		_pitch = clampf(_pitch - motion.relative.y * 0.003, -1.5, 1.5)
	var mb := event as InputEventMouseButton
	if mb and mb.pressed:
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam.fov = clampf(_cam.fov - 3.0, 20.0, 110.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam.fov = clampf(_cam.fov + 3.0, 20.0, 110.0)
	if event.is_action_pressed("photo_mode") or event.is_action_pressed("pause"):
		_exit()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and (event as InputEventKey).keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_F12]:
		take_photo()
		get_viewport().set_input_as_handled()


func take_photo() -> String:
	_hint.visible = false
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	_hint.visible = true
	DirAccess.make_dir_recursive_absolute("user://screenshots")
	var path := "user://screenshots/aura_%s.png" % Time.get_datetime_string_from_system().replace(":", "-")
	img.save_png(path)
	Audio.play(&"pickup")
	_hint.text = "Foto gespeichert: " + ProjectSettings.globalize_path(path)
	return path
