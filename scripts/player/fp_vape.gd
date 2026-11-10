class_name FpVape
extends Node3D
## Vape in der Hand (Ego-Perspektive): hängt an der Kamera, wandert beim Ziehen zum Mund,
## LED färbt sich mit der Zugstärke von Cyan nach Rot. Aussehen folgt der ausgerüsteten Vape.

const REST := Vector3(0.2, -0.2, -0.42)
const MOUTH := Vector3(0.03, -0.11, -0.24)

var tricks: TrickSystem
var _body: MeshInstance3D
var _led_mat: StandardMaterial3D
var _bob := 0.0


func _ready() -> void:
	_body = MeshInstance3D.new()
	add_child(_body)
	var led := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.008
	s.height = 0.016
	led.mesh = s
	_led_mat = StandardMaterial3D.new()
	_led_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	led.material_override = _led_mat
	led.position = Vector3(0, 0.02, 0.016)
	_body.add_child(led)
	for m in [_body, led]:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	refresh()
	Events.item_equipped.connect(func(slot: StringName, _id: StringName): if slot == &"gadget": refresh())
	position = REST


## Form und Farbe der ausgerüsteten Vape (Box-Varianten breiter, Stift-Varianten schlank).
func refresh() -> void:
	var item: ItemDef = Inventory.equipped_item(&"gadget")
	var v: StringName = item.variant if item else &"pen"
	if v == &"tank":
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.024
		cyl.bottom_radius = 0.024
		cyl.height = 0.12
		_body.mesh = cyl
	else:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.05, 0.11, 0.03) if v in [&"box", &"orb"] else (Vector3(0.016, 0.11, 0.016) if v == &"stick" else Vector3(0.022, 0.13, 0.022))
		_body.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = item.color if item else Color("8b5cf6")
	mat.metallic = 0.4
	mat.roughness = 0.35
	_body.material_override = mat
	_body.rotation = Vector3(0.5, -0.35, 0.15)


func _process(delta: float) -> void:
	var inhaling := tricks != null and tricks.is_inhaling()
	var goal := MOUTH if inhaling else REST
	_bob += delta * (2.0 if inhaling else 1.2)
	goal += Vector3(0, sin(_bob) * 0.004, 0)
	position = position.lerp(goal, minf(1.0, delta * 10.0))
	var c := tricks.charge if inhaling else 0.0
	_led_mat.albedo_color = Color("22d3ee").lerp(Color("ef4444"), clampf(c / 100.0, 0.0, 1.0)) if inhaling else Color("22d3ee") * 0.7
