extends Node2D

var open = true
@export var button: Button

func on_open():
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", 23.0, 0.4)
	button.text = "Close Redacted Text"

func on_close():
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position:y", 555.0, 0.4)
	button.text = "Open Redacted Text"


func _on_page_open_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	if open:
		on_close()
		open = false
	else:
		on_open()
		open = true


func _on_open_close_pressed() -> void:
	if open:
		on_close()
		open = false
	else:
		on_open()
		open = true
		
