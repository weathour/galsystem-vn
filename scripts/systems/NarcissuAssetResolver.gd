extends RefCounted
## Resolves ignored private Narcissu assets through a manifest or local filesystem scan.
## It intentionally returns paths only; callers decide how to present/play them.

const RuntimeProfile := preload("res://scripts/systems/NarcissuRuntimeProfile.gd")
const IMAGE_EXTS := [".png", ".jpg", ".jpeg", ".bmp", ".webp"]
const AUDIO_EXTS := [".mp3", ".ogg", ".wav"]

var manifest_path: String = RuntimeProfile.MANIFEST_PATH
var game_root_res: String = RuntimeProfile.GAME_DATA_PATH
var game_root_absolute: String = ""
var manifest: Dictionary = {}
var _index: Dictionary = {}
var _loaded_manifest: bool = false
var _diagnostics: Array[String] = []

func load_manifest(path: String = RuntimeProfile.MANIFEST_PATH) -> bool:
	manifest_path = path
	_loaded_manifest = false
	manifest.clear()
	_diagnostics.clear()
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				manifest = parsed
				_loaded_manifest = true
				var root := str(manifest.get("game_root", game_root_res))
				if root.begins_with("res://"):
					game_root_res = root
					game_root_absolute = ProjectSettings.globalize_path(root)
				elif root.is_absolute_path():
					game_root_absolute = root
				else:
					game_root_absolute = ProjectSettings.globalize_path("res://" + root)
			else:
				_diagnostics.append("manifest parse failed: %s" % path)
	else:
		_diagnostics.append("manifest missing: %s" % path)
	if game_root_absolute.is_empty():
		game_root_absolute = ProjectSettings.globalize_path(game_root_res)
	_build_index()
	return _loaded_manifest

func has_private_media() -> bool:
	if _index.size() > 0:
		return true
	return DirAccess.dir_exists_absolute(game_root_absolute)

func diagnostics() -> Array[String]:
	return _diagnostics.duplicate()

func resolve(ref: String, category: String = "") -> Dictionary:
	if ref.is_empty() or ref == "none" or ref == "stop":
		return {"exists": false, "reference": ref, "category": category, "reason": "empty"}
	if manifest.is_empty() and _index.is_empty():
		load_manifest(manifest_path)
	var key := _norm(ref)
	var manifest_assets: Dictionary = manifest.get("assets", {})
	if manifest_assets.has(key):
		var entry: Dictionary = manifest_assets.get(key, {})
		var resolved := _from_manifest_entry(ref, category, entry)
		if bool(resolved.get("exists", false)):
			return resolved
	var rel := _resolve_rel(key)
	if rel.is_empty() and key.get_extension().is_empty():
		for ext in IMAGE_EXTS + AUDIO_EXTS:
			rel = _resolve_rel(key + ext)
			if not rel.is_empty():
				break
	if rel.is_empty():
		_diagnostics.append("missing %s asset: %s" % [category, ref])
		return {"exists": false, "reference": ref, "category": category, "reason": "not_found"}
	return _entry_from_rel(ref, category, rel)

func load_texture(ref: String) -> Dictionary:
	var resolved := resolve(ref, "image")
	if not bool(resolved.get("exists", false)):
		return resolved
	var absolute := str(resolved.get("absolute_path", ""))
	var image := Image.new()
	var err := image.load(absolute)
	if err != OK:
		resolved["load_error"] = err
		resolved["texture"] = null
		return resolved
	resolved["texture"] = ImageTexture.create_from_image(image)
	return resolved

func load_audio(ref: String, category: String = "sfx") -> Dictionary:
	var resolved := resolve(ref, category)
	if not bool(resolved.get("exists", false)):
		return resolved
	var absolute := str(resolved.get("absolute_path", ""))
	var ext := absolute.get_extension().to_lower()
	var stream: AudioStream = null
	match ext:
		"mp3":
			stream = AudioStreamMP3.load_from_file(absolute)
		"ogg":
			stream = AudioStreamOggVorbis.load_from_file(absolute)
		"wav":
			stream = AudioStreamWAV.load_from_file(absolute)
		_:
			resolved["load_error"] = "unsupported_audio_extension"
	resolved["stream"] = stream
	return resolved

func _from_manifest_entry(ref: String, category: String, entry: Dictionary) -> Dictionary:
	var rel := str(entry.get("path", ""))
	if rel.is_empty():
		return {"exists": false, "reference": ref, "category": category, "reason": "manifest_unresolved"}
	return _entry_from_rel(ref, str(entry.get("category", category)), rel)

func _entry_from_rel(ref: String, category: String, rel: String) -> Dictionary:
	var absolute := rel
	if not absolute.is_absolute_path():
		absolute = _join_absolute(game_root_absolute, rel)
	var res_path := ""
	var project_root := ProjectSettings.globalize_path("res://")
	if absolute.begins_with(project_root):
		res_path = "res://" + absolute.substr(project_root.length()).replace("\\", "/")
	return {"exists": FileAccess.file_exists(absolute), "reference": ref, "category": category, "relative_path": rel, "absolute_path": absolute, "res_path": res_path}

func _build_index() -> void:
	_index.clear()
	var root := game_root_absolute
	if root.is_empty() or not DirAccess.dir_exists_absolute(root):
		return
	_scan_dir(root, root)

func _scan_dir(root: String, current: String) -> void:
	var dir := DirAccess.open(current)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		if name != "." and name != "..":
			var abs := current.path_join(name)
			if dir.current_is_dir():
				_scan_dir(root, abs)
			else:
				var rel := abs.substr(root.length()).trim_prefix("/").replace("\\", "/")
				_index[_norm(rel)] = rel
				_index[_norm(name)] = rel
		name = dir.get_next()
	dir.list_dir_end()

func _resolve_rel(key: String) -> String:
	if _index.has(key):
		return str(_index[key])
	var basename := key.get_file()
	if _index.has(basename):
		return str(_index[basename])
	var stem := key.get_basename().get_file()
	for indexed_key in _index.keys():
		if str(indexed_key).get_basename().get_file() == stem:
			return str(_index[indexed_key])
	return ""

func _norm(value: String) -> String:
	return value.replace("\\", "/").replace("//", "/").strip_edges().trim_prefix("./").to_lower()

func _join_absolute(root: String, rel: String) -> String:
	return root.path_join(rel.replace("\\", "/"))
