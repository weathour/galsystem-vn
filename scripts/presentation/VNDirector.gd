extends Control
## Runtime presentation shell for the Phase-1 ADV vertical slice.
## The shell is intentionally independent from ScenarioRunner internals so the runner can
## later be replaced by Dialogue Manager or another adapter.

const START_SCRIPT := "res://scenario/common/prologue.galscript"
const DM_MAIN_SCRIPT := "res://scenario/dialogue_manager/chapter_01.dialogue"
const SAVE_SLOT_COUNT := 6

var background: ColorRect
var background_label: Label
var character_slots: Dictionary = {}
var title_panel: PanelContainer
var dialogue_panel: PanelContainer
var speaker_label: Label
var text_label: RichTextLabel
var choice_box: VBoxContainer
var status_label: Label
var phone_overlay: PanelContainer
var phone_label: Label
var backlog_panel: PanelContainer
var backlog_text: RichTextLabel
var system_menu: PanelContainer
var save_load_panel: PanelContainer
var save_load_list: VBoxContainer
var debug_panel: PanelContainer
var debug_text: RichTextLabel
var flow_panel: PanelContainer
var flow_text: RichTextLabel

var _current_full_text: String = ""
var _typing: bool = false
var _type_accumulator: float = 0.0
var _type_chars_per_second: float = 42.0
var _auto_mode: bool = false
var _skip_mode: bool = false
var _auto_wait: float = 0.0
var _last_status_message: String = "LMB/Space: 推进  Esc: 菜单  B: 历史  F1: 调试  F2: 流程  F5/F9: 快存/快读"
var _menu_open: bool = false
var _game_started: bool = false
var _dialogue_backend: String = "galscript"

enum SaveLoadMode { SAVE, LOAD }
var _save_load_mode: SaveLoadMode = SaveLoadMode.SAVE

func _ready() -> void:
	_validate_extension_scripts()
	_build_ui()
	_connect_runner()
	_show_title()
	if _has_cmdline_flag("--galsystem-smoke"):
		call_deferred("_run_smoke_test")
	elif _has_cmdline_flag("--galsystem-qa-invalid-save"):
		call_deferred("_run_invalid_save_qa")
	elif _has_cmdline_flag("--galsystem-dm-smoke"):
		call_deferred("_run_dialogue_manager_smoke")

func _process(delta: float) -> void:
	_update_typewriter(delta)
	_update_auto_skip(delta)
	if debug_panel.visible:
		_refresh_debug_panel()
	if flow_panel.visible:
		_refresh_flow_panel()

func _validate_extension_scripts() -> void:
	assert(load("res://scripts/systems/PhoneSystem.gd") != null)
	assert(load("res://scripts/systems/CalendarSystem.gd") != null)
	assert(load("res://autoload/FlowchartSystem.gd") != null)

func _connect_runner() -> void:
	ScenarioRunner.line_presented.connect(_on_line_presented)
	ScenarioRunner.command_requested.connect(_on_command_requested)
	ScenarioRunner.choices_presented.connect(_on_choices_presented)
	ScenarioRunner.scenario_finished.connect(_on_scenario_finished)
	DialogueManagerAdapter.command_requested.connect(_on_command_requested)

func _has_cmdline_flag(flag: String) -> bool:
	return flag in OS.get_cmdline_args() or flag in OS.get_cmdline_user_args()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("advance_text"):
		_handle_advance()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				_toggle_system_menu()
			KEY_F1:
				_toggle_debug_panel()
			KEY_F2:
				_toggle_flow_panel()
			KEY_F5:
				_quick_save()
			KEY_F9:
				_quick_load()
			KEY_B:
				_toggle_backlog()
			KEY_A:
				_toggle_auto_mode()
			KEY_S:
				_toggle_skip_mode()

func _handle_advance() -> void:
	if title_panel.visible:
		_start_new_game()
		return
	if _menu_open or backlog_panel.visible or save_load_panel.visible or debug_panel.visible or flow_panel.visible:
		_close_overlays()
		return
	if choice_box.visible:
		return
	if _typing:
		_finish_typewriter()
		return
	if _dialogue_backend == "dialogue_manager":
		_advance_dialogue_manager()
	else:
		ScenarioRunner.next()

func _build_ui() -> void:
	_build_background()
	_build_character_stage()
	_build_dialogue_panel()
	_build_choice_box()
	_build_status_label()
	_build_phone_overlay()
	_build_backlog_panel()
	_build_system_menu()
	_build_save_load_panel()
	_build_debug_panel()
	_build_flow_panel()
	_build_title_panel()
	_set_status(_last_status_message)

