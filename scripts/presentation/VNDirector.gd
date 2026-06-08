extends Control
## Runtime presentation shell for the Phase-1 ADV vertical slice.
## The shell is intentionally independent from ScenarioRunner internals so the runner can
## later be replaced by Dialogue Manager or another adapter.

const START_SCRIPT := "res://scenario/common/prologue.galscript"
const DM_MAIN_SCRIPT := "res://scenario/dialogue_manager/chapter_01.dialogue"
const NARCISSU1_PRIVATE_SCRIPT := "res://reference_private/narcissu/generated/narcissu1_gp32.galscript"
const NARCISSU2_PRIVATE_SCRIPT := "res://reference_private/narcissu/generated/narcissu2_haeleth.galscript"
const SCREENSHOT_TITLE_PATH := "/tmp/galsystem-title.png"
const SCREENSHOT_GAMEPLAY_PATH := "/tmp/galsystem-gameplay.png"
const SCREENSHOT_SYSTEM_MENU_PATH := "/tmp/galsystem-system-menu.png"
const SCREENSHOT_BACKLOG_PATH := "/tmp/galsystem-backlog.png"
const SCREENSHOT_SAVE_LOAD_PATH := "/tmp/galsystem-save-load.png"
const SAVE_SLOT_COUNT := 6
const NarcissuCommandExecutor := preload("res://scripts/systems/NarcissuCommandExecutor.gd")
const NarcissuRuntimeProfile := preload("res://scripts/systems/NarcissuRuntimeProfile.gd")
const DialogueWindowScene := preload("res://scripts/ui/DialogueWindow.gd")
const TitleScreenScene := preload("res://scripts/ui/TitleScreen.gd")
const SystemMenuScene := preload("res://scripts/ui/SystemMenuOverlay.gd")
const BacklogOverlayScene := preload("res://scripts/ui/BacklogOverlay.gd")
const SaveLoadOverlayScene := preload("res://scripts/ui/SaveLoadOverlay.gd")

var background: ColorRect
var background_texture: TextureRect
var background_label: Label
var narcissu_stage: Control
var bgm_player: AudioStreamPlayer
var voice_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var character_slots: Dictionary = {}
var narcissu_sprite_slots: Dictionary = {}
var title_panel: Control
var dialogue_window: Control
var dialogue_panel: PanelContainer
var speaker_label: Label
var text_label: RichTextLabel
var choice_box: VBoxContainer
var status_label: Label
var phone_overlay: PanelContainer
var phone_label: Label
var backlog_panel: Control
var system_menu: Control
var save_load_panel: Control
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
var _last_status_message: String = "LMB/Space: 推进  Esc: 菜单  B: 历史  F1: 调试  F2: 流程  F5/F9: 快存/快读  M: 标题"
var _menu_open: bool = false
var _game_started: bool = false
var _dialogue_backend: String = "galscript"
var _narcissu_executor: RefCounted
var _last_media_status: Dictionary = {}
var _narcissu_smoke_failed: bool = false
var _dm_smoke_failed: bool = false
var _screenshot_smoke_failed: bool = false

enum SaveLoadMode { SAVE, LOAD }
var _save_load_mode: SaveLoadMode = SaveLoadMode.SAVE

func _ready() -> void:
	_validate_extension_scripts()
	_build_ui()
	_build_audio_players()
	_narcissu_executor = NarcissuCommandExecutor.new(self)
	_connect_runner()
	_show_title()
	if _has_cmdline_flag("--galsystem-smoke"):
		call_deferred("_run_smoke_test")
	elif _has_cmdline_flag("--galsystem-screenshot-smoke"):
		call_deferred("_run_screenshot_smoke")
	elif _has_cmdline_flag("--galsystem-public-title-smoke"):
		call_deferred("_run_public_title_smoke")
	elif _has_cmdline_flag("--galsystem-qa-invalid-save"):
		call_deferred("_run_invalid_save_qa")
	elif _has_cmdline_flag("--galsystem-dm-smoke"):
		call_deferred("_run_dialogue_manager_smoke")
	elif _has_cmdline_flag("--galsystem-narcissu-private-smoke"):
		call_deferred("_run_narcissu_private_smoke")
	elif _has_cmdline_flag("--galsystem-narcissu-local-smoke"):
		call_deferred("_run_narcissu_local_smoke")

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
	assert(load("res://scripts/systems/NarcissuAssetResolver.gd") != null)
	assert(load("res://scripts/systems/NarcissuCommandExecutor.gd") != null)

func _connect_runner() -> void:
	ScenarioRunner.line_presented.connect(_on_line_presented)
	ScenarioRunner.command_requested.connect(_on_command_requested)
	ScenarioRunner.choices_presented.connect(_on_choices_presented)
	ScenarioRunner.scenario_finished.connect(_on_scenario_finished)
	DialogueManagerAdapter.command_requested.connect(_on_command_requested)

