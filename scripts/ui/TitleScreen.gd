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

	vbox.add_child(_menu_button("Start .galscript", func() -> void: start_galscript_requested.emit()))
	vbox.add_child(_menu_button("Start Dialogue Manager", func() -> void: start_dialogue_manager_requested.emit()))
	vbox.add_child(_menu_button("Narcissu 1 Private", func() -> void: start_narcissu1_requested.emit()))
	vbox.add_child(_menu_button("Narcissu 2 Private", func() -> void: start_narcissu2_requested.emit()))
	vbox.add_child(_menu_button("Continue Slot 1", func() -> void: continue_requested.emit()))
	vbox.add_child(_menu_button("Config / System", func() -> void: config_requested.emit()))
	vbox.add_child(_menu_button("Developer Tools", func() -> void: debug_requested.emit()))

func _menu_button(label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	VNTheme.apply_button_style(button)
	button.pressed.connect(callback)
	return button

func relayout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if root == null:
		return
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 72
	root.offset_right = -72
	root.offset_top = 64
	root.offset_bottom = -64