func _build_background() -> void:
	background = ColorRect.new()
	background.name = "Background"
	background.color = Color(0.08, 0.10, 0.14)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	background_label = Label.new()
	background_label.text = "bg: title"
	background_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	background_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	background_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	background_label.add_theme_font_size_override("font_size", 34)
	background.add_child(background_label)

func _build_character_stage() -> void:
	var stage := Control.new()
	stage.name = "CharacterStage"
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(stage)
	for slot_name in ["left", "center", "right"]:
		var panel := PanelContainer.new()
		panel.name = "Character_%s" % slot_name
		panel.visible = false
		panel.custom_minimum_size = Vector2(260, 440)
		panel.anchor_top = 0.18
		panel.anchor_bottom = 0.85
		panel.offset_top = 0
		panel.offset_bottom = 0
		match slot_name:
			"left":
				panel.anchor_left = 0.08
				panel.anchor_right = 0.30
			"center":
				panel.anchor_left = 0.39
				panel.anchor_right = 0.61
			"right":
				panel.anchor_left = 0.70
				panel.anchor_right = 0.92
		var label := Label.new()
		label.name = "Label"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 26)
		panel.add_child(label)
		stage.add_child(panel)
		character_slots[slot_name] = panel

func _build_dialogue_panel() -> void:
	dialogue_panel = PanelContainer.new()
	dialogue_panel.name = "DialoguePanel"
	dialogue_panel.anchor_left = 0.08
	dialogue_panel.anchor_right = 0.92
	dialogue_panel.anchor_top = 0.70
	dialogue_panel.anchor_bottom = 0.96
	dialogue_panel.offset_left = 0
	dialogue_panel.offset_right = 0
	dialogue_panel.offset_top = 0
	dialogue_panel.offset_bottom = 0
	add_child(dialogue_panel)

	var dialogue_vbox := VBoxContainer.new()
	dialogue_panel.add_child(dialogue_vbox)
	speaker_label = Label.new()
	speaker_label.add_theme_font_size_override("font_size", 24)
	dialogue_vbox.add_child(speaker_label)
	text_label = RichTextLabel.new()
	text_label.bbcode_enabled = true
	text_label.fit_content = true
	text_label.scroll_active = false
	text_label.visible_characters_behavior = TextServer.VC_CHARS_BEFORE_SHAPING
	text_label.add_theme_font_size_override("normal_font_size", 28)
	dialogue_vbox.add_child(text_label)

func _build_choice_box() -> void:
	choice_box = VBoxContainer.new()
	choice_box.name = "ChoiceBox"
	choice_box.visible = false
	choice_box.anchor_left = 0.58
	choice_box.anchor_right = 0.92
	choice_box.anchor_top = 0.30
	choice_box.anchor_bottom = 0.68
	add_child(choice_box)

func _build_status_label() -> void:
	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.anchor_left = 0.02
	status_label.anchor_top = 0.02
	status_label.anchor_right = 0.98
	status_label.anchor_bottom = 0.08
	status_label.add_theme_font_size_override("font_size", 16)
	add_child(status_label)

func _build_phone_overlay() -> void:
	phone_overlay = PanelContainer.new()
	phone_overlay.name = "PhoneOverlay"
	phone_overlay.visible = false
	phone_overlay.anchor_left = 0.68
	phone_overlay.anchor_right = 0.95
	phone_overlay.anchor_top = 0.10
	phone_overlay.anchor_bottom = 0.66
	phone_label = Label.new()
	phone_label.name = "PhoneLabel"
	phone_label.text = "PHONE\n\n这里是手机/短信/电话触发器 UI 占位。"
	phone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phone_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	phone_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	phone_overlay.add_child(phone_label)
	add_child(phone_overlay)

func _build_backlog_panel() -> void:
	backlog_panel = PanelContainer.new()
	backlog_panel.name = "BacklogPanel"
	backlog_panel.visible = false
	backlog_panel.anchor_left = 0.10
	backlog_panel.anchor_right = 0.90
	backlog_panel.anchor_top = 0.08
	backlog_panel.anchor_bottom = 0.88
	var vbox := VBoxContainer.new()
	backlog_panel.add_child(vbox)
	var title := Label.new()
	title.text = "Backlog / 历史文本（B 或点击任意处关闭）"
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)
	backlog_text = RichTextLabel.new()
	backlog_text.bbcode_enabled = true
	backlog_text.fit_content = false
	backlog_text.scroll_active = true
	backlog_text.custom_minimum_size = Vector2(900, 460)
	backlog_text.add_theme_font_size_override("normal_font_size", 22)
	vbox.add_child(backlog_text)
	add_child(backlog_panel)

