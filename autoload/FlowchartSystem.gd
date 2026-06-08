extends Node
## Lightweight flow/debug tracker. This is not a full route-map editor.

signal label_visited(label: String)
signal choice_seen(label: String, choices: Array[Dictionary])

var visited_labels: Array[String] = []
var visited_label_counts: Dictionary = {}
var choice_history: Array[Dictionary] = []
var current_label: String = ""

func reset() -> void:
	visited_labels.clear()
	visited_label_counts.clear()
	choice_history.clear()
	current_label = ""

func visit_label(label: String) -> void:
	if label.is_empty():
		return
	current_label = label
	visited_label_counts[label] = int(visited_label_counts.get(label, 0)) + 1
	if not visited_labels.has(label):
		visited_labels.append(label)
	label_visited.emit(label)

func record_choice(label: String, choices: Array[Dictionary]) -> void:
	choice_history.append({"label": label, "choices": choices.duplicate(true)})
	choice_seen.emit(label, choices)

func snapshot() -> Dictionary:
	return {
		"visited_labels": visited_labels.duplicate(),
		"visited_label_counts": visited_label_counts.duplicate(true),
		"choice_history": choice_history.duplicate(true),
		"current_label": current_label,
	}

func restore(data: Dictionary) -> void:
	reset()
	for label in data.get("visited_labels", []):
		visited_labels.append(str(label))
	visited_label_counts = data.get("visited_label_counts", {}).duplicate(true)
	for item in data.get("choice_history", []):
		if typeof(item) == TYPE_DICTIONARY:
			choice_history.append(item.duplicate(true))
	current_label = str(data.get("current_label", ""))
