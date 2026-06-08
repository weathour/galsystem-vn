extends Node
## Adapter boundary for Nathan Hoad's Dialogue Manager v3.x.
## Keeps VNDirector independent from Dialogue Manager internals and preserves the option
## to keep the self-built ScenarioRunner as a fallback backend.
##
## Dialogue files can call the bridge via mutations, e.g.:
##   do bg("lab_evening")
##   do show("okabe", "serious", "center")
##   do mail_receive("sg001", "unknown", "subject", "body")

signal command_requested(command: String, args: Array)

var resource: Resource
var next_id: String = ""
var current_line: Variant = null
var active: bool = false
var resource_path: String = ""

func reset() -> void:
	resource = null
	current_line = null
	next_id = ""
	active = false
	resource_path = ""

func start(path: String, title: String = "start") -> Dictionary:
	resource_path = path
	resource = load(path)
	if resource == null:
		push_error("DialogueManagerAdapter: failed to load %s" % path)
		active = false
		return {}
	next_id = title
	active = true
	return await get_next_line()

func get_next_line() -> Dictionary:
	if not active or resource == null:
		return {}
	var line: Variant = await DialogueManager.get_next_dialogue_line(resource, next_id, _extra_states())
	if typeof(line) == TYPE_DICTIONARY and line.is_empty():
		active = false
		current_line = null
		return {}
	if line == null:
		active = false
		current_line = null
		return {}
	current_line = line
	next_id = str(line.next_id)
	return _line_to_dictionary(line)

func choose_response(index: int) -> Dictionary:
	if current_line == null:
		return {}
	var responses: Array = current_line.responses
	if index < 0 or index >= responses.size():
		push_error("DialogueManagerAdapter: invalid response index %d" % index)
		return {}
	var response: Variant = responses[index]
	next_id = str(response.next_id)
	return await get_next_line()

func has_responses() -> bool:
	return current_line != null and current_line.responses.size() > 0

func snapshot() -> Dictionary:
	return {
		"resource_path": resource_path,
		"next_id": next_id,
		"active": active,
	}

func restore(data: Dictionary) -> bool:
	resource_path = str(data.get("resource_path", ""))
	next_id = str(data.get("next_id", ""))
	active = bool(data.get("active", false))
	resource = load(resource_path) if not resource_path.is_empty() else null
	return resource != null or not active

# ── Dialogue Manager mutation bridge ───────────────────────────────

func bg(id: String) -> void:
	_emit_command("bg", [id])

func bgm(id: String = "stop") -> void:
	_emit_command("bgm", [id])

func music(id: String = "stop") -> void:
	_emit_command("music", [id])

func sfx(id: String = "none") -> void:
	_emit_command("sfx", [id])

func show(character_id: String, pose: String = "neutral", slot: String = "center") -> void:
	_emit_command("show", [character_id, pose, slot])

func hide(slot: String = "center") -> void:
	_emit_command("hide", [slot])

func clear_chars() -> void:
	_emit_command("clear_chars", [])

func phone_open(screen: String = "inbox") -> void:
	_emit_command("phone", [screen])

func phone_close() -> void:
	_emit_command("phone", ["close"])

func mail_receive(mail_id: String, sender: String, subject: String, body: String = "") -> void:
	_emit_command("mail", [mail_id, sender, subject, body])

func mail_read(mail_id: String) -> void:
	_emit_command("read_mail", [mail_id])

func mail_reply(mail_id: String, keyword: String) -> void:
	_emit_command("reply_mail", [mail_id, keyword])

func schedule_event(event_id: String, day: int, affection_character: String = "", affection_min: int = 0, required_flag: String = "") -> void:
	var args: Array = [event_id, str(day), affection_character, str(affection_min)]
	if not required_flag.is_empty():
		args.append(required_flag)
	_emit_command("schedule_event", args)

func advance_day(delta: int = 1) -> void:
	_emit_command("advance_day", [str(delta)])

func add_affection(character_id: String, delta: int) -> void:
	VNState.add_affection(character_id, delta)

func set_flag(key: String, value: bool = true) -> void:
	VNState.set_flag(key, value)

func set_var(key: String, value: Variant) -> void:
	VNState.set_var(key, value)

func lock_route(route_id: String) -> void:
	RouteManager.lock_route(route_id)

func set_worldline(value: String) -> void:
	VNState.worldline = value

func unlock_tip(tip_id: String) -> void:
	_emit_command("tip", [tip_id])

func unlock_cg(cg_id: String) -> void:
	_emit_command("cg", [cg_id])

func _emit_command(command: String, args: Array) -> void:
	command_requested.emit(command, args)

# ── Conversion ─────────────────────────────────────────────────────

func _line_to_dictionary(line: Variant) -> Dictionary:
	var responses: Array[Dictionary] = []
	for response in line.responses:
		if bool(response.is_allowed):
			responses.append({
				"text": str(response.text),
				"next_id": str(response.next_id),
				"id": str(response.id),
				"tags": response.tags,
			})
	return {
		"id": str(line.id),
		"next_id": str(line.next_id),
		"speaker": str(line.character),
		"text": str(line.text),
		"tags": line.tags,
		"responses": responses,
	}

func _extra_states() -> Array:
	var states: Array = [self]
	if has_node("/root/VNState"):
		states.append(VNState)
	if has_node("/root/PhoneSystem"):
		states.append(PhoneSystem)
	if has_node("/root/CalendarSystem"):
		states.append(CalendarSystem)
	if has_node("/root/RouteManager"):
		states.append(RouteManager)
	return states
