extends PanelContainer
class_name BacklogOverlay

signal closed

const VNTheme := preload("res://scripts/ui/VNTheme.gd")

var backlog_text: RichTextLabel

func _ready() -> void:
	name = "BacklogPanel"
	visible = false
	anchor_left = 0.09
	anchor_right = 0.91
	anchor_top = 0.07
	anchor_bottom = 0.88
	offset_left = 0
	offset_right = 0
	offset_top = 0
	offset_bottom = 0
	VNTheme.apply_overlay_style(self)
	_build()

func _build() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)
	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title := Label.new()
	title.text = "Backlog"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.58, 1.0))
	header.add_child(title)
	var close_button := Button.new()
	close_button.text = "Close"
	VNTheme.apply_button_style(close_button, 96)
	close_button.pressed.connect(func() -> void: closed.emit())
	header.add_child(close_button)
	backlog_text = RichTextLabel.new()
	backlog_text.name = "BacklogText"
	backlog_text.bbcode_enabled = true
	backlog_text.fit_content = false
	backlog_text.scroll_active = true
	backlog_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	backlog_text.custom_minimum_size = Vector2(900, 470)
	backlog_text.add_theme_font_size_override("normal_font_size", 23)
	backlog_text.add_theme_color_override("default_color", Color(0.92, 0.90, 0.84, 1.0))
	vbox.add_child(backlog_text)

func set_entries(entries: Array) -> void:
	var lines: Array[String] = []
	for item in entries:
		var entry: Dictionary = item if typeof(item) == TYPE_DICTIONARY else {}
		var speaker := str(entry.get("speaker", ""))
		var text := str(entry.get("text", ""))
		var prefix := "[color=gray]D%s %s[/color] " % [int(entry.get("day", 0)), str(entry.get("route", ""))]
		lines.append(prefix + (("[b]%s[/b]: %s" % [speaker, text]) if not speaker.is_empty() else text))
	backlog_text.text = "\n\n".join(lines)