func _build_system_menu() -> void:
	system_menu = PanelContainer.new()
	system_menu.name = "SystemMenu"
	system_menu.visible = false
	system_menu.anchor_left = 0.36
	system_menu.anchor_right = 0.64
	system_menu.anchor_top = 0.18
	system_menu.anchor_bottom = 0.72
	var vbox := VBoxContainer.new()
	system_menu.add_child(vbox)
	var title := Label.new()
	title.text = "System"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)
	vbox.add_child(_menu_button("开始 .galscript", func() -> void: _start_new_game()))
	vbox.add_child(_menu_button("开始 Dialogue Manager", func() -> void: _start_dialogue_manager_sample()))
	vbox.add_child(_menu_button("保存", func() -> void: _open_save_load(SaveLoadMode.SAVE)))
	vbox.add_child(_menu_button("读取", func() -> void: _open_save_load(SaveLoadMode.LOAD)))
	vbox.add_child(_menu_button("Backlog", func() -> void: _toggle_backlog()))
	vbox.add_child(_menu_button("Flow", func() -> void: _toggle_flow_panel()))
	vbox.add_child(_menu_button("Debug", func() -> void: _toggle_debug_panel()))
	vbox.add_child(_menu_button("Auto/Skip", func() -> void: _toggle_auto_mode()))
	vbox.add_child(_menu_button("关闭", func() -> void: _toggle_system_menu(false)))
	add_child(system_menu)

func _build_save_load_panel() -> void:
	save_load_panel = PanelContainer.new()
	save_load_panel.name = "SaveLoadPanel"
	save_load_panel.visible = false
	save_load_panel.anchor_left = 0.18
	save_load_panel.anchor_right = 0.82
	save_load_panel.anchor_top = 0.12
	save_load_panel.anchor_bottom = 0.86
	var vbox := VBoxContainer.new()
	save_load_panel.add_child(vbox)
	var title := Label.new()
	title.name = "Title"
	title.text = "Save/Load"
	title.add_theme_font_size_override("font_size", 26)
	vbox.add_child(title)
	save_load_list = VBoxContainer.new()
	vbox.add_child(save_load_list)
	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.pressed.connect(func() -> void: save_load_panel.visible = false)
	vbox.add_child(close_button)
	add_child(save_load_panel)

func _build_debug_panel() -> void:
	debug_panel = PanelContainer.new()
	debug_panel.name = "DebugPanel"
	debug_panel.visible = false
	debug_panel.anchor_left = 0.03
	debug_panel.anchor_right = 0.45
	debug_panel.anchor_top = 0.10
	debug_panel.anchor_bottom = 0.66
	debug_text = RichTextLabel.new()
	debug_text.bbcode_enabled = true
	debug_text.fit_content = false
	debug_text.scroll_active = true
	debug_text.add_theme_font_size_override("normal_font_size", 16)
	debug_panel.add_child(debug_text)
	add_child(debug_panel)

func _build_flow_panel() -> void:
	flow_panel = PanelContainer.new()
	flow_panel.name = "FlowPanel"
	flow_panel.visible = false
	flow_panel.anchor_left = 0.50
	flow_panel.anchor_right = 0.95
	flow_panel.anchor_top = 0.10
	flow_panel.anchor_bottom = 0.66
	flow_text = RichTextLabel.new()
	flow_text.bbcode_enabled = true
	flow_text.fit_content = false
	flow_text.scroll_active = true
	flow_text.add_theme_font_size_override("normal_font_size", 16)
	flow_panel.add_child(flow_text)
	add_child(flow_panel)

func _build_title_panel() -> void:
	title_panel = PanelContainer.new()
	title_panel.name = "TitlePanel"
	title_panel.anchor_left = 0.32
	title_panel.anchor_right = 0.68
	title_panel.anchor_top = 0.20
	title_panel.anchor_bottom = 0.70
	var vbox := VBoxContainer.new()
	title_panel.add_child(vbox)
	var title := Label.new()
	title.text = "galsystem\nADV Core Vertical Slice"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	vbox.add_child(title)
	vbox.add_child(_menu_button("Start .galscript", func() -> void: _start_new_game()))
	vbox.add_child(_menu_button("Start Dialogue Manager", func() -> void: _start_dialogue_manager_sample()))
	vbox.add_child(_menu_button("Continue Slot 1", func() -> void: _load_slot(1)))
	vbox.add_child(_menu_button("System", func() -> void: _toggle_system_menu(true)))
	vbox.add_child(_menu_button("Debug", func() -> void: _toggle_debug_panel()))
	add_child(title_panel)