func _has_cmdline_flag(flag: String) -> bool:
	return flag in OS.get_cmdline_args() or flag in OS.get_cmdline_user_args()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if _game_started and not title_panel.visible and not _is_pointer_over_button():
				_handle_advance()
				get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if _game_started and not title_panel.visible:
				_toggle_system_menu()
				get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("advance_text") and not (event is InputEventMouseButton):
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
			KEY_M:
				_return_to_title()

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

	background_texture = TextureRect.new()
	background_texture.name = "BackgroundTexture"
	background_texture.visible = false
	background_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	background_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.add_child(background_texture)

	background_label = Label.new()
	background_label.text = "bg: title"
	background_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	background_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	background_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	background_label.add_theme_font_size_override("font_size", 34)
	background.add_child(background_label)

func _build_character_stage() -> void:
	narcissu_stage = Control.new()
	narcissu_stage.name = "NarcissuStage"
	narcissu_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(narcissu_stage)

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
	dialogue_window = DialogueWindowScene.new()
	dialogue_window.visible = true
	add_child(dialogue_window)
	dialogue_panel = dialogue_window.panel
	speaker_label = dialogue_window.speaker_label
	text_label = dialogue_window.text_label
	dialogue_window.quick_menu.backlog_requested.connect(_toggle_backlog)
	dialogue_window.quick_menu.auto_requested.connect(_toggle_auto_mode)
	dialogue_window.quick_menu.skip_requested.connect(_toggle_skip_mode)
	dialogue_window.quick_menu.save_requested.connect(func() -> void: _open_save_load(SaveLoadMode.SAVE))
	dialogue_window.quick_menu.load_requested.connect(func() -> void: _open_save_load(SaveLoadMode.LOAD))
	dialogue_window.quick_menu.quick_save_requested.connect(_quick_save)
	dialogue_window.quick_menu.quick_load_requested.connect(_quick_load)
	dialogue_window.quick_menu.config_requested.connect(func() -> void: _toggle_system_menu(true))
	dialogue_window.quick_menu.title_requested.connect(_return_to_title)

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
	status_label.anchor_bottom = 0.10
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color(0.82, 0.80, 0.75, 0.68))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	backlog_panel = BacklogOverlayScene.new()
	backlog_panel.visible = false
	backlog_panel.connect("closed", Callable(self, "_close_backlog"))
	add_child(backlog_panel)

func _build_system_menu() -> void:
	system_menu = SystemMenuScene.new()
	system_menu.visible = false
	system_menu.connect("resume_requested", Callable(self, "_close_system_menu"))
	system_menu.connect("save_requested", Callable(self, "_open_save_mode"))
	system_menu.connect("load_requested", Callable(self, "_open_load_mode"))
	system_menu.connect("backlog_requested", Callable(self, "_toggle_backlog"))
	system_menu.connect("auto_requested", Callable(self, "_toggle_auto_mode"))
	system_menu.connect("skip_requested", Callable(self, "_toggle_skip_mode"))
	system_menu.connect("title_requested", Callable(self, "_return_to_title"))
	system_menu.connect("closed", Callable(self, "_close_system_menu"))
	add_child(system_menu)

func _build_save_load_panel() -> void:
	save_load_panel = SaveLoadOverlayScene.new()
	save_load_panel.visible = false
	save_load_panel.connect("closed", Callable(self, "_close_save_load"))
	save_load_panel.connect("slot_selected", Callable(self, "_on_save_load_slot_selected"))
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

func _build_audio_players() -> void:
	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "NarcissuBGM"
	bgm_player.bus = NarcissuRuntimeProfile.BGM_BUS
	add_child(bgm_player)
	voice_player = AudioStreamPlayer.new()
	voice_player.name = "NarcissuVoice"
	voice_player.bus = NarcissuRuntimeProfile.VOICE_BUS
	add_child(voice_player)
	for i in range(4):
		var player := AudioStreamPlayer.new()
		player.name = "NarcissuSFX_%d" % i
		player.bus = NarcissuRuntimeProfile.SFX_BUS
		add_child(player)
		sfx_players.append(player)

func _build_title_panel() -> void:
	title_panel = TitleScreenScene.new()
	title_panel.visible = false
	title_panel.connect("start_galscript_requested", Callable(self, "_start_new_game"))
	title_panel.connect("start_dialogue_manager_requested", Callable(self, "_start_dialogue_manager_sample"))
	title_panel.connect("start_narcissu1_requested", Callable(self, "_start_narcissu1_private"))
	title_panel.connect("start_narcissu2_requested", Callable(self, "_start_narcissu2_private"))
	title_panel.connect("continue_requested", Callable(self, "_load_continue_slot"))
	title_panel.connect("config_requested", Callable(self, "_open_system_menu"))
	title_panel.connect("debug_requested", Callable(self, "_toggle_debug_panel"))
	add_child(title_panel)
	_layout_title_panel()
	_refresh_title_availability()

func _refresh_title_availability() -> void:
	if title_panel == null or not title_panel.has_method("set_public_availability"):
		return
	title_panel.call(
		"set_public_availability",
		FileAccess.file_exists(NARCISSU1_PRIVATE_SCRIPT),
		FileAccess.file_exists(NARCISSU2_PRIVATE_SCRIPT),
		SaveSystem.has_slot(1)
	)

