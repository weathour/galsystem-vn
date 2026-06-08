extends RefCounted

static func panel_style(
	bg: Color = Color(0.035, 0.042, 0.060, 0.90),
	border: Color = Color(0.82, 0.72, 0.56, 0.70),
	radius: int = 14,
	border_width: int = 2
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	return style

static func apply_button_style(button: Button, min_width: float = 150.0) -> void:
	button.custom_minimum_size = Vector2(min_width, 36)
	button.focus_mode = Control.FOCUS_ALL
	var normal := panel_style(Color(0.070, 0.072, 0.086, 0.96), Color(0.28, 0.25, 0.20, 0.95), 7, 1)
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.17, 0.12, 0.08, 0.98)
	hover.border_color = Color(0.86, 0.66, 0.36, 1.0)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.25, 0.17, 0.08, 1.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color(0.91, 0.89, 0.84, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.88, 0.62, 1.0))

static func apply_overlay_style(panel: PanelContainer) -> void:
	panel.add_theme_stylebox_override("panel", panel_style(Color(0.025, 0.028, 0.038, 0.94), Color(0.72, 0.62, 0.48, 0.72), 16, 2))
