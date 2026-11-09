class_name ResourceDir
extends RefCounted
## Lädt alle .tres eines Ordners – funktioniert auch im Export (dort heißen sie *.tres.remap).


static func load_all(dir_path: String) -> Array[Resource]:
	var out: Array[Resource] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("Ordner fehlt: " + dir_path)
		return out
	var files := dir.get_files()
	files.sort()
	for f in files:
		var name := f.trim_suffix(".remap")
		if name.ends_with(".tres") or name.ends_with(".res"):
			var res := load(dir_path.path_join(name))
			if res:
				out.append(res)
			else:
				push_error("Resource kaputt: " + name)
	return out