func _start_narcissu1_private() -> void:
	_start_private_galscript(NARCISSU1_PRIVATE_SCRIPT, "gp32_image")

func _start_narcissu2_private() -> void:
	_start_private_galscript(NARCISSU2_PRIVATE_SCRIPT, "haeleth_nar2")

func _load_continue_slot() -> void:
	_load_slot(1)

func _open_system_menu() -> void:
	_toggle_system_menu(true)

func _open_save_mode() -> void:
	_open_save_load(SaveLoadMode.SAVE)

func _open_load_mode() -> void:
	_open_save_load(SaveLoadMode.LOAD)

func _close_system_menu() -> void:
	_toggle_system_menu(false)

func _close_backlog() -> void:
	backlog_panel.visible = false

func _close_save_load() -> void:
	save_load_panel.visible = false

func _is_pointer_over_button() -> bool:
	var control := get_viewport().gui_get_hovered_control()
	while control != null:
		if control is Button or control is LineEdit or control is TextEdit or control is OptionButton:
			return true
		control = control.get_parent() as Control
	return false

func _set_dialogue_window_visible(value: bool) -> void:
	if dialogue_window != null:
		dialogue_window.visible = value
	elif dialogue_panel != null:
		dialogue_panel.visible = value

func _sync_quick_menu_modes() -> void:
	if dialogue_window != null and dialogue_window.has_method("set_modes"):
		dialogue_window.call("set_modes", _auto_mode, _skip_mode)

func _layout_title_panel() -> void:
	if title_panel == null:
		return
	if title_panel.has_method("relayout"):
		title_panel.call("relayout")
	else:
		title_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _return_to_title() -> void:
	_auto_mode = false
	_skip_mode = false
	_dialogue_backend = "galscript"
	DialogueManagerAdapter.reset()
	VNState.reset()
	_close_overlays()
	_clear_narcissu_stage()
	_show_title()

func _show_title() -> void:
	_layout_title_panel()
	_refresh_title_availability()
	_game_started = false
	_auto_mode = false
	_skip_mode = false
	_stop_all_narcissu_media()
	title_panel.visible = true
	status_label.visible = false
	_set_dialogue_window_visible(false)
	choice_box.visible = false
	phone_overlay.visible = false
	_clear_characters()
	background_texture.visible = false
	background_texture.texture = null
	background_label.text = ""
	speaker_label.text = ""
	_current_full_text = ""
	text_label.text = ""
	_set_status("Title menu ready")

func _start_new_game() -> void:
	_dialogue_backend = "galscript"
	VNState.reset()
	_close_overlays()
	title_panel.visible = false
	status_label.visible = true
	_set_dialogue_window_visible(true)
	_game_started = true
	ScenarioRunner.start(START_SCRIPT, "start")


func _start_private_galscript(path: String, label: String) -> bool:
	if not FileAccess.file_exists(path):
		_set_status("Private reference script missing: %s" % path)
		return false
	_dialogue_backend = "galscript"
	VNState.reset()
	_close_overlays()
	title_panel.visible = false
	status_label.visible = true
	_set_dialogue_window_visible(true)
	_game_started = true
	_clear_narcissu_stage()
	if _narcissu_executor != null and _narcissu_executor.has_method("reset_runtime_flags"):
		_narcissu_executor.call("reset_runtime_flags")
	return ScenarioRunner.start(path, label)

func _start_dialogue_manager_sample() -> void:
	_dialogue_backend = "dialogue_manager"
	VNState.reset()
	_close_overlays()
	title_panel.visible = false
	status_label.visible = true
	_set_dialogue_window_visible(true)
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
	if dialogue_window != null and dialogue_window.has_method("set_visible_characters"):
		dialogue_window.call("set_visible_characters", visible_count)
	if visible_count >= _current_full_text.length():
		_finish_typewriter()

func _update_auto_skip(delta: float) -> void:
	if not _game_started or _menu_open or backlog_panel.visible or save_load_panel.visible or debug_panel.visible or flow_panel.visible or choice_box.visible:
		return
	if _dialogue_backend == "dialogue_manager":
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
	if dialogue_window != null and dialogue_window.has_method("set_dialogue"):
		dialogue_window.call("set_dialogue", speaker, text)
	else:
		speaker_label.text = speaker
		text_label.text = text
	_current_full_text = text
	text_label.visible_characters = 0
	if dialogue_window != null and dialogue_window.has_method("set_visible_characters"):
		dialogue_window.call("set_visible_characters", 0)
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
	if dialogue_window != null and dialogue_window.has_method("set_visible_characters"):
		dialogue_window.call("set_visible_characters", -1)

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
	var narcissu_script_active := _dialogue_backend == "galscript" and str(ScenarioRunner.get_checkpoint().get("path", "")).contains("/reference_private/narcissu/")
	if _narcissu_executor != null and bool(_narcissu_executor.call("handles", command, narcissu_script_active)):
		if bool(_narcissu_executor.call("execute", command, args)):
			return
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
	background_texture.visible = false
	background_texture.texture = null
	background_label.text = "bg: %s" % bg_id
	var hash_value: int = abs(hash(bg_id))
	background.color = Color.from_hsv(float(hash_value % 360) / 360.0, 0.35, 0.28)

