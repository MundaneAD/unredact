extends RichTextLabel

signal word_became_visible(word: String)

# Words you want to watch, mapped to whether they've been seen yet
var watched_words: Dictionary = {
	"snow drift": false,
	"avalanche": false,
}

# Cached line number for each word (-1 = not found)
var word_lines: Dictionary = {}

func _ready() -> void:
	# Wait one frame for the label to lay out text before measuring lines
	await get_tree().process_frame
	_cache_word_lines()
	get_v_scroll_bar().value_changed.connect(_on_scroll_changed)
	# Check initial state in case words are visible without scrolling
	_check_visible_words(get_v_scroll_bar().value)
	word_became_visible.connect(_on_word_revealed)
	
func _on_word_revealed(word):
	print(word)

func _cache_word_lines() -> void:
	var plain := get_parsed_text()  # plain text, no BBCode
	for word in watched_words.keys():
		var idx := plain.findn(word)  # case-insensitive search
		if idx != -1:
			word_lines[word] = get_character_line(idx)
		else:
			word_lines[word] = -1


func _on_scroll_changed(scroll_value: float) -> void:
	_check_visible_words(scroll_value)


func _check_visible_words(scroll_value: float) -> void:
	var total_lines := get_line_count()
	if total_lines == 0:
		return

	var content_h := get_content_height()
	var line_height := content_h / float(total_lines)

	var first_visible_line := int(scroll_value / line_height)
	var last_visible_line := int((scroll_value + size.y) / line_height)

	for word in watched_words.keys():
		# Skip already-triggered words
		if watched_words[word]:
			continue

		var line: int = word_lines.get(word, -1)
		if line == -1:
			continue

		if line >= first_visible_line and line <= last_visible_line:
			watched_words[word] = true
			word_became_visible.emit(word)
