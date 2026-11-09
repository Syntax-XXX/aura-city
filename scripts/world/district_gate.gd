class_name DistrictGate
extends Interactable
## Tor zu einem Distrikt. Blockiert den Weg (StaticBody), bis der Rang reicht – dann fährt es in den Boden.

@export var district_name := ""
@export var required_rank := 1
@export var gate_size := Vector3(14, 6, 1)

var _body: StaticBody3D
var _open := false


func _ready() -> void:
	super._ready()
	_body = StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = gate_size
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0, gate_size.y / 2, 0)
	_body.add_child(col)
	var mesh := BoxMesh.new()
	mesh.size = gate_size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := CharacterVisual.make_material(Color(0.6, 0.3, 1.0, 0.35), 0.2, 0.0, 1.2)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mi.position = col.position
	_body.add_child(mi)
	var label := Label3D.new()
	label.text = "%s\nab Rang %s" % [district_name, Economy.rank_name(required_rank)]
	label.font_size = 96
	label.pixel_size = 0.01
	label.outline_size = 18
	label.position = Vector3(0, gate_size.y + 1.2, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_body.add_child(label)
	add_child(_body)
	Events.rank_changed.connect(func(_r): _update())
	_update(true)


func is_available() -> bool:
	return not _open


func prompt_text() -> String:
	return "%s: benötigt Rang %s (du: %s)" % [district_name, Economy.rank_name(required_rank), Economy.rank_name()]


func interact(_player: Node3D) -> void:
	Audio.play(&"denied")
	Events.toast.emit("Sammle mehr Aura für Rang %s" % Economy.rank_name(required_rank), Color("fca5a5"))


func _update(instant := false) -> void:
	if _open or Economy.rank_index < required_rank:
		return
	_open = true
	if instant or not is_inside_tree():
		_body.queue_free()
		return
	Events.toast.emit("%s ist jetzt offen!" % district_name, Color("4ade80"))
	var tw := create_tween()
	tw.tween_property(_body, "position:y", -gate_size.y - 1.0, 1.5).set_trans(Tween.TRANS_CUBIC)
	tw.tween_callback(_body.queue_free)