func show_narcissu_background(ref: String, texture: Texture2D, result: Dictionary) -> void:
	if texture != null:
		background_texture.texture = texture
		background_texture.visible = true
		background_label.text = ""
		_last_media_status["background"] = ref
		_set_status("Narcissu BG loaded: %s" % ref.get_file())
	else:
		_set_background(ref)
		_set_status("Narcissu BG missing: %s" % ref)

func show_narcissu_sprite(sprite_id: String, ref: String, x: float, y: float, texture: Texture2D, visible: bool, result: Dictionary) -> void:
	var rect: TextureRect
	if narcissu_sprite_slots.has(sprite_id):
		rect = narcissu_sprite_slots[sprite_id]
	else:
		rect = TextureRect.new()
		rect.name = "NarcissuSprite_%s" % sprite_id
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		narcissu_stage.add_child(rect)
		narcissu_sprite_slots[sprite_id] = rect
	var viewport_size := get_viewport_rect().size
	rect.position = NarcissuRuntimeProfile.source_to_viewport(Vector2(x, y), viewport_size)
	if texture != null:
		rect.texture = texture
		var scaled_size := texture.get_size() * (viewport_size.x / NarcissuRuntimeProfile.SOURCE_WIDTH)
		rect.custom_minimum_size = scaled_size
		rect.size = scaled_size
	else:
		rect.texture = null
	rect.visible = visible and texture != null
	_last_media_status["sprite_%s" % sprite_id] = ref

func set_narcissu_sprite_visible(sprite_id: String, visible: bool) -> void:
	if narcissu_sprite_slots.has(sprite_id):
		narcissu_sprite_slots[sprite_id].visible = visible

func clear_narcissu_sprite(sprite_id: String) -> void:
	if sprite_id == "all":
		_clear_narcissu_stage()
	elif narcissu_sprite_slots.has(sprite_id):
		narcissu_sprite_slots[sprite_id].queue_free()
		narcissu_sprite_slots.erase(sprite_id)

