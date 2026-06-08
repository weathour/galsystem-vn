extends HBoxContainer
class_name QuickMenu

signal backlog_requested
signal auto_requested
signal skip_requested
signal save_requested
signal load_requested
signal quick_save_requested
signal quick_load_requested
signal config_requested
signal title_requested

var _buttons: Dictionary = {}

func _ready() -> void:
	name = "QuickMenu"
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 8)
	_build_buttons()
	set_modes(false, false)

func _build_buttons() -> void:
	_add_button("backlog", "Backlog", backlog_requested)
	_add_button("auto", "Auto", auto_requested)
	_add_button("skip", "Skip", skip_requested)
	_add_button("save", "Save", save_requested)
	_add_button("load", "Load", load_requested)
	_add_button("qsave", "Q.Save", quick_save_requested)
	_add_button("qload", "Q.Load", quick_load_requested)
	_add_button("config", "Config", config_requested)
	_add_button("title", "Title", title_requested)

func _add_button(key: String, label: String, target_signal: Signal) -> void:
	var button := Button.new()
	button.name = "%sButton" % key.capitalize()
	button.text = label
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(76, 30)
	_apply_button_skin(button)
	button.pressed.connect(func() -> void: target_signal.emit())
	add_child(button)
	_buttons[key] = button

func _apply_button_skin(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.065, 0.066, 0.080, 0.92)
	normal.border_color = Color(0.22, 0.20, 0.18, 0.9)
	normal.set_border_width_all(1)
	normal.corner_radius_top_left = 5
	normal.corner_radius_top_right = 5
	normal.corner_radius_bottom_left = 5
	normal.corner_radius_bottom_right = 5
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.16, 0.12, 0.09, 0.96)
	hover.border_color = Color(0.78, 0.60, 0.36, 0.9)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.24, 0.16, 0.08, 0.98)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color(0.90, 0.88, 0.82, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.88, 0.62, 1.0))

func set_modes(auto_enabled: bool, skip_enabled: bool) -> void:
	_set_button_active("auto", auto_enabled)
	_set_button_active("skip", skip_enabled)

func _set_button_active(key: String, active: bool) -> void:
	if not _buttons.has(key):
		return
	var button: Button = _buttons[key]
	button.modulate = Color(1.0, 0.86, 0.50, 1.0) if active else Color(1, 1, 1, 1)
