extends PanelContainer
class_name SaveLoadOverlay

signal slot_selected(slot_id: int)
signal closed

const VNTheme := preload("res://scripts/ui/VNTheme.gd")

var title_label: Label
var slot_list: VBoxContainer

func _ready() -> void:
	name = "SaveLoadPanel"
	visible = false
	anchor_left = 0.10
	anchor_right = 0.90
	anchor_top = 0.08
	anchor_bottom = 0.90
	offset_left = 0
	offset_right = 0
	offset_top = 0
	offset_bottom = 0
	VNTheme.apply_overlay_style(self)
	_build()

func _build() -> void:
	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.add_theme_constant_override("separation", 14)
	add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	title_label = Label.new()
	title_label.name = "Title"
	title_label.text = "Save"
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override("font_size", 30)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.58, 1.0))
	header.add_child(title_label)

	var close_button := Button.new()
	close_button.text = "Close"
	VNTheme.apply_button_style(close_button, 96)
	close_button.pressed.connect(func() -> void: closed.emit())
	header.add_child(close_button)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	slot_list = VBoxContainer.new()
	slot_list.name = "SlotList"
	slot_list.add_theme_constant_override("separation", 8)
	slot_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(slot_list)

func set_mode(label: String) -> void:
	if title_label != null:
		title_label.text = label

func set_slots(slots: Array) -> void:
	for child in slot_list.get_children():
		child.queue_free()
	for slot in slots:
		var data: Dictionary = slot if typeof(slot) == TYPE_DICTIONARY else {}
		var slot_id := int(data.get("slot_id", 0))
		var exists := bool(data.get("exists", false))
		var disabled := bool(data.get("disabled", false))
		var button := Button.new()
		button.name = "Slot%d" % slot_id
		button.text = str(data.get("label", "Slot %02d" % slot_id))
		button.custom_minimum_size = Vector2(0, 74)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		VNTheme.apply_button_style(button, 0)
		button.disabled = disabled
		button.modulate = Color(1, 1, 1, 1) if exists else Color(0.74, 0.74, 0.74, 0.82)
		button.pressed.connect(_emit_slot_selected.bind(slot_id))
		slot_list.add_child(button)

func _emit_slot_selected(slot_id: int) -> void:
	slot_selected.emit(slot_id)
