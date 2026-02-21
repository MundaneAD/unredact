class_name RedactedLabel
extends Control

@export_multiline var source_text: String = \
	"The [[quick]] brown fox [[jumps]] over the [[lazy]] dog."

@export var char_width_estimate: float = 10.0
@export var font_size: int = 18
@export var redact_color: Color = Color.BLACK

@export var _word_bank: HFlowContainer
var _slots: Array = []

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0

	#var vbox := VBoxContainer.new()
	##vbox.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	#add_child(vbox)

	var flow := VBoxContainer.new()
	
	flow.add_theme_constant_override("h_separation", 5)
	flow.add_theme_constant_override("v_separation", 8)
	add_child(flow)
	_parse_into_flow(flow)

	#_word_bank = HFlowContainer.new()
	_word_bank.add_theme_constant_override("h_separation", 8)
	_word_bank.add_theme_constant_override("v_separation", 6)
	#vbox.add_child(_word_bank)

	#var words := _slots.map(func(s): return s.get_meta("word"))
	#words.shuffle()
	#for word in words:
		#_word_bank.add_child(_make_chip(word))

func unlock_word(word):
	_word_bank.add_child(_make_chip(word))

func _parse_into_flow(parent) -> void:
	for line in source_text.split("\n", false):
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("separation", 5)
		parent.add_child(flow)
		_parse_line_into_flow(flow, line)

func _parse_line_into_flow(flow, text: String) -> void:
	var remaining := text
	while remaining != "":
		var bs := remaining.find("[[")
		if bs == -1:
			for word in remaining.split(" ", false):
				flow.add_child(_make_label(word))
			break
		if bs > 0:
			for word in remaining.substr(0, bs).split(" ", false):
				flow.add_child(_make_label(word))
		var be := remaining.find("]]", bs)
		if be == -1:
			for word in remaining.substr(bs).split(" ", false):
				flow.add_child(_make_label(word))
			break
		flow.add_child(_make_slot(remaining.substr(bs + 2, be - bs - 2)))
		remaining = remaining.substr(be + 2)

func _make_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color.BLACK)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.size_flags_vertical = SIZE_SHRINK_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.size_flags_horizontal = Control.SIZE_EXPAND
	lbl.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	return lbl

func _make_slot(word: String) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.set_meta("word", word)
	slot.set_meta("filled", false)
	slot.custom_minimum_size = Vector2(
		max(float(word.length()) * char_width_estimate, 40.0) + 16.0,
		float(font_size) + 14.0
	)

	var style := StyleBoxFlat.new()
	style.bg_color = redact_color
	slot.add_theme_stylebox_override("panel", style)

	var lbl := Label.new()
	lbl.text = word
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.set_anchors_and_offsets_preset(PRESET_CENTER)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.visible = false
	slot.add_child(lbl)

	slot.set_drag_forwarding(Callable(), _slot_can_drop.bind(slot), _slot_drop.bind(slot))
	_slots.append(slot)
	return slot

func _make_chip(word: String) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.set_meta("word", word)
	chip.custom_minimum_size = Vector2(
		max(float(word.length()) * char_width_estimate, 40.0) + 24.0,
		float(font_size) + 18.0
	)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.4, 0.8)
	style.corner_radius_top_left     = 4
	style.corner_radius_top_right    = 4
	style.corner_radius_bottom_left  = 4
	style.corner_radius_bottom_right = 4
	chip.add_theme_stylebox_override("panel", style)

	var lbl := Label.new()
	lbl.text = word
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.set_anchors_and_offsets_preset(PRESET_CENTER)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.add_child(lbl)

	chip.set_drag_forwarding(_chip_get_drag_data.bind(chip), Callable(), Callable())
	return chip

func _chip_get_drag_data(_pos: Vector2, chip: PanelContainer) -> Variant:
	var preview := _make_chip(chip.get_meta("word"))
	set_drag_preview(preview)
	return {"word": chip.get_meta("word"), "chip": chip}

func _slot_can_drop(_pos: Vector2, data: Variant, slot: PanelContainer) -> bool:
	return not slot.get_meta("filled") and data.get("word", "") == slot.get_meta("word")

func _slot_drop(_pos: Vector2, data: Variant, slot: PanelContainer) -> void:
	slot.set_meta("filled", true)
	slot.get_child(0).visible = true
	var style := slot.get_theme_stylebox("panel") as StyleBoxFlat
	style.bg_color = Color(0.2, 0.6, 0.3)  # green to show success
	var chip: PanelContainer = data.get("chip")
	if chip and is_instance_valid(chip):
		chip.queue_free()
