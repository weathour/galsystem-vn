extends PanelContainer
class_name SystemMenuOverlay

signal resume_requested
signal save_requested
signal load_requested
signal backlog_requested
signal auto_requested
signal skip_requested
signal title_requested
signal closed

const VNTheme := preload("res://scripts/ui/VNTheme.gd")

func _ready() -> void:
	name = "SystemMenu"
	visible = false
	anchor_left = 0.34
	anchor_right = 0.66
	anchor_top = 0.14
	anchor_bottom = 0.82
	offset_left = 0
	offset_right = 0
	offset_top = 0
	offset_bottom = 0
	VNTheme.apply_overlay_style(self)
	_build()

func _build() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)
	var title := Label.new()
	title.text = "System Menu"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.58, 1.0))
	vbox.add_child(title)
	vbox.add_child(_menu_button("Resume", func() -> void: resume_requested.emit()))
	vbox.add_child(_menu_button("Save", func() -> void: save_requested.emit()))
	vbox.add_child(_menu_button("Load", func() -> void: load_requested.emit()))
	vbox.add_child(_menu_button("Backlog", func() -> void: backlog_requested.emit()))
	vbox.add_child(_menu_button("Auto", func() -> void: auto_requested.emit()))
	vbox.add_child(_menu_button("Skip", func() -> void: skip_requested.emit()))
	vbox.add_child(_menu_button("Return to Title", func() -> void: title_requested.emit()))
	vbox.add_child(_menu_button("Close", func() -> void: closed.emit()))

func _menu_button(label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	VNTheme.apply_button_style(button)
	button.pressed.connect(callback)
	return button
