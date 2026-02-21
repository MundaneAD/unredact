extends Node2D

@export var speechbox: VBoxContainer
@onready var microfilm_view: Node2D = $"../microfilm_view"

signal term_searched(text)

var engine := LibLib.new()
var last_query: String = ""

func speak(text: String) -> void:
	pass

func ask(text: String) -> void:
	speechbox.visible = true

func _on_microfilm_viewer_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		speechbox.visible = false

func _on_tannie_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		ask("hi")

func _on_search_input_text_submitted(query: String) -> void:
	last_query = query
	var result := engine.search(query)

	if result["results"].is_empty():
		speak(result["status"])
		return

	# Hand the result entries to whatever displays them
	microfilm_view.set_entries(result["results"])
	speak(result["status"])
	term_searched.emit(query)

func open_result(doc_id: String) -> void:
	var result := engine.open_doc(doc_id, last_query)
	microfilm_view.show_document(result["title"], result["body_bbcode"])

	for word in result["new_words"]:
		# Add to your word bank UI however you like
		pass

	speak(result["status"])

func next_chapter() -> void:
	engine.advance_chapter()
	speak("New chapter unlocked.")
