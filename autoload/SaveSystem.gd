extends Node
## JSON save/load with save_version. Store state and ScenarioRunner checkpoint together.

const SAVE_VERSION := 1
const SAVE_DIR := "user://saves"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func save_slot(slot_id: int, presentation_state: Dictionary = {}) -> bool:
	var payload := {
		"save_version": SAVE_VERSION,
		"created_unix": Time.get_unix_time_from_system(),
		"slot_id": slot_id,
		"vn_state": VNState.snapshot(),
		"scenario": ScenarioRunner.get_checkpoint(),
		"presentation": presentation_state,
		"phone": PhoneSystem.snapshot() if has_node("/root/PhoneSystem") else {},
		"calendar": CalendarSystem.snapshot() if has_node("/root/CalendarSystem") else {},
		"flowchart": FlowchartSystem.snapshot() if has_node("/root/FlowchartSystem") else {},
	}
	var path := _slot_path(slot_id)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem: cannot write %s" % path)
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	return true

func load_slot(slot_id: int) -> Dictionary:
	var path := _slot_path(slot_id)
	if not FileAccess.file_exists(path):
		push_warning("SaveSystem: slot %d does not exist" % slot_id)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SaveSystem: cannot read %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveSystem: invalid save JSON in %s" % path)
		return {}
	var payload: Dictionary = parsed
	if not _is_valid_payload(payload):
		push_error("SaveSystem: invalid save payload in %s" % path)
		return {}
	VNState.restore(payload.get("vn_state", {}))
	if not ScenarioRunner.restore_checkpoint(payload.get("scenario", {})):
		push_error("SaveSystem: scenario checkpoint restore failed for %s" % path)
		return {}
	if has_node("/root/PhoneSystem"):
		PhoneSystem.restore(payload.get("phone", {}))
	if has_node("/root/CalendarSystem"):
		CalendarSystem.restore(payload.get("calendar", {}))
	if has_node("/root/FlowchartSystem"):
		FlowchartSystem.restore(payload.get("flowchart", {}))
	return payload

func has_slot(slot_id: int) -> bool:
	return FileAccess.file_exists(_slot_path(slot_id))

func _slot_path(slot_id: int) -> String:
	return "%s/slot_%03d.json" % [SAVE_DIR, slot_id]

func _is_valid_payload(payload: Dictionary) -> bool:
	if int(payload.get("save_version", -1)) != SAVE_VERSION:
		return false
	for key in ["vn_state", "scenario", "presentation"]:
		if typeof(payload.get(key)) != TYPE_DICTIONARY:
			return false
	for optional_key in ["phone", "calendar", "flowchart"]:
		if payload.has(optional_key) and typeof(payload.get(optional_key)) != TYPE_DICTIONARY:
			return false
	return true
