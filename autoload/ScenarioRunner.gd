extends Node
## Minimal textual scenario runner with a small compatibility VM for converted
## NScripter/PONScripter case-study scripts.
##
## Script grammar examples:
##   label start
##   bg winter_street
##   show kazusa neutral center
##   say 冬马|你迟到了。
##   narr|十二月的风从校舍之间穿过。
##   choice 接电话->phone_call|先放着->ignore_call
##   if_flag phone_replied true_label false_label
##   set_flag met_kazusa true
##   affection kazusa +1
##   jump next_label
##   end

signal scenario_started(path: String, label: String)
signal line_presented(speaker: String, text: String)
signal command_requested(command: String, args: Array)
signal choices_presented(choices: Array[Dictionary])
signal label_changed(label: String)
signal scenario_finished()

var _path: String = ""
var _lines: Array[Dictionary] = []
var _labels: Dictionary = {}
var _index: int = 0
var _waiting_for_choice: bool = false
var _last_label: String = "start"
var _current_speaker: String = ""
var _current_text: String = ""
var _current_choices: Array[Dictionary] = []
var _finished: bool = false
var _last_choice_label: String = ""
var _num_vars: Dictionary = {}
var _str_vars: Dictionary = {}
var _call_stack: Array[int] = []

func start(path: String, label: String = "start") -> bool:
	_path = path
	if not _load(path):
		return false
	_reset_vm()
	_jump_to_label(label)
	_waiting_for_choice = false
	_current_choices.clear()
	_finished = false
	scenario_started.emit(path, label)
	next()
	return true

func next() -> void:
	if _waiting_for_choice or _finished:
		return
	while _index < _lines.size():
		var line: Dictionary = _lines[_index]
		_index += 1
		var op: String = str(line.get("op", ""))
		var args: Array = line.get("args", [])
		match op:
			"label":
				if args.size() > 0:
					_record_label(str(args[0]))
				continue
			"narr":
				var narr_text: String = str(args[0]) if args.size() > 0 else ""
				_present_line("", narr_text)
				return
			"say":
				var speaker: String = str(args[0]) if args.size() > 0 else ""
				var say_text: String = str(args[1]) if args.size() > 1 else ""
				_present_line(speaker, say_text)
				return
			"choice":
				_waiting_for_choice = true
				_current_choices = _parse_choices(args)
				_last_choice_label = _last_label
				if has_node("/root/FlowchartSystem"):
					FlowchartSystem.record_choice(_last_choice_label, _current_choices)
				choices_presented.emit(_current_choices)
				return
			"jump":
				if args.size() > 0:
					_jump_to_label(str(args[0]))
				continue
			"call":
				if args.size() > 0:
					_call_label(str(args[0]))
				continue
			"return":
				_return_from_call()
				continue
			"if_flag":
				if args.size() >= 3:
					_jump_to_label(str(args[1]) if VNState.get_flag(str(args[0])) else str(args[2]))
				continue
			"if_var":
				if args.size() >= 4:
					var actual: String = str(VNState.get_var(str(args[0]), ""))
					_jump_to_label(str(args[2]) if actual == str(args[1]) else str(args[3]))
				continue
			"if_expr":
				if args.size() >= 3 and _eval_expr(str(args[0])):
					if str(args[1]) == "gosub":
						_call_label(str(args[2]))
					else:
						_jump_to_label(str(args[2]))
				continue
			"tablegoto":
				_handle_tablegoto(args)
				continue
			"if_affection":
				if args.size() >= 4:
					var affection_value := VNState.get_affection(str(args[0]))
					_jump_to_label(str(args[2]) if affection_value >= int(args[1]) else str(args[3]))
				continue
			"if_calendar_event":
				if args.size() >= 3:
					var event_ready := CalendarSystem.check_event(str(args[0])) if has_node("/root/CalendarSystem") else VNState.get_flag("calendar_event_%s" % str(args[0]))
					_jump_to_label(str(args[1]) if event_ready else str(args[2]))
				continue
			"set_flag":
				if args.size() >= 1:
					VNState.set_flag(str(args[0]), _parse_bool(str(args[1])) if args.size() > 1 else true)
				continue
			"set_var":
				if args.size() >= 2:
					VNState.set_var(str(args[0]), " ".join(args.slice(1)))
				continue
			"set_value", "add_value", "sub_value", "mul_value":
				_handle_value_op(op, args)
				continue
			"affection":
				if args.size() >= 2:
					VNState.add_affection(str(args[0]), int(args[1]))
				continue
			"route":
				if args.size() > 0:
					RouteManager.lock_route(str(args[0]))
				continue
			"chapter":
				if args.size() > 0:
					VNState.current_chapter = str(args[0])
				continue
			"day":
				if args.size() > 0:
					VNState.current_day = int(args[0])
				continue
			"worldline":
				if args.size() > 0:
					VNState.worldline = str(args[0])
				continue
			"wait":
				command_requested.emit(op, args)
				continue
			"end":
				_finish()
				return
			_:
				command_requested.emit(op, args)
				continue
	_finish()

