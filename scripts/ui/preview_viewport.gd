class_name PreviewViewport
extends SubViewportContainer
## 3D-Vorschau der eigenen Figur in einer eigenen Mini-Welt (dreht sich langsam).
## show_with(item) zeigt die aktuelle Ausrüstung plus das gewählte Item.

var _viewport: SubViewport
var _visual: CharacterVisual
var _animator: CharacterAnimator
var _pivot: Node3D


func _ready() -> void:
	stretch = true
	custom_minimum_size = Vector2(300, 380)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	add_child(_viewport)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c4b5fd")
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	_viewport.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.6, 0.5, 0)
	key.light_energy = 1.0
	_viewport.add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-1.5, 2.2, 1.5)
	rim.light_color = Color("22d3ee")
	rim.light_energy = 1.5
	rim.omni_range = 5.0
	_viewport.add_child(rim)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.15, -3.2)
	cam.rotation = Vector3(-0.08, PI, 0)
	cam.fov = 40.0
	cam.current = true
	_viewport.add_child(cam)
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = 0.9
	floor_mesh.bottom_radius = 0.9
	floor_mesh.height = 0.05
	var floor_mi := MeshInstance3D.new()
	floor_mi.mesh = floor_mesh
	floor_mi.material_override = CharacterVisual.make_material(UITheme.PURPLE, 0.3, 0.0, 1.2)
	_viewport.add_child(floor_mi)
	_pivot = Node3D.new()
	_viewport.add_child(_pivot)
	_visual = CharacterVisual.new()
	_pivot.add_child(_visual)
	_animator = CharacterAnimator.new()
	_animator.visual = _visual
	add_child(_animator)
	show_with(null)


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_pivot.rotation.y += delta * 0.6


## Aktuelle Ausrüstung + optional ein Item zur Probe.
func show_with(item: ItemDef) -> void:
	var look := {}
	for slot in Inventory.SLOTS:
		look[slot] = Inventory.equipped_item(slot)
	if item:
		look[item.slot()] = item
	_visual.apply_look(look)
	var idle: ItemDef = look.get(&"animation")
	_animator.idle_style = idle.variant if idle else &"chill"
	if item and item.category == &"emote":
		_animator.play_action(item.variant, 2.4, true)
	elif item and item.category == &"animation":
		_animator.cancel_action()