func _menu_button(label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.pressed.connect(callback)
	return button

func _show_title() -> void:
	_game_started = false
	title_panel.visible = true
	dialogue_panel.visible = false
	choice_box.visible = false
	phone_overlay.visible = false
	_clear_characters()
	background_label.text = "galsystem title"
	speaker_label.text = ""
	_current_full_text = ""
	text_label.text = ""
	_set_status("Title flow ready — Start begins the vertical slice")

func _start_new_game() -> void:
	_dialogue_backend = "galscript"
	VNState.reset()
	_close_overlays()
	title_panel.visible = false
	dialogue_panel.visible = true
	_game_started = true
	ScenarioRunner.start(START_SCRIPT, "start")

func _start_dialogue_manager_sample() -> void:
	_dialogue_backend = "dialogue_manager"
	VNState.reset()
	_close_overlays()
	title_panel.visible = false
	dialogue_panel.visible = true
	_game_started = true
	FlowchartSystem.visit_label("dm:start")
	var line := await DialogueManagerAdapter.start(DM_MAIN_SCRIPT, "start")
	_present_dialogue_manager_line(line)

func _advance_dialogue_manager() -> void:
	var line := await DialogueManagerAdapter.get_next_line()
	_present_dialogue_manager_line(line)

func _choose_dialogue_manager_response(index: int) -> void:
	choice_box.visible = false
	var line := await DialogueManagerAdapter.choose_response(index)
	_present_dialogue_manager_line(line)

func _present_dialogue_manager_line(line: Dictionary, record_history: bool = true) -> void:
	if line.is_empty():
		_on_scenario_finished()
		return
	var flow_label := "dm:%s" % str(line.get("id", ""))
	if record_history:
		FlowchartSystem.visit_label(flow_label)
	var speaker := str(line.get("speaker", ""))
	var text := str(line.get("text", ""))
	if record_history:
		VNState.add_backlog(speaker, text)
	_on_line_presented(speaker, text)
	var responses: Array = line.get("responses", [])
	if not responses.is_empty():
		_finish_typewriter()
		for child in choice_box.get_children():
			child.queue_free()
		if record_history:
			FlowchartSystem.record_choice(flow_label, responses)
		for i in range(responses.size()):
			var response_index := i
			var button := Button.new()
			button.text = str(responses[i].get("text", "Response %d" % i))
			button.pressed.connect(func() -> void:
				_choose_dialogue_manager_response(response_index)
			)
			choice_box.add_child(button)
		choice_box.visible = true

func _refresh_dialogue_manager_display() -> void:
	var line := DialogueManagerAdapter.get_current_display()
	if line.is_empty():
		_on_scenario_finished()
	else:
		_present_dialogue_manager_line(line, false)

func _update_typewriter(delta: float) -> void:
	if not _typing:
		return
	_type_accumulator += delta * _type_chars_per_second
	var visible_count := mini(_current_full_text.length(), int(_type_accumulator))
	text_label.visible_characters = visible_count
	if visible_count >= _current_full_text.length():
		_finish_typewriter()

func _update_auto_skip(delta: float) -> void:
	if not _game_started or _menu_open or backlog_panel.visible or save_load_panel.visible or debug_panel.visible or flow_panel.visible or choice_box.visible:
		return
	if _typing:
		if _skip_mode:
			_finish_typewriter()
		return
	if _skip_mode:
		ScenarioRunner.next()
		return
	if _auto_mode:
		_auto_wait -= delta
		if _auto_wait <= 0.0:
			ScenarioRunner.next()

func _on_line_presented(speaker: String, text: String) -> void:
	choice_box.visible = false
	speaker_label.text = speaker
	_current_full_text = text
	text_label.text = text
	text_label.visible_characters = 0
	_type_accumulator = 0.0
	_typing = not _skip_mode and text.length() > 0
	if not _typing:
		_finish_typewriter()
	_auto_wait = clampf(float(text.length()) / 14.0, 1.2, 4.5)
	_set_status(_last_status_message)

func _finish_typewriter() -> void:
	_typing = false
	_type_accumulator = float(_current_full_text.length())
	text_label.visible_characters = -1

func _on_choices_presented(choices: Array[Dictionary]) -> void:
	_finish_typewriter()
	for child in choice_box.get_children():
		child.queue_free()
	for i in range(choices.size()):
		var choice_index := i
		var button := Button.new()
		button.text = str(choices[i].get("text", "Choice %d" % i))
		button.pressed.connect(func() -> void:
			choice_box.visible = false
			ScenarioRunner.choose(choice_index)
		)
		choice_box.add_child(button)
	choice_box.visible = true

func _on_command_requested(command: String, args: Array) -> void:
	match command:
		"bg":
			_set_background(str(args[0]) if args.size() > 0 else "none")
		"show":
			_show_character(args)
		"hide":
			_hide_character(str(args[0]) if args.size() > 0 else "center")
		"clear_chars":
			_clear_characters()
		"phone":
			_handle_phone(args)
		"mail":
			_show_mail(args)
		"read_mail":
			if args.size() > 0:
				PhoneSystem.mark_read(str(args[0]))
				_set_status("Mail read: %s" % args[0])
		"reply_mail":
			if args.size() >= 2:
				PhoneSystem.reply_mail(str(args[0]), str(args[1]))
				_set_status("Mail reply: %s -> %s" % [args[0], args[1]])
		"schedule_event":
			_schedule_event(args)
		"advance_day":
			var delta := int(args[0]) if args.size() > 0 else 1
			CalendarSystem.advance_day(delta)
			_set_status("Day advanced by %d" % delta)
		"music", "bgm":
			_set_status("BGM: %s" % (str(args[0]) if args.size() > 0 else "stop"))
		"sfx":
			_set_status("SFX: %s" % (str(args[0]) if args.size() > 0 else "none"))
		"cg":
			if args.size() > 0:
				VNState.unlock_cg(str(args[0]))
				_set_status("CG unlocked: %s" % args[0])
		"tip":
			if args.size() > 0:
				VNState.unlock_tip(str(args[0]))
				_set_status("TIP unlocked: %s" % args[0])
		_:
			_set_status("command: %s %s" % [command, " ".join(args)])

func _on_scenario_finished() -> void:
	_finish_typewriter()
	speaker_label.text = "System"
	_current_full_text = "Phase 1 vertical slice demo ended."
	text_label.text = _current_full_text
	text_label.visible_characters = -1

func _handle_phone(args: Array) -> void:
	if args.size() > 0 and str(args[0]) == "close":
		PhoneSystem.close()
		phone_overlay.visible = false
	else:
		var screen := str(args[0]) if args.size() > 0 else "inbox"
		PhoneSystem.open(screen)
		phone_overlay.visible = true

func _show_mail(args: Array) -> void:
	phone_overlay.visible = true
	var mail_id := str(args[0]) if args.size() > 0 else "mail_unknown"
	var sender := str(args[1]) if args.size() > 1 else "unknown"
	var subject := str(args[2]) if args.size() > 2 else "no_subject"
	var body := " ".join(args.slice(3))
	PhoneSystem.receive_mail(mail_id, sender, subject, body)
	phone_label.text = "PHONE / MAIL\n\nID: %s\nFrom: %s\nSubject: %s\n\n%s" % [mail_id, sender, subject, body]

func _schedule_event(args: Array) -> void:
	if args.size() < 2:
		push_warning("schedule_event requires id day [affection_character affection_min] [flags...]")
		return
	var event_id := str(args[0])
	var day := int(args[1])
	var affection_character := str(args[2]) if args.size() > 2 else ""
	var affection_min := int(args[3]) if args.size() > 3 else 0
	var required_flags: Array[String] = []
	for i in range(4, args.size()):
		required_flags.append(str(args[i]))
	CalendarSystem.schedule_event(event_id, day, required_flags, affection_character, affection_min)
	_set_status("Scheduled event: %s" % event_id)

func _set_background(bg_id: String) -> void:
	background_label.text = "bg: %s" % bg_id
	var hash_value: int = abs(hash(bg_id))
	background.color = Color.from_hsv(float(hash_value % 360) / 360.0, 0.35, 0.28)

func _show_character(args: Array) -> void:
	var character_id: String = str(args[0]) if args.size() > 0 else "character"
	var pose: String = str(args[1]) if args.size() > 1 else "neutral"
	var slot_name: String = str(args[2]) if args.size() > 2 else "center"
	if not character_slots.has(slot_name):
		slot_name = "center"
	var panel: PanelContainer = character_slots[slot_name]
	panel.visible = true
	var label: Label = panel.get_node("Label")
	label.text = "%s\n[%s]" % [character_id, pose]

func _hide_character(slot_name: String) -> void:
	if character_slots.has(slot_name):
		character_slots[slot_name].visible = false

func _clear_characters() -> void:
	for panel in character_slots.values():
		panel.visible = false

func _set_status(text: String) -> void:
	_last_status_message = text
	var modes := ""
	if _auto_mode:
		modes += " AUTO"
	if _skip_mode:
		modes += " SKIP"
	status_label.text = "%s%s    |    Day %d Route %s Worldline %s" % [text, modes, VNState.current_day, VNState.current_route, VNState.worldline]

func _toggle_auto_mode() -> void:
	_auto_mode = not _auto_mode
	if _auto_mode:
		_skip_mode = false
	_auto_wait = 0.8
	_set_status("Auto %s" % ("ON" if _auto_mode else "OFF"))

func _toggle_skip_mode() -> void:
	_skip_mode = not _skip_mode
	if _skip_mode:
		_auto_mode = false
	_set_status("Skip %s" % ("ON" if _skip_mode else "OFF"))

func _toggle_backlog() -> void:
	backlog_panel.visible = not backlog_panel.visible
	_menu_open = system_menu.visible
	if backlog_panel.visible:
		_refresh_backlog_panel()

func _refresh_backlog_panel() -> void:
	var lines: Array[String] = []
	for item in VNState.backlog:
		var speaker := str(item.get("speaker", ""))
		var text := str(item.get("text", ""))
		var prefix := "[color=gray]D%s %s[/color] " % [int(item.get("day", 0)), str(item.get("route", ""))]
		lines.append(prefix + (("[b]%s[/b]: %s" % [speaker, text]) if not speaker.is_empty() else text))
	backlog_text.text = "\n\n".join(lines)

func _toggle_system_menu(force_visible: Variant = null) -> void:
	if force_visible == null:
		system_menu.visible = not system_menu.visible
	else:
		system_menu.visible = bool(force_visible)
	_menu_open = system_menu.visible

func _open_save_load(mode: SaveLoadMode) -> void:
	_save_load_mode = mode
	save_load_panel.visible = true
	_refresh_save_load_panel()

func _refresh_save_load_panel() -> void:
	var title: Label = save_load_panel.get_node("VBoxContainer/Title")
	title.text = "保存" if _save_load_mode == SaveLoadMode.SAVE else "读取"
	for child in save_load_list.get_children():
		child.queue_free()
	for slot in range(1, SAVE_SLOT_COUNT + 1):
		var slot_id := slot
		var button := Button.new()
		var exists := SaveSystem.has_slot(slot_id)
		button.text = "Slot %d  %s" % [slot_id, "已有存档" if exists else "空"]
		button.disabled = _save_load_mode == SaveLoadMode.LOAD and not exists
		button.pressed.connect(func() -> void:
			if _save_load_mode == SaveLoadMode.SAVE:
				SaveSystem.save_slot(slot_id, _presentation_snapshot())
				_set_status("已保存到 Slot %d" % slot_id)
			else:
				_load_slot(slot_id)
			_refresh_save_load_panel()
		)
		save_load_list.add_child(button)

func _quick_save() -> void:
	if not _game_started:
		return
	SaveSystem.save_slot(1, _presentation_snapshot())
	_set_status("已快速保存到 Slot 1")

func _quick_load() -> void:
	_load_slot(1)

func _load_slot(slot_id: int) -> void:
	var payload := SaveSystem.load_slot(slot_id)
	if payload.is_empty():
		_set_status("Slot %d 无法读取" % slot_id)
		return
	title_panel.visible = false
	dialogue_panel.visible = true
	_game_started = true
	_restore_presentation(payload.get("presentation", {}))
	if _dialogue_backend == "dialogue_manager":
		_refresh_dialogue_manager_display()
	else:
		ScenarioRunner.refresh_display()
	_set_status("已读取 Slot %d" % slot_id)

func _toggle_debug_panel() -> void:
	debug_panel.visible = not debug_panel.visible
	if debug_panel.visible:
		_refresh_debug_panel()

func _toggle_flow_panel() -> void:
	flow_panel.visible = not flow_panel.visible
	if flow_panel.visible:
		_refresh_flow_panel()

func _refresh_debug_panel() -> void:
	var checkpoint := ScenarioRunner.get_checkpoint()
	var current := ScenarioRunner.get_current_line()
	debug_text.text = """
[b]Debug[/b]
script: %s
index: %s
label: %s
chapter: %s day: %d route: %s worldline: %s
waiting_choice: %s finished: %s
current: %s | %s
phone: %s mails / %s replies
calendar_events: %s

[b]Flags[/b]
%s

[b]Affection[/b]
%s

[b]Variables[/b]
%s
""" % [
		str(checkpoint.get("path", "")),
		str(checkpoint.get("index", "")),
		FlowchartSystem.current_label,
		VNState.current_chapter,
		VNState.current_day,
		VNState.current_route,
		VNState.worldline,
		str(ScenarioRunner.is_waiting_for_choice()),
		str(ScenarioRunner.is_finished()),
		str(current.get("speaker", "")),
		str(current.get("text", "")),
		str(PhoneSystem.inbox.size()),
		str(PhoneSystem.replies.size()),
		JSON.stringify(CalendarSystem.triggered_events),
		JSON.stringify(VNState.flags, "  "),
		JSON.stringify(VNState.affection, "  "),
		JSON.stringify(VNState.variables, "  "),
	]

func _refresh_flow_panel() -> void:
	flow_text.text = """
[b]Flow Debug[/b]
current_label: %s
visited_labels:
%s

choices:
%s
""" % [
		FlowchartSystem.current_label,
		"\n".join(FlowchartSystem.visited_labels),
		JSON.stringify(FlowchartSystem.choice_history, "  "),
	]

func _close_overlays() -> void:
	backlog_panel.visible = false
	save_load_panel.visible = false
	debug_panel.visible = false
	flow_panel.visible = false
	system_menu.visible = false
	_menu_open = false

func _presentation_snapshot() -> Dictionary:
	var chars := {}
	for slot_name in character_slots.keys():
		var panel: PanelContainer = character_slots[slot_name]
		chars[slot_name] = {"visible": panel.visible, "text": panel.get_node("Label").text}
	return {
		"background_text": background_label.text,
		"background_color": background.color.to_html(),
		"characters": chars,
		"phone_visible": phone_overlay.visible,
		"phone_text": phone_label.text,
		"speaker": speaker_label.text,
		"text": _current_full_text,
		"game_started": _game_started,
		"dialogue_backend": _dialogue_backend,
		"dialogue_manager": DialogueManagerAdapter.snapshot() if has_node("/root/DialogueManagerAdapter") else {},
	}

func _restore_presentation(data: Dictionary) -> void:
	background_label.text = str(data.get("background_text", "bg: restored"))
	background.color = Color(data.get("background_color", "1d2638"))
	var chars: Dictionary = data.get("characters", {})
	for slot_name in chars.keys():
		if character_slots.has(slot_name):
			var panel: PanelContainer = character_slots[slot_name]
			panel.visible = bool(chars[slot_name].get("visible", false))
			panel.get_node("Label").text = str(chars[slot_name].get("text", ""))
	phone_overlay.visible = bool(data.get("phone_visible", false))
	phone_label.text = str(data.get("phone_text", phone_label.text))
	speaker_label.text = str(data.get("speaker", ""))
	_current_full_text = str(data.get("text", ""))
	_game_started = bool(data.get("game_started", true))
	_dialogue_backend = str(data.get("dialogue_backend", "galscript"))
	if has_node("/root/DialogueManagerAdapter"):
		DialogueManagerAdapter.restore(data.get("dialogue_manager", {}))
	text_label.text = _current_full_text
	_finish_typewriter()

func _run_invalid_save_qa() -> void:
	DirAccess.make_dir_recursive_absolute("user://saves")
	var path := "user://saves/slot_099.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({"save_version": -1, "vn_state": {}, "scenario": {}, "presentation": {}}))
	file.close()
	var payload := SaveSystem.load_slot(99)
	assert(payload.is_empty())
	print("qa: invalid save payload rejected")
	get_tree().quit(0)

func _run_dialogue_manager_smoke() -> void:
	assert(title_panel.visible)
	await _smoke_dialogue_manager_branch(0, "phone")
	await _smoke_dialogue_manager_branch(1, "calendar")
	DialogueManagerAdapter.reset()
	print("dialogue manager smoke ok")
	get_tree().quit(0)

func _smoke_dialogue_manager_branch(choice_index: int, branch_name: String) -> void:
	await _start_dialogue_manager_sample()
	assert(_dialogue_backend == "dialogue_manager")
	assert(_current_full_text.contains("Chapter 01"))
	assert(background_label.text == "bg: dm_winter_school_gate")
	assert(choice_box.visible == false)
	await _advance_dialogue_manager_until_choice(16)
	assert(choice_box.visible)
	var before_save := _dm_critical_snapshot()
	assert(SaveSystem.save_slot(2, _presentation_snapshot()))
	var payload := SaveSystem.load_slot(2)
	assert(not payload.is_empty())
	_restore_presentation(payload.get("presentation", {}))
	_refresh_dialogue_manager_display()
	var after_load := _dm_critical_snapshot()
	assert(before_save.get("text") == after_load.get("text"))
	assert(before_save.get("choice_visible") == after_load.get("choice_visible"))
	assert(before_save.get("response_count") == after_load.get("response_count"))
	assert(after_load.get("backend") == "dialogue_manager")
	await _choose_dialogue_manager_response(choice_index)
	if branch_name == "phone":
		assert(VNState.get_flag("mail_received_dm_sg001"))
		assert(VNState.get_flag("mail_read_dm_sg001"))
		assert(VNState.get_flag("mail_reply_dm_sg001"))
		assert(VNState.get_flag("dm_phone_branch_observed"))
		assert(VNState.worldline == "1.048596")
		assert(VNState.unlocked_tips.has("dm_worldline_tips"))
		assert(VNState.unlocked_cg.has("dm_phone_trigger"))
		assert(_current_full_text.contains("命运石之门"))
	else:
		assert(VNState.get_flag("dm_visited_music_room"))
		assert(VNState.get_flag("dm_calendar_branch_observed"))
		assert(VNState.current_route == "kazusa")
		assert(VNState.current_day >= 2)
		assert(VNState.get_affection("kazusa") >= 3)
		assert(background_label.text == "bg: dm_music_room")
		assert(_current_full_text.contains("白色相簿"))
	await _advance_dialogue_manager()
	assert(_current_full_text == "Phase 1 vertical slice demo ended.")

func _run_smoke_test() -> void:
	assert(title_panel.visible)
	print("smoke: title flow visible")
	_smoke_branch(0, "phone")
	_smoke_branch(1, "calendar")
	print("galsystem smoke ok")
	get_tree().quit(0)

func _smoke_branch(choice_index: int, branch_name: String) -> void:
	_start_new_game()
	_advance_until_choice(32)
	assert(ScenarioRunner.is_waiting_for_choice())
	var before := _critical_snapshot()
	SaveSystem.save_slot(1, _presentation_snapshot())
	var payload := SaveSystem.load_slot(1)
	assert(not payload.is_empty())
	_restore_presentation(payload.get("presentation", {}))
	ScenarioRunner.refresh_display()
	assert(str(ScenarioRunner.get_checkpoint().get("path", "")) == START_SCRIPT)
	assert(SaveSystem.save_slot(1, _presentation_snapshot()))
	var payload_second := SaveSystem.load_slot(1)
	assert(not payload_second.is_empty())
	_restore_presentation(payload_second.get("presentation", {}))
	ScenarioRunner.refresh_display()
	assert(str(ScenarioRunner.get_checkpoint().get("path", "")) == START_SCRIPT)
	var after := _critical_snapshot()
	assert(before.get("speaker") == after.get("speaker"))
	assert(before.get("text") == after.get("text"))
	assert(before.get("waiting_choice") == after.get("waiting_choice"))
	assert(before.get("day") == after.get("day"))
	assert(before.get("worldline") == after.get("worldline"))
	ScenarioRunner.choose(choice_index)
	_advance_until_finished(96)
	if branch_name == "phone":
		assert(VNState.get_flag("mail_received_sg001"))
		assert(VNState.get_flag("mail_read_sg001"))
		assert(VNState.get_flag("mail_reply_sg001"))
		assert(VNState.get_flag("answered_phone"))
		assert(VNState.get_flag("sg_branch_observed"))
		assert(VNState.unlocked_tips.has("worldline_tips"))
		assert(VNState.unlocked_cg.has("first_phone_trigger"))
		assert(VNState.worldline == "1.048596")
		print("smoke: phone branch mail->read->reply->worldline/tips/cg ok")
	else:
		assert(VNState.get_flag("visited_music_room"))
		assert(VNState.get_flag("calendar_event_music_rehearsal"))
		assert(VNState.get_flag("white_album_branch_observed"))
		assert(VNState.current_route == "kazusa")
		assert(VNState.current_day >= 2)
		assert(VNState.get_affection("kazusa") >= 3)
		print("smoke: calendar/affection branch route lock ok")
	assert(FlowchartSystem.visited_labels.size() > 0)
	assert(FlowchartSystem.choice_history.size() > 0)

func _advance_until_choice(max_steps: int) -> void:
	for step in range(max_steps):
		if ScenarioRunner.is_waiting_for_choice() or ScenarioRunner.is_finished():
			return
		ScenarioRunner.next()

func _advance_dialogue_manager_until_choice(max_steps: int) -> void:
	for step in range(max_steps):
		if choice_box.visible:
			return
		await _advance_dialogue_manager()
	assert(choice_box.visible)

func _advance_until_finished(max_steps: int) -> void:
	for step in range(max_steps):
		if ScenarioRunner.is_finished():
			return
		if ScenarioRunner.is_waiting_for_choice():
			ScenarioRunner.choose(0)
		else:
			ScenarioRunner.next()
	assert(ScenarioRunner.is_finished())

func _critical_snapshot() -> Dictionary:
	var line := ScenarioRunner.get_current_line()
	return {
		"speaker": str(line.get("speaker", "")),
		"text": str(line.get("text", "")),
		"waiting_choice": ScenarioRunner.is_waiting_for_choice(),
		"day": VNState.current_day,
		"route": VNState.current_route,
		"worldline": VNState.worldline,
		"flags": VNState.flags.duplicate(true),
		"affection": VNState.affection.duplicate(true),
		"phone_inbox": PhoneSystem.inbox.duplicate(true),
	}

func _dm_critical_snapshot() -> Dictionary:
	var line := DialogueManagerAdapter.get_current_display()
	var responses: Array = line.get("responses", [])
	return {
		"backend": _dialogue_backend,
		"speaker": speaker_label.text,
		"text": _current_full_text,
		"choice_visible": choice_box.visible,
		"response_count": responses.size(),
		"resource_path": str(DialogueManagerAdapter.snapshot().get("resource_path", "")),
		"background": background_label.text,
		"day": VNState.current_day,
		"route": VNState.current_route,
		"worldline": VNState.worldline,
	}
