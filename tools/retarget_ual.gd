extends SceneTree
## Aufruf: godot --headless -s tools/retarget_ual.gd   (erzeugt assets/characters/ual_anims.res)
## Retarget: Universal Animation Library (UAL-Rig) → Quaternius-Charakter-Rig.
## Pro Frame: Welt-Rotationsdelta zur Ruhepose übertragen, Positionen per Vorwärtskinematik,
## Füße (hängen am Root) an das Schienbein-Ende setzen. Ergebnis: AnimationLibrary (.res).

const MAP := {
	"Hips": "DEF-hips", "Abdomen": "DEF-spine.001", "Torso": "DEF-spine.003", "Neck": "DEF-neck", "Head": "DEF-head",
	"Shoulder.L": "DEF-shoulder.L", "UpperArm.L": "DEF-upper_arm.L", "LowerArm.L": "DEF-forearm.L", "Fist.L": "DEF-hand.L",
	"Shoulder.R": "DEF-shoulder.R", "UpperArm.R": "DEF-upper_arm.R", "LowerArm.R": "DEF-forearm.R", "Fist.R": "DEF-hand.R",
	"UpperLeg.L": "DEF-thigh.L", "LowerLeg.L": "DEF-shin.L", "Foot.L": "DEF-foot.L",
	"UpperLeg.R": "DEF-thigh.R", "LowerLeg.R": "DEF-shin.R", "Foot.R": "DEF-foot.R",
}
const FEET := {"Foot.L": "LowerLeg.L_end", "Foot.R": "LowerLeg.R_end"}
const FPS := 30.0

var src_sk: Skeleton3D
var src_ap: AnimationPlayer
var tgt_sk: Skeleton3D


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "res://assets/characters/ual_anims.res"
	var src: Node3D = (load("res://assets/characters/source/UAL.glb") as PackedScene).instantiate()
	var tgt: Node3D = (load("res://assets/characters/models/Casual_Male.fbx") as PackedScene).instantiate()
	get_root().add_child(src)
	get_root().add_child(tgt)
	await process_frame
	src_sk = src.find_child("Skeleton3D", true, false)
	src_ap = src.find_child("AnimationPlayer", true, false)
	tgt_sk = tgt.find_child("Skeleton3D", true, false)
	(tgt.find_child("AnimationPlayer", true, false) as AnimationPlayer).active = false
	var skel_path := String(tgt.get_path_to(tgt_sk))
	# Ruheposen in Weltkoordinaten
	src_sk.reset_bone_poses()
	var src_rest := {}
	for b in MAP.values():
		src_rest[b] = _src_world(src_sk.find_bone(b))
	var src_hips_rest: Vector3 = src_rest["DEF-hips"].origin
	var T := tgt_sk.global_transform
	var T_rot := T.basis.orthonormalized()
	var tgt_rest_world := {} # bone index -> Transform3D (Welt, Rotation orthonormal)
	for i in tgt_sk.get_bone_count():
		var g := tgt_sk.get_bone_global_rest(i)
		tgt_rest_world[i] = Transform3D(T_rot * g.basis.orthonormalized(), T * g.origin)
	var hips_i := tgt_sk.find_bone("Hips")
	var scale: float = tgt_rest_world[hips_i].origin.y / src_hips_rest.y
	var lib := AnimationLibrary.new()
	for anim_name in src_ap.get_animation_list():
		if anim_name == "A_TPose":
			continue
		var src_anim := src_ap.get_animation(anim_name)
		var a := Animation.new()
		a.length = src_anim.length
		a.loop_mode = src_anim.loop_mode
		var rot_tracks := {}
		var pos_tracks := {}
		for i in tgt_sk.get_bone_count():
			var bn := tgt_sk.get_bone_name(i)
			if MAP.has(bn):
				var t := a.add_track(Animation.TYPE_ROTATION_3D)
				a.track_set_path(t, "%s:%s" % [skel_path, bn])
				rot_tracks[i] = t
			if bn == "Hips" or FEET.has(bn):
				var t2 := a.add_track(Animation.TYPE_POSITION_3D)
				a.track_set_path(t2, "%s:%s" % [skel_path, bn])
				pos_tracks[i] = t2
		src_ap.play(anim_name)
		var frames := maxi(2, ceili(src_anim.length * FPS) + 1)
		for f in frames:
			var time := minf(f / FPS, src_anim.length)
			src_ap.seek(time, true)
			var world := {} # Ziel-Welt-Transform pro Knochen
			for i in tgt_sk.get_bone_count():
				var bn := tgt_sk.get_bone_name(i)
				var parent := tgt_sk.get_bone_parent(i)
				var rest_local := tgt_sk.get_bone_rest(i)
				var pw: Transform3D = world[parent] if parent >= 0 else Transform3D(T_rot, T.origin)
				var basis: Basis
				if MAP.has(bn):
					var sw := _src_world(src_sk.find_bone(MAP[bn]))
					var delta: Basis = sw.basis.orthonormalized() * (src_rest[MAP[bn]] as Transform3D).basis.orthonormalized().inverse()
					basis = delta * (tgt_rest_world[i] as Transform3D).basis
				else:
					basis = pw.basis * rest_local.basis.orthonormalized()
				var origin: Vector3
				if parent >= 0:
					# Position aus Elternknochen (Skelettraum-Offset × Armature-Skalierung)
					origin = pw.origin + pw.basis * (rest_local.origin * T.basis.get_scale())
				else:
					origin = T * rest_local.origin
				if bn == "Hips":
					var sh := _src_world(src_sk.find_bone("DEF-hips")).origin
					origin = (tgt_rest_world[i] as Transform3D).origin + (sh - src_hips_rest) * scale
				world[i] = Transform3D(basis, origin)
			# Füße an das Schienbein-Ende
			for fb in FEET:
				var fi := tgt_sk.find_bone(fb)
				var end_i := tgt_sk.find_bone(FEET[fb])
				world[fi] = Transform3D(world[fi].basis, world[end_i].origin)
			for i in rot_tracks:
				var local := _to_local(i, world, T, T_rot)
				a.rotation_track_insert_key(rot_tracks[i], time, local.basis.get_rotation_quaternion())
			for i in pos_tracks:
				var local2 := _to_local(i, world, T, T_rot)
				a.position_track_insert_key(pos_tracks[i], time, local2.origin)
		lib.add_animation(anim_name, a)
		print("baked ", anim_name, " ", frames, " frames")
	ResourceSaver.save(lib, out_path)
	print("saved ", out_path)
	quit()


func _src_world(i: int) -> Transform3D:
	return src_sk.global_transform * src_sk.get_bone_global_pose(i)


## Welt-Transform → lokale Knochenpose (relativ zum Eltern-Knochen im Skelettraum)
func _to_local(i: int, world: Dictionary, T: Transform3D, T_rot: Basis) -> Transform3D:
	var w: Transform3D = world[i]
	var skel := Transform3D(T_rot.inverse() * w.basis, T.affine_inverse() * w.origin)
	var parent := tgt_sk.get_bone_parent(i)
	if parent < 0:
		return skel
	var pw: Transform3D = world[parent]
	var pskel := Transform3D(T_rot.inverse() * pw.basis, T.affine_inverse() * pw.origin)
	return pskel.affine_inverse() * skel
