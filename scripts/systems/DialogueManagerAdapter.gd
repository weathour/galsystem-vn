extends Node
## Adapter boundary for Nathan Hoad's Dialogue Manager v3.x.
## Keeps VNDirector independent from Dialogue Manager internals and preserves the option
## to keep the self-built ScenarioRunner as a fallback backend.

const DEFAULT_EXTRA_STATES := []

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
	var states: Array = []
	if has_node("/root/VNState"):
		states.append(VNState)
	if has_node("/root/PhoneSystem"):
		states.append(PhoneSystem)
	if has_node("/root/CalendarSystem"):
		states.append(CalendarSystem)
	if has_node("/root/RouteManager"):
		states.append(RouteManager)
	return states
