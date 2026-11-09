class_name CameraRig
extends Node3D
## Third-Person-Kamera: Maussteuerung, SpringArm gegen Wände, weiches Nachziehen, FOV-Kick beim Sprinten.

@export var target: Node3D
@export var height := 1.6
@export var distance := 4.6
@export var follow_speed := 12.0
@export var pitch_min := -1.2
@export var pitch_max := 0.6

var yaw := 0.0
var pitch := -0.25
var camera: Camera3D
var _arm: SpringArm3D
var _fov_extra := 0.0
var _shake := 0.0


func _ready() -> void:
	top_level = true
	_arm = SpringArm3D.new()
	_arm.spring_length = distance
	_arm.margin = 0.2
	var shape := SphereShape3D.new()
	shape.radius = 0.25
	_arm.shape = shape
	add_child(_arm)
	camera = Camera3D.new()
	camera.current = true
	camera.far = 900.0
	_arm.add_child(camera)
	if target:
		global_position = target.global_position + Vector3.UP * height
		_arm.add_excluded_object((target as CollisionObject3D).get_rid() if target is CollisionObject3D else RID())


func rotate_by_mouse(relative: Vector2) -> void:
	var sens := 0.0025 * Settings.mouse_sensitivity
	yaw -= relative.x * sens
	pitch -= relative.y * sens * (-1.0 if Settings.invert_y else 1.0)
	pitch = clampf(pitch, pitch_min, pitch_max)


func set_sprint(on: bool) -> void:
	_fov_extra = 8.0 if on else 0.0


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _process(delta: float) -> void:
	if target == null:
		return
	var goal := target.global_position + Vector3.UP * height
	global_position = global_position.lerp(goal, minf(1.0, delta * follow_speed))
	rotation = Vector3(pitch, yaw, 0)
	camera.fov = lerpf(camera.fov, Settings.fov + _fov_extra, minf(1.0, delta * 6.0))
	_shake = maxf(0.0, _shake - delta * 2.5)
	camera.h_offset = randf_range(-1.0, 1.0) * _shake * 0.15
	camera.v_offset = randf_range(-1.0, 1.0) * _shake * 0.15


## Blickrichtung (horizontal) für die Bewegung.
func forward_flat() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))
