extends Control
class_name DialogueWindow

const QuickMenuScene := preload("res://scripts/ui/QuickMenu.gd")

var panel: PanelContainer
var namebox: PanelContainer
var speaker_label: Label
var text_label: RichTextLabel
var quick_menu: HBoxContainer
var advance_indicator: Label

func _ready() -> void:
	name = "DialogueWindow"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()

func _build() -> void:
	panel = PanelContainer.new()
	panel.name = "DialoguePanel"
	panel.anchor_left = 0.075
	panel.anchor_right = 0.925
	panel.anchor_top = 0.675
	panel.anchor_bottom = 0.965
	panel.offset_left = 0
	panel.offset_right = 0
	panel.offset_top = 0
	panel.offset_bottom = 0
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.042, 0.060, 0.86)
	panel_style.border_color = Color(0.82, 0.72, 0.56, 0.72)
	panel_style.set_border_width_all(2)
	panel_style.corner_radius_top_left = 14
	panel_style.corner_radius_top_right = 14
	panel_style.corner_radius_bottom_left = 14
	panel_style.corner_radius_bottom_right = 14
	panel_style.content_margin_left = 24
	panel_style.content_margin_right = 24
	panel_style.content_margin_top = 24
	panel_style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)

	var text_row := HBoxContainer.new()
	text_row.name = "TextRow"
	text_row.add_theme_constant_override("separation", 12)
	content.add_child(text_row)

	text_label = RichTextLabel.new()
	text_label.name = "DialogueText"
	text_label.bbcode_enabled = true
	text_label.fit_content = false
	text_label.scroll_active = false
	text_label.visible_characters_behavior = TextServer.VC_CHARS_BEFORE_SHAPING
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_label.custom_minimum_size = Vector2(0, 116)
	text_label.add_theme_font_size_override("normal_font_size", 30)
	text_label.add_theme_color_override("default_color", Color(0.96, 0.94, 0.88, 1.0))
	text_row.add_child(text_label)

	advance_indicator = Label.new()
	advance_indicator.name = "AdvanceIndicator"
	advance_indicator.text = "▾"
	advance_indicator.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	advance_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	advance_indicator.custom_minimum_size = Vector2(28, 0)
	advance_indicator.add_theme_font_size_override("font_size", 28)
	advance_indicator.add_theme_color_override("font_color", Color(1.0, 0.80, 0.46, 1.0))
	text_row.add_child(advance_indicator)

	quick_menu = QuickMenuScene.new()
	quick_menu.name = "QuickMenu"
	quick_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(quick_menu)

	namebox = PanelContainer.new()
	namebox.name = "Namebox"
	namebox.anchor_left = 0.095
	namebox.anchor_right = 0.34
	namebox.anchor_top = 0.615
	namebox.anchor_bottom = 0.685
	namebox.offset_left = 0
	namebox.offset_right = 0
	namebox.offset_top = 0
	namebox.offset_bottom = 0
	namebox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_style := StyleBoxFlat.new()
	name_style.bg_color = Color(0.11, 0.07, 0.10, 0.94)
	name_style.border_color = Color(0.86, 0.66, 0.36, 0.84)
	name_style.set_border_width_all(2)
	name_style.corner_radius_top_left = 12
	name_style.corner_radius_top_right = 12
	name_style.corner_radius_bottom_left = 12
	name_style.corner_radius_bottom_right = 12
	name_style.content_margin_left = 18
	name_style.content_margin_right = 18
	name_style.content_margin_top = 8
	name_style.content_margin_bottom = 8
	namebox.add_theme_stylebox_override("panel", name_style)
	add_child(namebox)

	speaker_label = Label.new()
	speaker_label.name = "SpeakerLabel"
	speaker_label.text = ""
	speaker_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speaker_label.add_theme_font_size_override("font_size", 24)
	speaker_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.62, 1.0))
	namebox.add_child(speaker_label)

func set_dialogue(speaker: String, text: String) -> void:
	speaker_label.text = speaker
	namebox.visible = not speaker.strip_edges().is_empty()
	text_label.text = text

func set_visible_characters(count: int) -> void:
	text_label.visible_characters = count
	advance_indicator.visible = count == -1

func set_modes(auto_enabled: bool, skip_enabled: bool) -> void:
	quick_menu.set_modes(auto_enabled, skip_enabled)
