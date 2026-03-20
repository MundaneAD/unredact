class_name RedactedLabel
extends Control

@export_multiline var source_text: String = \
	"The [[quick]] brown fox [[jumps]] over the [[lazy]] dog."

@export var char_width_estimate: float = 10.0
@export var font_size: int = 18
@export var redact_color: Color = Color.BLACK
@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer

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
@onready var color_rect: ColorRect = $"../.."

func unlock_word(word):
	var chip := _make_chip(word)
	_word_bank.add_child(chip)
	
	chip.modulate.a = 0.0
	audio_stream_player.play()

	# wait a frame so the chip has been laid out and has a valid position
	await get_tree().process_frame
	await get_tree().process_frame

	var target_pos := chip.global_position

	# overlay chip starting at mouse position
	var overlay := _make_chip(word)
	overlay.theme = color_rect.theme
	var ft = color_rect.theme.default_font
	overlay.theme.default_font = ft
	
	overlay.global_position = get_viewport().get_mouse_position()
	get_tree().current_scene.add_child(overlay)

	# hide the real chip until animation lands

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(overlay, "global_position", target_pos, 0.4)
	await tween.finished

	chip.modulate.a = 1.0
	overlay.queue_free()

func _parse_into_flow(parent) -> void:
	for line in source_text.split("\n", true):
		if line.strip_edges() == "":
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(0, font_size)
			parent.add_child(spacer)
			continue
		var flow := HFlowContainer.new()
		flow.last_wrap_alignment = FlowContainer.LAST_WRAP_ALIGNMENT_BEGIN
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
	#lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	#lbl.size_flags_horizontal = Control.SIZE_EXPAND
	lbl.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	return lbl

func _make_slot(word: String) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.set_meta("word", word)
	slot.set_meta("filled", false)
	#slot.custom_minimum_size = Vector2(
		#max(float(word.length()) * char_width_estimate, 40.0) ,
		#float(font_size) 
	#)

	var style := StyleBoxFlat.new()
	style.bg_color = redact_color
	slot.add_theme_stylebox_override("panel", style)

	var lbl := Label.new()
	lbl.text = word
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.set_anchors_and_offsets_preset(PRESET_CENTER)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	#lbl.visible = false
	lbl.modulate.a = 0
	
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
	return not slot.get_meta("filled") and data.get("word", "").to_lower() == slot.get_meta("word").to_lower()

func _slot_drop(_pos: Vector2, data: Variant, slot: PanelContainer) -> void:
	slot.set_meta("filled", true)
	slot.get_child(0).modulate.a = 1
	var style := slot.get_theme_stylebox("panel") as StyleBoxFlat
	style.bg_color = Color(0.2, 0.6, 0.3)  # green to show success
	var chip: PanelContainer = data.get("chip")
	if chip and is_instance_valid(chip):
		chip.queue_free()
