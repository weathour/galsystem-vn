extends Node
## Centralized story state for long-form ADV/VN projects.
## Keep every flag, route variable, affection value, and chapter marker here so saves,
## debugging, and route audits remain predictable.

signal flag_changed(key: String, value: bool)
signal variable_changed(key: String, value: Variant)
signal affection_changed(character_id: String, value: int)
signal route_changed(route_id: String)

const STATE_VERSION := 1
const HISTORY_LIMIT := 200

var flags: Dictionary = {}
var variables: Dictionary = {}
var affection: Dictionary = {}
var current_route: String = "common"
var current_chapter: String = "prologue"
var current_day: int = 1
var worldline: String = "1.000000"
var backlog: Array[Dictionary] = []
var unlocked_cg: Dictionary = {}
var unlocked_tips: Dictionary = {}

func reset() -> void:
	flags.clear()
	variables.clear()
	affection.clear()
	current_route = "common"
	current_chapter = "prologue"
	current_day = 1
	worldline = "1.000000"
	backlog.clear()
	unlocked_cg.clear()
	unlocked_tips.clear()
	if has_node("/root/PhoneSystem"):
		PhoneSystem.reset()
	if has_node("/root/CalendarSystem"):
		CalendarSystem.reset()
	if has_node("/root/FlowchartSystem"):
		FlowchartSystem.reset()

func set_flag(key: String, value: bool = true) -> void:
	flags[key] = value
	flag_changed.emit(key, value)

func get_flag(key: String, default_value: bool = false) -> bool:
	return bool(flags.get(key, default_value))

func set_var(key: String, value: Variant) -> void:
	variables[key] = value
	variable_changed.emit(key, value)

func get_var(key: String, default_value: Variant = null) -> Variant:
	return variables.get(key, default_value)

func add_affection(character_id: String, delta: int) -> int:
	var next_value := int(affection.get(character_id, 0)) + delta
	affection[character_id] = next_value
	affection_changed.emit(character_id, next_value)
	return next_value

func get_affection(character_id: String) -> int:
	return int(affection.get(character_id, 0))

func set_route(route_id: String) -> void:
	current_route = route_id
	route_changed.emit(route_id)

func add_backlog(speaker: String, text: String) -> void:
	backlog.append({
		"speaker": speaker,
		"text": text,
		"chapter": current_chapter,
		"route": current_route,
		"day": current_day,
	})
	if backlog.size() > HISTORY_LIMIT:
		backlog.pop_front()

func unlock_cg(cg_id: String) -> void:
	unlocked_cg[cg_id] = true

func unlock_tip(tip_id: String) -> void:
	unlocked_tips[tip_id] = true

func snapshot() -> Dictionary:
	return {
		"state_version": STATE_VERSION,
		"flags": flags.duplicate(true),
		"variables": variables.duplicate(true),
		"affection": affection.duplicate(true),
		"current_route": current_route,
		"current_chapter": current_chapter,
		"current_day": current_day,
		"worldline": worldline,
		"backlog": backlog.duplicate(true),
		"unlocked_cg": unlocked_cg.duplicate(true),
		"unlocked_tips": unlocked_tips.duplicate(true),
	}

func restore(data: Dictionary) -> void:
	flags = data.get("flags", {}).duplicate(true)
	variables = data.get("variables", {}).duplicate(true)
	affection = data.get("affection", {}).duplicate(true)
	current_route = str(data.get("current_route", "common"))
	current_chapter = str(data.get("current_chapter", "prologue"))
	current_day = int(data.get("current_day", 1))
	worldline = str(data.get("worldline", "1.000000"))
	backlog.clear()
	for item in data.get("backlog", []):
		if typeof(item) == TYPE_DICTIONARY:
			backlog.append(item.duplicate(true))
	unlocked_cg = data.get("unlocked_cg", {}).duplicate(true)
	unlocked_tips = data.get("unlocked_tips", {}).duplicate(true)
