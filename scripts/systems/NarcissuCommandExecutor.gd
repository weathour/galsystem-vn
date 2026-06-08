extends RefCounted
## Presentation-facing executor for the committed Narcissu command subset.
## ScenarioRunner owns VM flow/variables; this class owns media/window command dispatch.

const NarcissuAssetResolver := preload("res://scripts/systems/NarcissuAssetResolver.gd")

var resolver: RefCounted
var director: Node
var sprites: Dictionary = {}
var last_background_loaded: bool = false
var last_bgm_loaded: bool = false
var last_sfx_or_voice_loaded: bool = false
var last_results: Dictionary = {}

func _init(target_director: Node = null) -> void:
	director = target_director
	resolver = NarcissuAssetResolver.new()
	resolver.load_manifest()

func reset_runtime_flags() -> void:
	last_background_loaded = false
	last_bgm_loaded = false
	last_sfx_or_voice_loaded = false
	last_results.clear()
	sprites.clear()

func has_private_media() -> bool:
	return resolver.has_private_media()

func handles(command: String) -> bool:
	return command.begins_with("narcissu_") or command in ["bgm", "music", "sfx"]

func execute(command: String, args: Array) -> bool:
	match command:
		"narcissu_bg":
			return _background(args)
		"narcissu_lsp", "narcissu_lsph":
			return _sprite(args, command == "narcissu_lsph")
		"narcissu_vsp":
			return _sprite_visible(args)
		"narcissu_csp":
			return _sprite_clear(args)
		"narcissu_bgm":
			return _bgm(args)
		"narcissu_bgm_stop", "narcissu_bgm_fadeout":
			if director != null and director.has_method("stop_narcissu_bgm"):
				director.call("stop_narcissu_bgm")
			return true
		"narcissu_sfx", "narcissu_voice":
			return _sfx(args, command == "narcissu_voice")
		"narcissu_sfx_stop":
			if director != null and director.has_method("stop_narcissu_sfx"):
				director.call("stop_narcissu_sfx", str(args[0]) if args.size() > 0 else "all")
			return true
		"narcissu_window", "narcissu_erasetextwindow", "narcissu_print", "narcissu_noop":
			return true
		"bgm", "music":
			if args.is_empty() or str(args[0]) == "stop":
				if director != null and director.has_method("stop_narcissu_bgm"):
					director.call("stop_narcissu_bgm")
				return true
			return _bgm([str(args[0]), "loop"])
		"sfx":
			return _sfx(["0", str(args[0]) if args.size() > 0 else "", "once"], false)
	return false

func diagnostics() -> Array[String]:
	return resolver.diagnostics()

func _background(args: Array) -> bool:
	var ref := str(args[0]) if args.size() > 0 else ""
	var result: Dictionary = resolver.load_texture(ref)
	last_results["background"] = result
	last_background_loaded = bool(result.get("texture", null) != null)
	if director != null and director.has_method("show_narcissu_background"):
		director.call("show_narcissu_background", ref, result.get("texture", null), result)
	return true

func _sprite(args: Array, hidden: bool) -> bool:
	if args.size() < 2:
		return true
	var sprite_id := str(args[0])
	var ref := str(args[1])
	var x := float(args[2]) if args.size() > 2 else 0.0
	var y := float(args[3]) if args.size() > 3 else 0.0
	var result: Dictionary = resolver.load_texture(ref)
	sprites[sprite_id] = {"reference": ref, "x": x, "y": y, "hidden": hidden, "loaded": result.get("texture", null) != null}
	last_results["sprite_%s" % sprite_id] = result
	if director != null and director.has_method("show_narcissu_sprite"):
		director.call("show_narcissu_sprite", sprite_id, ref, x, y, result.get("texture", null), not hidden, result)
	return true

func _sprite_visible(args: Array) -> bool:
	if args.is_empty():
		return true
	var sprite_id := str(args[0])
	var visible := bool(int(args[1])) if args.size() > 1 and str(args[1]).is_valid_int() else true
	if director != null and director.has_method("set_narcissu_sprite_visible"):
		director.call("set_narcissu_sprite_visible", sprite_id, visible)
	return true

func _sprite_clear(args: Array) -> bool:
	if director == null or not director.has_method("clear_narcissu_sprite"):
		return true
	if args.is_empty():
		director.call("clear_narcissu_sprite", "all")
	else:
		for arg in args:
			director.call("clear_narcissu_sprite", str(arg))
	return true

func _bgm(args: Array) -> bool:
	var ref := str(args[0]) if args.size() > 0 else ""
	var loop := args.size() < 2 or str(args[1]) == "loop"
	var result: Dictionary = resolver.load_audio(ref, "bgm")
	last_results["bgm"] = result
	last_bgm_loaded = bool(result.get("stream", null) != null)
	if director != null and director.has_method("play_narcissu_bgm"):
		director.call("play_narcissu_bgm", ref, result.get("stream", null), loop, result)
	return true

func _sfx(args: Array, voice: bool) -> bool:
	var channel := str(args[0]) if args.size() > 0 else "0"
	var ref := str(args[1]) if args.size() > 1 else (str(args[0]) if args.size() > 0 else "")
	var result: Dictionary = resolver.load_audio(ref, "voice" if voice else "sfx")
	last_results["voice" if voice else "sfx"] = result
	last_sfx_or_voice_loaded = last_sfx_or_voice_loaded or bool(result.get("stream", null) != null)
	if director != null and director.has_method("play_narcissu_sfx"):
		director.call("play_narcissu_sfx", channel, ref, result.get("stream", null), voice, result)
	return true
