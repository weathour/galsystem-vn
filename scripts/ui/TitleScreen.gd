extends PanelContainer
class_name TitleScreen

signal start_galscript_requested
signal start_dialogue_manager_requested
signal start_narcissu1_requested
signal start_narcissu2_requested
signal continue_requested
signal config_requested
signal debug_requested

const VNTheme := preload("res://scripts/ui/VNTheme.gd")

var root: HBoxContainer
var status_label: Label
var _buttons: Dictionary = {}

func _ready() -> void:
	name = "TitlePanel"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_theme_stylebox_override("panel", VNTheme.panel_style(Color(0.025, 0.028, 0.040, 0.90), Color(0.55, 0.46, 0.34, 0.45), 0, 0))
	_build()
	relayout()

func _build() -> void:
	root = HBoxContainer.new()
	root.name = "TitleRoot"
	root.add_theme_constant_override("separation", 32)
	root.custom_minimum_size = Vector2(1080, 560)
	add_child(root)

	var title_box := VBoxContainer.new()
	title_box.name = "BrandColumn"
	title_box.custom_minimum_size = Vector2(560, 0)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	title_box.add_theme_constant_override("separation", 18)
	root.add_child(title_box)

	var title := Label.new()
	title.text = "galsystem"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.62, 1.0))
	title_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "ADV / Galgame Runtime"
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", Color(0.83, 0.80, 0.72, 1.0))
	title_box.add_child(subtitle)

	var hint := Label.new()
	hint.text = "A Godot visual-novel shell for long-form branching stories"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(440, 0)
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(0.70, 0.68, 0.62, 1.0))
	title_box.add_child(hint)

	var menu_panel := PanelContainer.new()
	menu_panel.name = "MainMenuPanel"
	menu_panel.custom_minimum_size = Vector2(360, 0)
	menu_panel.add_theme_stylebox_override("panel", VNTheme.panel_style(Color(0.035, 0.038, 0.052, 0.92), Color(0.76, 0.64, 0.46, 0.72), 16, 2))
	root.add_child(menu_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 11)
	menu_panel.add_child(vbox)

	var menu_title := Label.new()
	menu_title.text = "Main Menu"
	menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_title.add_theme_font_size_override("font_size", 28)
	menu_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.58, 1.0))
	vbox.add_child(menu_title)

	vbox.add_child(_menu_button("demo", "Start Demo", func() -> void: start_galscript_requested.emit()))
	vbox.add_child(_menu_button("dialogue_manager", "Start Dialogue Manager Demo", func() -> void: start_dialogue_manager_requested.emit()))
	vbox.add_child(_menu_button("narcissu1", "Narcissu 1 Private", func() -> void: start_narcissu1_requested.emit()))
	vbox.add_child(_menu_button("narcissu2", "Narcissu 2 Private", func() -> void: start_narcissu2_requested.emit()))
	vbox.add_child(_menu_button("continue", "Continue Slot 1", func() -> void: continue_requested.emit()))
	vbox.add_child(_menu_button("config", "Config / System", func() -> void: config_requested.emit()))
	vbox.add_child(_menu_button("developer", "Developer Tools", func() -> void: debug_requested.emit()))

	status_label = Label.new()
	status_label.name = "PublicStatus"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(0, 54)
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color(0.74, 0.72, 0.66, 1.0))
	vbox.add_child(status_label)

func _menu_button(key: String, label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	VNTheme.apply_button_style(button)
	button.pressed.connect(callback)
	_buttons[key] = button
	return button

func set_public_availability(narcissu1_ready: bool, narcissu2_ready: bool, continue_ready: bool) -> void:
	_set_button_state("narcissu1", narcissu1_ready, "Narcissu 1 Private", "Narcissu 1 Private — not installed")
	_set_button_state("narcissu2", narcissu2_ready, "Narcissu 2 Private", "Narcissu 2 Private — not installed")
	_set_button_state("continue", continue_ready, "Continue Slot 1", "Continue Slot 1 — empty")
	if status_label != null:
		var notes: Array[String] = []
		if not narcissu1_ready or not narcissu2_ready:
			notes.append("Private compatibility entries are disabled until local reference data is installed.")
		if not continue_ready:
			notes.append("Slot 1 is empty; start the public demo first.")
		status_label.text = " ".join(notes)

func _set_button_state(key: String, enabled: bool, ready_label: String, missing_label: String) -> void:
	if not _buttons.has(key):
		return
	var button: Button = _buttons[key]
	button.disabled = not enabled
	button.text = ready_label if enabled else missing_label
	button.modulate = Color(1, 1, 1, 1) if enabled else Color(0.66, 0.66, 0.66, 0.78)

func get_button_snapshot() -> Dictionary:
	var snapshot := {}
	for key in _buttons.keys():
		var button: Button = _buttons[key]
		snapshot[key] = {
			"text": button.text,
			"disabled": button.disabled,
		}
	return snapshot

func relayout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if root == null:
		return
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 72
	root.offset_right = -72
	root.offset_top = 64
	root.offset_bottom = -64