func choose(choice_index: int) -> void:
	if not _waiting_for_choice:
		return
	if choice_index < 0 or choice_index >= _current_choices.size():
		push_error("ScenarioRunner: invalid choice index %d" % choice_index)
		return
	_waiting_for_choice = false
	var choice: Dictionary = _current_choices[choice_index]
	_current_choices.clear()
	_jump_to_label(str(choice.get("target", "")))
	next()

func refresh_display() -> void:
	if _waiting_for_choice:
		choices_presented.emit(_current_choices)
	elif not _current_text.is_empty() or not _current_speaker.is_empty():
		line_presented.emit(_current_speaker, _current_text)
	elif _finished:
		scenario_finished.emit()

func get_current_line() -> Dictionary:
	return {"speaker": _current_speaker, "text": _current_text}

func is_waiting_for_choice() -> bool:
	return _waiting_for_choice

func is_finished() -> bool:
	return _finished

func get_compatibility_state() -> Dictionary:
	return {
		"num_vars": _num_vars.duplicate(true),
		"str_vars": _str_vars.duplicate(true),
		"call_stack": _call_stack.duplicate(),
	}

func get_checkpoint() -> Dictionary:
	return {
		"path": _path,
		"index": _index,
		"last_label": _last_label,
		"waiting_for_choice": _waiting_for_choice,
		"current_speaker": _current_speaker,
		"current_text": _current_text,
		"current_choices": _current_choices.duplicate(true),
		"last_choice_label": _last_choice_label,
		"finished": _finished,
		"compatibility": get_compatibility_state(),
	}

func restore_checkpoint(data: Dictionary) -> bool:
	var path: String = str(data.get("path", ""))
	if path.is_empty():
		return false
	if not _load(path):
		return false
	_path = path
	_index = clampi(int(data.get("index", 0)), 0, _lines.size())
	_last_label = str(data.get("last_label", "start"))
	_waiting_for_choice = bool(data.get("waiting_for_choice", false))
	_current_speaker = str(data.get("current_speaker", ""))
	_current_text = str(data.get("current_text", ""))
	_current_choices.clear()
	for choice in data.get("current_choices", []):
		if typeof(choice) == TYPE_DICTIONARY:
			_current_choices.append(choice.duplicate(true))
	_last_choice_label = str(data.get("last_choice_label", ""))
	_finished = bool(data.get("finished", false))
	_restore_compatibility(data.get("compatibility", {}))
	return true

func _present_line(speaker: String, text: String) -> void:
	_current_speaker = speaker
	_current_text = text
	_current_choices.clear()
	VNState.add_backlog(speaker, text)
	line_presented.emit(speaker, text)

func _finish() -> void:
	_finished = true
	scenario_finished.emit()

func _load(path: String) -> bool:
	if not FileAccess.file_exists(path):
		push_error("ScenarioRunner: missing script %s" % path)
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("ScenarioRunner: cannot open %s" % path)
		return false
	_parse(file.get_as_text())
	return true

func _parse(text: String) -> void:
	_lines.clear()
	_labels.clear()
	var raw_lines := text.split("\n")
	for raw in raw_lines:
		var trimmed := raw.strip_edges()
		if trimmed.is_empty() or trimmed.begins_with("#"):
			continue
		var parsed := _parse_line(trimmed)
		if parsed.is_empty():
			continue
		if parsed.get("op", "") == "label" and parsed.get("args", []).size() > 0:
			_labels[parsed["args"][0]] = _lines.size()
		_lines.append(parsed)

func _parse_line(line: String) -> Dictionary:
	if line.begins_with("say "):
		var payload := line.substr(4)
		var parts := payload.split("|", true, 1)
		return {"op": "say", "args": [parts[0].strip_edges(), parts[1].strip_edges() if parts.size() > 1 else ""]}
	if line.begins_with("narr|"):
		return {"op": "narr", "args": [line.substr(5).strip_edges()]}
	if line.begins_with("choice "):
		return {"op": "choice", "args": [line.substr(7).strip_edges()]}
	var tokens := _split_tokens(line)
	if tokens.is_empty():
		return {}
	var op := str(tokens[0])
	var args: Array = []
	for i in range(1, tokens.size()):
		args.append(tokens[i])
	return {"op": op, "args": args}

func _split_tokens(line: String) -> Array:
	var result: Array = []
	var current := ""
	var in_quote := false
	var escaped := false
	for i in range(line.length()):
		var ch := line[i]
		if escaped:
			current += ch
			escaped = false
			continue
		if ch == "\\" and in_quote:
			current += ch
			escaped = true
			continue
		if ch == '"':
			current += ch
			in_quote = not in_quote
			continue
		if ch == " " or ch == "\t":
			if in_quote:
				current += ch
			elif not current.is_empty():
				result.append(_decode_token(current))
				current = ""
		else:
			current += ch
	if not current.is_empty():
		result.append(_decode_token(current))
	return result