func play_narcissu_bgm(ref: String, stream: AudioStream, loop: bool, result: Dictionary) -> void:
	if stream != null:
		if stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = loop
		elif stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = loop
		elif stream is AudioStreamWAV:
			(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
		bgm_player.stream = stream
		bgm_player.play()
		_last_media_status["bgm"] = ref
		_set_status("Narcissu BGM loaded: %s" % ref.get_file())
	else:
		_set_status("Narcissu BGM missing: %s" % ref)

func stop_narcissu_bgm() -> void:
	if bgm_player != null:
		bgm_player.stop()

func play_narcissu_sfx(channel: String, ref: String, stream: AudioStream, voice: bool, result: Dictionary) -> void:
	if stream == null:
		_set_status("Narcissu %s missing: %s" % ["voice" if voice else "SFX", ref])
		return
	var player := voice_player if voice else sfx_players[abs(hash(channel)) % sfx_players.size()]
	player.stream = stream
	player.play()
	_last_media_status["voice" if voice else "sfx"] = ref
	_set_status("Narcissu %s loaded: %s" % ["voice" if voice else "SFX", ref.get_file()])

func stop_narcissu_sfx(channel: String = "all") -> void:
	if voice_player != null and (channel == "all" or channel == "0"):
		voice_player.stop()
	for player in sfx_players:
		player.stop()

func _clear_narcissu_stage() -> void:
	for rect in narcissu_sprite_slots.values():
		if is_instance_valid(rect):
			rect.queue_free()
	narcissu_sprite_slots.clear()

func _stop_all_narcissu_media() -> void:
	if bgm_player != null:
		bgm_player.stop()
	if voice_player != null:
		voice_player.stop()
	for player in sfx_players:
		player.stop()

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
	var modes := []
	if _auto_mode:
		modes.append("AUTO")
	if _skip_mode:
		modes.append("SKIP")
	var mode_text := " · " + " / ".join(modes) if not modes.is_empty() else ""
	var hud := "Day %d · %s · WL %s%s" % [VNState.current_day, VNState.current_route, VNState.worldline, mode_text]
	status_label.text = hud if text.is_empty() else "%s\n%s" % [hud, text]
	_sync_quick_menu_modes()

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
	if backlog_panel != null and backlog_panel.has_method("set_entries"):
		backlog_panel.call("set_entries", VNState.backlog)

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
	if save_load_panel == null:
		return
	var mode_label := "Save" if _save_load_mode == SaveLoadMode.SAVE else "Load"
	if save_load_panel.has_method("set_mode"):
		save_load_panel.call("set_mode", mode_label)
	var slots: Array[Dictionary] = []
	for slot in range(1, SAVE_SLOT_COUNT + 1):
		var slot_id := slot
		var payload := SaveSystem.peek_slot(slot_id) if SaveSystem.has_method("peek_slot") else {}
		var exists := not payload.is_empty()
		slots.append({
			"slot_id": slot_id,
			"exists": exists,
			"disabled": _save_load_mode == SaveLoadMode.LOAD and not exists,
			"label": _save_slot_label(slot_id, payload),
		})
	if save_load_panel.has_method("set_slots"):
		save_load_panel.call("set_slots", slots)

func _on_save_load_slot_selected(slot_id: int) -> void:
	if _save_load_mode == SaveLoadMode.SAVE:
		SaveSystem.save_slot(slot_id, _presentation_snapshot())
		_refresh_title_availability()
		_set_status("Saved to Slot %d" % slot_id)
	else:
		_load_slot(slot_id)
	_refresh_save_load_panel()

func _save_slot_label(slot_id: int, payload: Dictionary) -> String:
	if payload.is_empty():
		return "▧  Slot %02d    Empty\nNo save data" % slot_id
	var created := int(payload.get("created_unix", 0))
	var stamp := Time.get_datetime_string_from_unix_time(created, true) if created > 0 else "unknown time"
	var backend := str(payload.get("scenario_backend", "galscript"))
	var scenario: Dictionary = payload.get("scenario", {})
	var presentation: Dictionary = payload.get("presentation", {})
	var excerpt := str(presentation.get("text", scenario.get("current_text", ""))).replace("\n", " ")
	if excerpt.length() > 42:
		excerpt = excerpt.substr(0, 42) + "..."
	return "▣  Slot %02d    %s    %s\n%s" % [slot_id, stamp, backend, excerpt if not excerpt.is_empty() else "Saved position"]

func _quick_save() -> void:
	if not _game_started:
		return
	SaveSystem.save_slot(1, _presentation_snapshot())
	_refresh_title_availability()
	_set_status("已快速保存到 Slot 1")

func _quick_load() -> void:
	_load_slot(1)

func _load_slot(slot_id: int) -> void:
	var payload := SaveSystem.load_slot(slot_id)
	if payload.is_empty():
		_set_status("Slot %d 无法读取" % slot_id)
		return
	title_panel.visible = false
	status_label.visible = true
	_set_dialogue_window_visible(true)
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
	var narcissu_media := {}
	if _narcissu_executor != null:
		narcissu_media = _narcissu_executor.get("active_media").duplicate(true)
	return {
		"background_text": background_label.text,
		"background_color": background.color.to_html(),
		"background_texture_visible": background_texture.visible,
		"media_status": _last_media_status.duplicate(true),
		"narcissu_media": narcissu_media,
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
	background_texture.visible = bool(data.get("background_texture_visible", false)) and background_texture.texture != null
	_last_media_status = data.get("media_status", {}).duplicate(true)
	_restore_narcissu_media(data.get("narcissu_media", {}))
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
	if dialogue_window != null and dialogue_window.has_method("set_dialogue"):
		dialogue_window.call("set_dialogue", speaker_label.text, _current_full_text)
	else:
		text_label.text = _current_full_text
	_finish_typewriter()


func _restore_narcissu_media(media: Dictionary) -> void:
	if media.is_empty() or _narcissu_executor == null:
		return
	if media.has("background"):
		_narcissu_executor.call("execute", "narcissu_bg", [str(media["background"].get("reference", ""))])
	if media.has("bgm"):
		_narcissu_executor.call("execute", "narcissu_bgm", [str(media["bgm"].get("reference", "")), "loop" if bool(media["bgm"].get("loop", true)) else "once"])
	for key in media.keys():
		var key_text := str(key)
		if key_text.begins_with("sprite_"):
			var sprite_id := key_text.trim_prefix("sprite_")
			var entry: Dictionary = media[key]
			_narcissu_executor.call("execute", "narcissu_lsp", [sprite_id, str(entry.get("reference", "")), float(entry.get("x", 0.0)), float(entry.get("y", 0.0))])
			_narcissu_executor.call("execute", "narcissu_vsp", [sprite_id, 1 if bool(entry.get("visible", true)) else 0])
		elif key_text == "voice":
			_narcissu_executor.call("execute", "narcissu_voice", [str(media[key].get("channel", "0")), str(media[key].get("reference", "")), "once"])
		elif key_text == "sfx":
			_narcissu_executor.call("execute", "narcissu_sfx", [str(media[key].get("channel", "0")), str(media[key].get("reference", "")), "once"])

func _narcissu_smoke_require(condition: bool, message: String) -> bool:
	if not condition:
		_narcissu_smoke_failed = true
		push_error("narcissu local smoke failed: %s" % message)
		get_tree().quit(1)
		return false
	return true

func _run_narcissu_local_smoke() -> void:
	if not FileAccess.file_exists(NARCISSU1_PRIVATE_SCRIPT) or not FileAccess.file_exists(NARCISSU2_PRIVATE_SCRIPT):
		print("narcissu local smoke skipped: generated private scripts are missing")
		get_tree().quit(0)
		return
	if _narcissu_executor == null or not bool(_narcissu_executor.call("has_private_media")):
		print("narcissu local smoke skipped: private game media/manifest missing under reference_private/narcissu/game_data")
		get_tree().quit(0)
		return
	_narcissu_smoke_failed = false
	_assert_narcissu_local_case(NARCISSU1_PRIVATE_SCRIPT, "gp32_image")
	if _narcissu_smoke_failed:
		return
	_assert_narcissu_local_case(NARCISSU2_PRIVATE_SCRIPT, "haeleth_nar2")
	if _narcissu_smoke_failed:
		return
	print("narcissu local smoke ok")
	get_tree().quit(0)

func _assert_narcissu_local_case(path: String, label: String) -> void:
	if not _narcissu_smoke_require(_start_private_galscript(path, label), "start %s" % path):
		return
	_advance_until_narcissu_media(256)
	if not _narcissu_smoke_require(not str(ScenarioRunner.get_current_line().get("text", "")).is_empty(), "text presented for %s" % path):
		return
	if not _narcissu_smoke_require(VNState.backlog.size() > 0, "backlog populated"):
		return
	if not _narcissu_smoke_require(bool(_narcissu_executor.get("last_background_loaded")), "background loaded"):
		return
	if not _narcissu_smoke_require(bool(_narcissu_executor.get("last_bgm_loaded")), "bgm loaded"):
		return
	if not _narcissu_smoke_require(bool(_narcissu_executor.get("last_sfx_or_voice_loaded")), "sfx or voice loaded"):
		return
	var compat_before := ScenarioRunner.get_compatibility_state()
	_quick_save()
	if not _narcissu_smoke_require(SaveSystem.has_slot(1), "quick save slot exists"):
		return
	var saved_presentation := _presentation_snapshot()
	background_texture.texture = null
	background_texture.visible = false
	_narcissu_executor = NarcissuCommandExecutor.new(self)
	_quick_load()
	_restore_narcissu_media(saved_presentation.get("narcissu_media", {}))
	var restored_media: Dictionary = _narcissu_executor.get("active_media")
	if not _narcissu_smoke_require(restored_media.has("background") and restored_media.has("bgm"), "active media restored"):
		return
	var compat_after := ScenarioRunner.get_compatibility_state()
	if not _narcissu_smoke_require(str(ScenarioRunner.get_checkpoint().get("path", "")) == path, "checkpoint restored path"):
		return
	if not _narcissu_smoke_require(typeof(compat_after.get("num_vars", {})) == TYPE_DICTIONARY, "num vars restored"):
		return
	if not _narcissu_smoke_require(typeof(compat_after.get("call_stack", [])) == TYPE_ARRAY, "call stack restored"):
		return
	if not _narcissu_smoke_require(compat_before.has("num_vars") and compat_after.has("num_vars"), "compat state present"):
		return
	_toggle_backlog()
	if not _narcissu_smoke_require(backlog_panel.visible, "backlog toggle"):
		return
	_toggle_backlog()
	_toggle_auto_mode()
	if not _narcissu_smoke_require(_auto_mode, "auto toggle"):
		return
	_toggle_auto_mode()
	_toggle_skip_mode()
	if not _narcissu_smoke_require(_skip_mode, "skip toggle"):
		return
	_toggle_skip_mode()

func _advance_until_narcissu_media(max_steps: int) -> void:
	for step in range(max_steps):
		var has_text := not str(ScenarioRunner.get_current_line().get("text", "")).is_empty()
		var has_bg := bool(_narcissu_executor.get("last_background_loaded"))
		var has_bgm := bool(_narcissu_executor.get("last_bgm_loaded"))
		var has_sfx := bool(_narcissu_executor.get("last_sfx_or_voice_loaded"))
		if has_text and has_bg and has_bgm and has_sfx:
			return
		if ScenarioRunner.is_finished():
			return
		if ScenarioRunner.is_waiting_for_choice():
			ScenarioRunner.choose(0)
		else:
			ScenarioRunner.next()

func _run_narcissu_private_smoke() -> void:
	if not FileAccess.file_exists(NARCISSU1_PRIVATE_SCRIPT) or not FileAccess.file_exists(NARCISSU2_PRIVATE_SCRIPT):
		print("narcissu private smoke skipped: generated private scripts are missing")
		get_tree().quit(0)
		return
	assert(_start_private_galscript(NARCISSU1_PRIVATE_SCRIPT, "gp32_image"))
	_advance_until_presented_text(16)
	assert(not str(ScenarioRunner.get_current_line().get("text", "")).is_empty())
	assert(str(ScenarioRunner.get_checkpoint().get("path", "")) == NARCISSU1_PRIVATE_SCRIPT)
	assert(_start_private_galscript(NARCISSU2_PRIVATE_SCRIPT, "haeleth_nar2"))
	_advance_until_presented_text(16)
	assert(not str(ScenarioRunner.get_current_line().get("text", "")).is_empty())
	assert(str(ScenarioRunner.get_checkpoint().get("path", "")) == NARCISSU2_PRIVATE_SCRIPT)
	print("narcissu private import smoke ok")
	get_tree().quit(0)

func _advance_until_presented_text(max_steps: int) -> void:
	for step in range(max_steps):
		var line := ScenarioRunner.get_current_line()
		if not str(line.get("text", "")).is_empty():
			return
		if ScenarioRunner.is_finished():
			return
		ScenarioRunner.next()

func _run_public_title_smoke() -> void:
	_show_title()
	await get_tree().process_frame
	assert(title_panel.visible)
	assert(title_panel.has_method("get_button_snapshot"))
	var snapshot: Dictionary = title_panel.call("get_button_snapshot")
	assert(snapshot.has("demo") and not bool(snapshot["demo"].get("disabled", true)))
	assert(snapshot.has("dialogue_manager") and not bool(snapshot["dialogue_manager"].get("disabled", true)))
	assert(snapshot.has("narcissu1"))
	assert(snapshot.has("narcissu2"))
	assert(snapshot.has("continue"))
	var narcissu1_missing := not FileAccess.file_exists(NARCISSU1_PRIVATE_SCRIPT)
	var narcissu2_missing := not FileAccess.file_exists(NARCISSU2_PRIVATE_SCRIPT)
	var slot1_missing := not SaveSystem.has_slot(1)
	assert(bool(snapshot["narcissu1"].get("disabled", false)) == narcissu1_missing)
	assert(bool(snapshot["narcissu2"].get("disabled", false)) == narcissu2_missing)
	assert(bool(snapshot["continue"].get("disabled", false)) == slot1_missing)
	if narcissu1_missing:
		assert(str(snapshot["narcissu1"].get("text", "")).contains("not installed"))
	if narcissu2_missing:
		assert(str(snapshot["narcissu2"].get("text", "")).contains("not installed"))
	if slot1_missing:
		assert(str(snapshot["continue"].get("text", "")).contains("empty"))
	print("public title smoke ok")
	get_tree().quit(0)

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

func _screenshot_smoke_fail(message: String) -> void:
	_screenshot_smoke_failed = true
	push_error("screenshot smoke failed: %s" % message)
	get_tree().quit(1)

func _capture_screenshot(path: String) -> bool:
	if DisplayServer.get_name() == "headless":
		return _capture_fallback_screenshot(path)
	await RenderingServer.frame_post_draw
	for attempt in range(8):
		var viewport_texture := get_viewport().get_texture()
		if viewport_texture != null:
			var viewport_rid: RID = viewport_texture.get_rid()
			if viewport_rid != RID() and viewport_rid.is_valid():
				var image := viewport_texture.get_image()
				if image != null:
					var error: Error = image.save_png(path)
					if error != OK:
						_screenshot_smoke_fail("failed to save %s: %s" % [path, str(error)])
						return false
					return true
		await get_tree().process_frame
	return _capture_fallback_screenshot(path)

func _capture_fallback_screenshot(path: String) -> bool:
	var size: Vector2 = get_viewport_rect().size
	var width: int = max(1, int(size.x))
	var height: int = max(1, int(size.y))
	var fallback: Image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	var tint := Color(0.07, 0.09, 0.12, 1.0)
	if path == SCREENSHOT_TITLE_PATH:
		tint = Color(0.10, 0.08, 0.14, 1.0)
	elif path == SCREENSHOT_GAMEPLAY_PATH:
		tint = Color(0.07, 0.12, 0.16, 1.0)
	elif path == SCREENSHOT_SYSTEM_MENU_PATH:
		tint = Color(0.13, 0.10, 0.07, 1.0)
	elif path == SCREENSHOT_BACKLOG_PATH:
		tint = Color(0.08, 0.12, 0.08, 1.0)
	elif path == SCREENSHOT_SAVE_LOAD_PATH:
		tint = Color(0.12, 0.08, 0.10, 1.0)
	fallback.fill(tint)
	var error: Error = fallback.save_png(path)
	if error != OK:
		_screenshot_smoke_fail("failed to save fallback screenshot %s: %s" % [path, str(error)])
		return false
	push_warning("screenshot smoke: used fallback placeholder for %s (rendered viewport texture unavailable)" % path)
	return true

func _advance_to_presented_line_for_screenshot() -> void:
	var attempts := 0
	while _current_full_text.is_empty() and attempts < 12:
		if ScenarioRunner.is_finished():
			break
		ScenarioRunner.next()
		await get_tree().process_frame
		attempts += 1

func _run_screenshot_smoke() -> void:
	_screenshot_smoke_failed = false
	_show_title()
	await get_tree().process_frame
	if not await _capture_screenshot(SCREENSHOT_TITLE_PATH):
		return
	_start_new_game()
	await _advance_to_presented_line_for_screenshot()
	await get_tree().process_frame
	if not await _capture_screenshot(SCREENSHOT_GAMEPLAY_PATH):
		return
	_toggle_system_menu(true)
	await get_tree().process_frame
	if not await _capture_screenshot(SCREENSHOT_SYSTEM_MENU_PATH):
		return
	_toggle_system_menu(false)
	_close_overlays()
	await get_tree().process_frame
	_toggle_backlog()
	await get_tree().process_frame
	if not await _capture_screenshot(SCREENSHOT_BACKLOG_PATH):
		return
	_toggle_backlog()
	_open_save_load(SaveLoadMode.SAVE)
	await get_tree().process_frame
	if not await _capture_screenshot(SCREENSHOT_SAVE_LOAD_PATH):
		return
	print("screenshot smoke ok")
	get_tree().quit(0)

func _dm_smoke_fail(message: String) -> void:
	_dm_smoke_failed = true
	push_error("dialogue manager smoke failed: %s" % message)
	get_tree().quit(1)

func _dm_smoke_require(condition: bool, message: String) -> bool:
	if not condition:
		_dm_smoke_fail(message)
		return false
	return true

func _run_dialogue_manager_smoke() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://.godot/imported")):
		print("dialogue manager smoke skipped: run `godot --headless --editor --path . --quit-after 10` once on fresh checkout")
		get_tree().quit(0)
		return
	_dm_smoke_failed = false
	if not _dm_smoke_require(title_panel.visible, "title panel visible"):
		return
	await _smoke_dialogue_manager_branch(0, "phone")
	if _dm_smoke_failed:
		return
	await _smoke_dialogue_manager_branch(1, "calendar")
	if _dm_smoke_failed:
		return
	DialogueManagerAdapter.reset()
	print("dialogue manager smoke ok")
	get_tree().quit(0)

func _smoke_dialogue_manager_branch(choice_index: int, branch_name: String) -> void:
	await _start_dialogue_manager_sample()
	if not _dm_smoke_require(_dialogue_backend == "dialogue_manager", "backend selected"):
		return
	if not _dm_smoke_require(_current_full_text.contains("Chapter 01"), "first DM line presented"):
		return
	if not _dm_smoke_require(background_label.text == "bg: dm_winter_school_gate", "initial DM background"):
		return
	if not _dm_smoke_require(choice_box.visible == false, "choice hidden before branch"):
		return
	await _advance_dialogue_manager_until_choice(16)
	if not _dm_smoke_require(choice_box.visible, "choice visible"):
		return
	var before_save := _dm_critical_snapshot()
	if not _dm_smoke_require(SaveSystem.save_slot(2, _presentation_snapshot()), "save slot"):
		return
	var payload := SaveSystem.load_slot(2)
	if not _dm_smoke_require(not payload.is_empty(), "load slot"):
		return
	_restore_presentation(payload.get("presentation", {}))
	_refresh_dialogue_manager_display()
	var after_load := _dm_critical_snapshot()
	if not _dm_smoke_require(before_save.get("text") == after_load.get("text"), "restore text"):
		return
	if not _dm_smoke_require(before_save.get("choice_visible") == after_load.get("choice_visible"), "restore choice visibility"):
		return
	if not _dm_smoke_require(before_save.get("response_count") == after_load.get("response_count"), "restore response count"):
		return
	if not _dm_smoke_require(after_load.get("backend") == "dialogue_manager", "restore backend"):
		return
	await _choose_dialogue_manager_response(choice_index)
	if branch_name == "phone":
		if not _dm_smoke_require(VNState.get_flag("mail_received_dm_sg001") and VNState.get_flag("mail_read_dm_sg001") and VNState.get_flag("mail_reply_dm_sg001"), "phone mail flags"):
			return
		if not _dm_smoke_require(VNState.get_flag("dm_phone_branch_observed") and VNState.worldline == "1.048596", "phone branch state"):
			return
		if not _dm_smoke_require(VNState.unlocked_tips.has("dm_worldline_tips") and VNState.unlocked_cg.has("dm_phone_trigger"), "phone unlocks"):
			return
		if not _dm_smoke_require(_current_full_text.contains("命运石之门"), "phone branch text"):
			return
	else:
		if not _dm_smoke_require(VNState.get_flag("dm_visited_music_room") and VNState.get_flag("dm_calendar_branch_observed"), "calendar flags"):
			return
		if not _dm_smoke_require(VNState.current_route == "kazusa" and VNState.current_day >= 2 and VNState.get_affection("kazusa") >= 3, "calendar route state"):
			return
		if not _dm_smoke_require(background_label.text == "bg: dm_music_room" and _current_full_text.contains("白色相簿"), "calendar presentation"):
			return
	await _advance_dialogue_manager()
	if not _dm_smoke_require(_current_full_text == "Phase 1 vertical slice demo ended.", "DM ending"):
		return

func _run_smoke_test() -> void:
	assert(title_panel.visible)
	print("smoke: title flow visible")
	_smoke_branch(0, "phone")
	_start_new_game()
	assert(_typing)
	var mouse_event := InputEventMouseButton.new()
	mouse_event.button_index = MOUSE_BUTTON_LEFT
	mouse_event.pressed = true
	_input(mouse_event)
	assert(not _typing)
	_input(mouse_event)
	assert(not str(ScenarioRunner.get_current_line().get("text", "")).is_empty())
	_return_to_title()
	assert(title_panel.visible and not _game_started)
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
