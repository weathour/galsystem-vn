extends Node
## White Album-like day/event scheduler skeleton.

signal day_advanced(day: int)
signal scheduled_event_ready(event_id: String)

var scheduled_events: Array[Dictionary] = []
var triggered_events: Dictionary = {}

func reset() -> void:
	scheduled_events.clear()
	triggered_events.clear()

func schedule_event(event_id: String, day: int, required_flags: Array[String] = [], affection_character: String = "", affection_min: int = 0) -> void:
	scheduled_events.append({
		"id": event_id,
		"day": day,
		"required_flags": required_flags.duplicate(),
		"affection_character": affection_character,
		"affection_min": affection_min,
	})

func advance_day(delta: int = 1) -> void:
	VNState.current_day += delta
	day_advanced.emit(VNState.current_day)
	_check_events()

func check_event(event_id: String) -> bool:
	_check_events()
	return bool(triggered_events.get(event_id, false))

func snapshot() -> Dictionary:
	return {
		"scheduled_events": scheduled_events.duplicate(true),
		"triggered_events": triggered_events.duplicate(true),
	}

func restore(data: Dictionary) -> void:
	reset()
	for item in data.get("scheduled_events", []):
		if typeof(item) == TYPE_DICTIONARY:
			scheduled_events.append(item.duplicate(true))
	triggered_events = data.get("triggered_events", {}).duplicate(true)

func _check_events() -> void:
	for event in scheduled_events:
		var event_id := str(event.get("id", ""))
		if event_id.is_empty() or bool(triggered_events.get(event_id, false)):
			continue
		if int(event.get("day", -1)) > VNState.current_day:
			continue
		var ok := true
		for flag_name in event.get("required_flags", []):
			if not VNState.get_flag(str(flag_name)):
				ok = false
		var character_id := str(event.get("affection_character", ""))
		if ok and not character_id.is_empty() and VNState.get_affection(character_id) < int(event.get("affection_min", 0)):
			ok = false
		if ok:
			triggered_events[event_id] = true
			VNState.set_flag("calendar_event_%s" % event_id, true)
			scheduled_event_ready.emit(event_id)
