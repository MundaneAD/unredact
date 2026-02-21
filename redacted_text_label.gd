@tool
class_name RedactedLabelj
extends RichTextLabel

## A RichTextLabel that draws solid redaction boxes over words wrapped in [[double brackets]].
## Usage: call set_redacted_text("The agent [[JOHN DOE]] has been compromised.")

const REDACT_COLOR := Color(0.08, 0.08, 0.08, 1.0)
const REDACT_PADDING := Vector2(3.0, 2.0)

# [start, end] character index pairs in the plain (stripped) text
var _redact_ranges: Array = []
# Computed screen-space Rect2s, rebuilt after layout
var _redact_regions: Array[Rect2] = []


func _ready() -> void:
	bbcode_enabled = false
	fit_content = true
	scroll_active = false


## Set text with [[redacted]] markers. This is the main API.
func set_redacted_text(raw: String) -> void:
	_parse_and_set(raw)
	# Wait one frame for RichTextLabel to finish laying out glyphs, then measure.
	await get_tree().process_frame
	_calculate_regions()
	queue_redraw()


func _parse_and_set(raw: String) -> void:
	_redact_ranges.clear()

	var regex := RegEx.new()
	regex.compile("\\[\\[(.+?)\\]\\]")

	var plain := ""
	var last := 0
	for m in regex.search_all(raw):
		# Append the non-redacted text before this match
		plain += raw.substr(last, m.get_start() - last)
		# Record the character range of the redacted word in the plain string
		var range_start := plain.length()
		var inner := m.get_string(1)
		plain += inner
		_redact_ranges.append([range_start, plain.length()])
		last = m.get_end()
	plain += raw.substr(last)

	# Set as plain text — bbcode_enabled is false so no escaping needed
	text = plain


func _calculate_regions() -> void:
	_redact_regions.clear()
	if _redact_ranges.is_empty():
		return

	var font: Font = get_theme_font("normal_font") \
		if has_theme_font("normal_font", "") \
		else ThemeDB.fallback_font
	var font_size: int = get_theme_font_size("normal_font_size") \
		if has_theme_font_size("normal_font_size", "") \
		else ThemeDB.fallback_font_size
	var line_height: float = font.get_height(font_size)
	var plain: String = get_parsed_text()

	for range_pair in _redact_ranges:
		var range_start: int = range_pair[0]
		var range_end: int   = range_pair[1]
		if range_start >= plain.length():
			continue

		# RichTextLabel may wrap a redacted word across lines. Handle each line segment.
		var seg_start := range_start
		while seg_start < range_end:
			var line_num := get_character_line(seg_start)
			if line_num < 0:
				break

			# Find where this line ends within our redacted range
			var seg_end := range_end
			for c in range(seg_start + 1, range_end):
				if get_character_line(c) != line_num:
					seg_end = c
					break

			var line_y: float = get_line_offset(line_num)

			# Find the first character of this line so we can measure the x prefix.
			# FIX: Default to 0; the old code defaulted to seg_start, which meant
			# that when all preceding chars were on the same line (the loop never
			# broke), the prefix was empty and x_start was incorrectly 0.
			var line_char_start := 0
			for c in range(seg_start - 1, -1, -1):
				if get_character_line(c) != line_num:
					line_char_start = c + 1
					break

			var prefix     := plain.substr(line_char_start, seg_start - line_char_start)
			var seg_text   := plain.substr(seg_start, seg_end - seg_start)
			var x_start: float = font.get_string_size(prefix,   HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var seg_width: float = font.get_string_size(seg_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

			var rect := Rect2(
				Vector2(x_start, line_y) - REDACT_PADDING,
				Vector2(seg_width, line_height) + REDACT_PADDING * 2.0
			)
			_redact_regions.append(rect)
			seg_start = seg_end


func _draw() -> void:
	for rect in _redact_regions:
		draw_rect(rect, REDACT_COLOR)
