extends SceneTree
## Folds Poly Haven's separate cut-out masks into the colour maps of its
## foliage models (their glTF colour maps are JPEGs, with no transparency):
## for every assets/nature/<id>/textures/<name>_alpha_<res>.png, writes
## <name>_diffa_<res>.png (the colour map with the mask as its alpha), which
## NatureModels then uses for that model's leaves. Run after
## `python3 tools/polyhaven.py model ...`, then import:
##
##   Godot --headless --path . -s tools/merge_alpha.gd
##   Godot --headless --path . --import

const ROOT := "res://assets/nature"


func _initialize() -> void:
	var made := 0
	for id in DirAccess.get_directories_at(ROOT):
		var dir := "%s/%s/textures" % [ROOT, id]
		if not DirAccess.dir_exists_absolute(dir):
			continue
		for f in DirAccess.get_files_at(dir):
			if not f.contains("_alpha_") or f.ends_with(".import"):
				continue
			var stem := f.get_basename()  # <name>_alpha_<res>
			var diff := dir.path_join(stem.replace("_alpha_", "_diff_") + ".jpg")
			var out := dir.path_join(stem.replace("_alpha_", "_diffa_") + ".png")
			if not FileAccess.file_exists(diff):
				print("  no colour map for %s" % f)
				continue
			if FileAccess.file_exists(out):
				continue
			var color := Image.load_from_file(ProjectSettings.globalize_path(diff))
			var mask := Image.load_from_file(ProjectSettings.globalize_path(dir.path_join(f)))
			color.convert(Image.FORMAT_RGBA8)
			mask.convert(Image.FORMAT_L8)
			if mask.get_size() != color.get_size():
				mask.resize(color.get_width(), color.get_height())
			var rgba := color.get_data()
			var a := mask.get_data()
			for i in a.size():
				rgba[i * 4 + 3] = a[i]
			var merged := Image.create_from_data(color.get_width(), color.get_height(), false, Image.FORMAT_RGBA8, rgba)
			merged.save_png(ProjectSettings.globalize_path(out))
			print("  %s" % out)
			made += 1
	print("merged %d mask(s)" % made)
	quit()
