extends Node2D

signal exit_pressed


func _on_back_button_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		exit_pressed.emit()

func set_entries(entries):
	for entry in entries:
		pass