func _decode_token(token: String) -> Variant:
	if token.begins_with('"') and token.ends_with('"'):
		var parsed: Variant = JSON.parse_string(token)
		if parsed != null:
			return parsed
		return token.trim_prefix('"').trim_suffix('"')
	return token

func _parse_choices(args: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if args.is_empty():
		return result
	for item in str(args[0]).split("|", false):
		var pair: PackedStringArray = item.split("->", true, 1)
		if pair.size() == 2:
			result.append({"text": pair[0].strip_edges(), "target": pair[1].strip_edges()})
	return result

func _jump_to_label(label: String) -> void:
	if not _labels.has(label):
		push_error("ScenarioRunner: missing label %s" % label)
		return
	_record_label(label)
	_index = int(_labels[label]) + 1

func _call_label(label: String) -> void:
	if not _labels.has(label):
		push_error("ScenarioRunner: missing call label %s" % label)
		return
	_call_stack.append(_index)
	_jump_to_label(label)

func _return_from_call() -> void:
	if _call_stack.is_empty():
		return
	_index = int(_call_stack.pop_back())

func _record_label(label: String) -> void:
	_last_label = label
	if has_node("/root/FlowchartSystem"):
		FlowchartSystem.visit_label(label)
	label_changed.emit(label)

func _handle_value_op(op: String, args: Array) -> void:
	if args.size() < 2:
		return
	var name := _var_name(str(args[0]))
	var raw_value: Variant = args[1]
	var value: Variant = _value_for_token(raw_value)
	if op == "set_value":
		if typeof(value) == TYPE_STRING and not str(value).is_valid_float():
			_str_vars[name] = str(value)
		else:
			_num_vars[name] = int(value)
		return
	var current := int(_num_vars.get(name, 0))
	var numeric := int(value) if str(value).is_valid_int() or typeof(value) in [TYPE_INT, TYPE_FLOAT] else 0
	match op:
		"add_value":
			_num_vars[name] = current + numeric
		"sub_value":
			_num_vars[name] = current - numeric
		"mul_value":
			_num_vars[name] = current * numeric

func _handle_tablegoto(args: Array) -> void:
	if args.size() < 2:
		return
	var index_value := int(_num_vars.get(_var_name(str(args[0])), 0))
	var label_index := clampi(index_value, 0, args.size() - 2)
	_jump_to_label(str(args[label_index + 1]))

func _eval_expr(expr: String) -> bool:
	if expr.contains("&&"):
		for part in expr.split("&&", false):
			if not _eval_expr(part.strip_edges()):
				return false
		return true
	if expr.contains("||"):
		for part in expr.split("||", false):
			if _eval_expr(part.strip_edges()):
				return true
		return false
	for op in [">=", "<=", "!=", "==", "<>", ">", "<"]:
		var idx := expr.find(op)
		if idx >= 0:
			var left: Variant = _value_for_token(expr.substr(0, idx).strip_edges())
			var right: Variant = _value_for_token(expr.substr(idx + op.length()).strip_edges())
			return _compare_values(left, right, op)
	return bool(int(_value_for_token(expr)))

func _compare_values(left: Variant, right: Variant, op: String) -> bool:
	var left_num := int(left) if str(left).is_valid_int() or typeof(left) in [TYPE_INT, TYPE_FLOAT] else 0
	var right_num := int(right) if str(right).is_valid_int() or typeof(right) in [TYPE_INT, TYPE_FLOAT] else 0
	match op:
		">=": return left_num >= right_num
		"<=": return left_num <= right_num
		"!=", "<>": return str(left) != str(right)
		"==": return str(left) == str(right)
		">": return left_num > right_num
		"<": return left_num < right_num
	return false

func _value_for_token(token: Variant) -> Variant:
	var text := str(token).strip_edges()
	if text.begins_with("$"):
		return _str_vars.get(_var_name(text), "")
	if text.begins_with("%"):
		return _num_vars.get(_var_name(text), 0)
	if text.is_valid_int():
		return int(text)
	return text.trim_prefix('"').trim_suffix('"')

func _var_name(token: String) -> String:
	var name := token.strip_edges()
	if name.begins_with("%") or name.begins_with("$"):
		name = name.substr(1)
	return name

func _reset_vm() -> void:
	_num_vars.clear()
	_str_vars.clear()
	_call_stack.clear()

func _restore_compatibility(data: Dictionary) -> void:
	_num_vars = data.get("num_vars", {}).duplicate(true)
	_str_vars = data.get("str_vars", {}).duplicate(true)
	_call_stack.clear()
	for item in data.get("call_stack", []):
		_call_stack.append(int(item))

func _parse_bool(value: String) -> bool:
	return value.to_lower() in ["true", "1", "yes", "on"]
